;;; -*- Log: hemlock.log; Package: Hemlock-Internals -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the Spice Lisp project at
;;; Carnegie-Mellon University, and has been placed in the public domain.
;;; Spice Lisp is currently incomplete and under active development.
;;; If you want to use this code or any part of Spice Lisp, please contact
;;; Scott Fahlman (FAHLMAN@CMUC).
;;; **********************************************************************
;;;
;;; "Site dependent" stuff for the editor while on the IBM RT PC machine.
;;;

(in-package "SYSTEM")

(export '(without-hemlock))


(in-package "HEMLOCK-INTERNALS" :nicknames '("HI"))

(export '(show-mark editor-sleep text-character print-pretty-character
	  *input-transcript* *real-editor-input* input-waiting
	  fun-defined-from-pathname editor-describe-function pause-hemlock
	  store-cut-string fetch-cut-string schedule-event
	  remove-scheduled-event enter-window-autoraise directoryp
	  last-key-event-cursorpos merge-relative-pathnames *editor-input*
	  *last-character-typed* *character-history*
	  ;;
	  ;; Export default-font to prevent a name conflict that occurs due to
	  ;; the Hemlock variable "Default Font" defined in SITE-INIT below.
	  ;;
	  default-font))


;;; SYSTEM:WITHOUT-HEMLOCK -- Public.
;;;
;;; Code:lispinit.lisp uses this for a couple interrupt handlers, and
;;; eval-server.lisp.
;;; 
(defmacro system:without-hemlock (&body body)
  "When in the editor and not in the debugger, call the exit method of Hemlock's
   device, so we can type.  Do the same thing on exit but call the init method."
  `(progn
     (when (and *in-the-editor* (not debug::*in-the-debugger*))
       (let ((device (device-hunk-device (window-hunk (current-window)))))
	 (funcall (device-exit device) device)))
     ,@body
     (when (and *in-the-editor* (not debug::*in-the-debugger*))
       (let ((device (device-hunk-device (window-hunk (current-window)))))
	 (funcall (device-init device) device)))))



;;;; SITE-INIT.

;;; *character-history* is defined much later in this file, but it needs to
;;; be set in SITE-INIT, since MAKE-RING doesn't exist at load time for this
;;; file.
;;;
(proclaim '(special *character-history*))

;;; SITE-INIT  --  Internal
;;;
;;;    This function is called at init time to set up any site stuff.
;;;
(defun site-init ()
  (defhvar "Beep Border Width"
    "Width in pixels of the border area inverted by beep."
    :value 20)
  (defhvar "Default Window Width"
    "This is used to make a window when prompting the user.  The value is in
     characters."
    :value 80)
  (defhvar "Default Window Height"
    "This is used to make a window when prompting the user.  The value is in
     characters."
    :value 24)
  (defhvar "Default Initial Window Width"
    "This is used when Hemlock first starts up to make its first window.
     The value is in characters."
    :value 80)
  (defhvar "Default Initial Window Height"
    "This is used when Hemlock first starts up to make its first window.
     The value is in characters."
    :value 24)
  (defhvar "Default Initial Window X"
    "This is used when Hemlock first starts up to make its first window.
     The value is in pixels."
    :value nil)
  (defhvar "Default Initial Window Y"
    "This is used when Hemlock first starts up to make its first window.
     The value is in pixels."
    :value nil)
  (defhvar "Bell Style"
    "This controls what beeps do in Hemlock.  Acceptable values are :border-flash
     (which is the default), :feep, :border-flash-and-feep, :flash,
     :flash-and-feep, and NIL (do nothing)."
    :value :border-flash)
  (defhvar "Reverse Video"
    "Paints white on black in window bodies, black on white in modelines."
    :value nil
    :hooks '(reverse-video-hook-fun))
  (defhvar "Cursor Bitmap File"
    "File to read to setup cursors for Hemlock windows.  The mask is found by
     merging this name with \".mask\"."
    :value "/usr/misc/.lisp/lib/hemlock11.cursor")
  (defhvar "Enter Window Hook"
    "When the mouse enters an editor window, this hook is invoked.  These
     functions take the Hemlock Window as an argument."
    :value nil)
  (defhvar "Exit Window Hook"
    "When the mouse exits an editor window, this hook is invoked.  These
     functions take the Hemlock Window as an argument."
    :value nil)
  (defhvar "Set Window Autoraise"
    "When non-nil, setting the current window will automatically raise that
     window via a function on \"Set Window Hook\".  If the value is :echo-only
     (the default), then only the echo area window will be raised
     automatically upon becoming current."
    :value :echo-only)
  (defhvar "Default Font"
    "The string name of the font to be used for Hemlock -- buffer text,
     modelines, random typeout, etc.  The font is loaded when initializing
     Hemlock."
    :value "8x13")
  (defhvar "Thumb Bar Meter"
    "When non-nil (the default), windows will be created to be displayed with
     a ruler in the bottom border of the window."
    :value t)

  (setf *character-history* (make-ring 60))
  nil)



;;;; Some generally useful file-system functions.

;;; MERGE-RELATIVE-PATHNAMES takes a pathname that is either absolute or
;;; relative to default-dir, merging it as appropriate and returning a definite
;;; directory pathname.  If the component comes back with a trailing slash, we
;;; have to remove it to get the MERGE-PATHNAMES to work correctly.  The result
;;; must have a trailing slash.
;;; 
(defun merge-relative-pathnames (pathname default-directory)
  "Merges pathname with default-directory.  If pathname is not absolute, it
   is assumed to be relative to default-directory.  The result is always a
   directory."
  (setf pathname (pathname pathname))
  (flet ((return-with-slash (pathname)
	   (let ((ns (namestring pathname)))
	     (declare (simple-string ns))
	     (if (char= #\/ (schar ns (1- (length ns))))
		 pathname
		 (pathname (concatenate 'simple-string ns "/"))))))
    (let ((dir (pathname-directory pathname)))
      (if dir
	  (let ((dev (pathname-device pathname)))
	    (if (eq dev :absolute)
		(return-with-slash pathname)
		(return-with-slash
		    (make-pathname :device (pathname-device default-directory)
				   :directory
				   (concatenate
				    'simple-vector
				    (pathname-directory default-directory)
				    dir)
				   :defaults pathname))))
	  (return-with-slash (merge-pathnames pathname default-directory))))))

(defun directoryp (pathname)
  (not (or (pathname-name pathname) (pathname-type pathname))))



;;;; I/O specials and initialization

(defvar *editor-input* nil
  "Input stream to get unechoed unbuffered terminal input.")

(defvar *real-editor-input* ()
  "The real editor input stream.  Useful when we want to read from the
  terminal when *editor-input* is rebound.")


;;; File descriptor for the terminal.
;;; 
(defvar *editor-file-descriptor*)


;;; This is a hack, so screen can tell how to initialize screen management
;;; without re-opening the display.  It is set in INIT-RAW-IO and referenced
;;; in WINDOWED-MONITOR-P.
;;; 
(defvar *editor-windowed-input* nil)


;;; These are used for selecting X events.
;;; 
;;; This says to send :key-press, :button-press, :button-release, :enter-notify,
;;; and :leave-notify events.
;;;
(defconstant input/boundary-xevents-selection-keys
  '(:key-press :button-press :button-release :enter-window :leave-window))
(defconstant input/boundary-xevents-mask
  (apply #'xlib:make-event-mask input/boundary-xevents-selection-keys))
;;;
;;; This says to send :exposure, :destroy-notify, :unmap-notify, :map-notify,
;;; :reparent-notify, :configure-notify, :gravity-notify, and :circulate-notify
;;; in addition to the above events.  Of those enumerated here, we only care
;;; about :exposure and :configure-notify.
;;;
(defconstant interesting-xevents-receive-keys
  '(:key-press :button-press :button-release :enter-notify :leave-notify
    :exposure :graphics-exposure :configure-notify :destroy-notify :unmap-notify
    :map-notify :reparent-notify :gravity-notify :circulate-notify))
(defconstant interesting-xevents-mask
  (apply #'xlib:make-event-mask
	 (append input/boundary-xevents-selection-keys
		 '(:exposure :structure-notify))))

(defconstant random-typeout-xevents-mask
  (apply #'xlib:make-event-mask
	 (append input/boundary-xevents-selection-keys
		 '(:exposure))))


(proclaim '(special ed::*open-paren-highlight-font*
		    ed::*active-region-highlight-font*))

(defparameter lisp-fonts-pathnames
  '("/usr/misc/.lisp/lib/fonts/"
    "/afs/cs.cmu.edu/unix/rt_mach/omega/usr/misc/.lisp/lib/fonts/"))


;;; INIT-RAW-IO  --  Internal
;;;
;;;    This function should be called whenever the editor is entered in a new
;;; lisp.  It sets up process specific data structures.
;;;
(defun init-raw-io (display)
  (setf *editor-windowed-input* nil)
  (cond (display
	 (setf *editor-windowed-input* (ext:open-clx-display display))
	 (setf *editor-input* (make-editor-window-input-stream))
	 (ext:carefully-add-font-paths *editor-windowed-input*
				       lisp-fonts-pathnames)
	 (setup-font-family *editor-windowed-input*
			    (variable-value 'ed::default-font)
			    "8x13u" "8x13bold"))
	(t ;; The editor's file descriptor is Unix standard input (0).
	   ;; We don't need to affect system:*file-input-handlers* here
	   ;; because the init and exit methods for tty redisplay devices
	   ;; take care of this.
	   ;;
	 (setf *editor-file-descriptor* 0)
	 (setf *editor-input* (make-editor-tty-input-stream 0))))
  (setf *real-editor-input* *editor-input*)
  *editor-windowed-input*)

;;; Stop flaming from compiler due to CLX macros expanding into illegal
;;; declarations.
;;;
(proclaim '(declaration values))
(proclaim '(special *default-font-family*))

;;; font-map-size should be defined in font.lisp, but SETUP-FONT-FAMILY would
;;; assume it to be special, issuing a nasty warning.
;;;
(defconstant font-map-size 16
  "The number of possible fonts in a font-map.")


;;; SETUP-FONT-FAMILY sets *default-font-family*, opening the three font names
;;; passed in.  The font family structure is filled in from the first argument.
;;; Actually, this ignores default-highlight-font and default-open-paren-font
;;; in lieu of "Active Region Highlighting Font" and "Open Paren Highlighting
;;; Font" when these are defined.
;;;
(defun setup-font-family (display default-font default-highlight-font
				  default-open-paren-font)
  (let* ((font-family (make-font-family :map (make-array font-map-size
							 :initial-element 0)
					:cursor-x-offset 0
					:cursor-y-offset 0))
	 (font-family-map (font-family-map font-family)))
    (declare (simple-vector font-family-map))
    (setf *default-font-family* font-family)
    (let ((font (xlib:open-font display default-font)))
      (unless font (error "Cannot open font -- ~S" default-font))
      (fill font-family-map font)
      (let ((width (xlib:max-char-width font)))
	(setf (font-family-width font-family) width)
	(setf (font-family-cursor-width font-family) width))
      (let* ((baseline (xlib:font-ascent font))
	     (height (+ baseline (xlib:font-descent font))))
	(setf (font-family-height font-family) height)
	(setf (font-family-cursor-height font-family) height)
	(setf (font-family-baseline font-family) baseline)))
    (setup-one-font display
		    (or (variable-value 'ed::open-paren-highlighting-font)
			default-open-paren-font)
		    font-family-map
		    ed::*open-paren-highlight-font*)
    (setup-one-font display
		    (or (variable-value 'ed::active-region-highlighting-font)
			default-highlight-font)
		    font-family-map
		    ed::*active-region-highlight-font*)))

;;; SETUP-ONE-FONT tries to open font-name for display, storing the result in
;;; font-family-map at index.  XLIB:OPEN-FONT will return font stuff regardless
;;; if the request is valid or not, so we finish the output to get synch'ed
;;; with the server which will cause any errors to get signaled.  At this
;;; level, we want to deal with this error here returning nil if the font
;;; couldn't be opened.
;;;
(defun setup-one-font (display font-name font-family-map index)
  (handler-case (let ((font (xlib:open-font display (namestring font-name))))
		  (xlib:display-finish-output display)
		  (setf (svref font-family-map index) font))
    (xlib:name-error ()
     (warn "Cannot open font -- ~S" font-name)
     nil)))



;;;; HEMLOCK-BEEP.

(defvar *editor-bell* (make-string 1 :initial-element #\bell))

;;; TTY-BEEP is used in Hemlock for beeping when running under a terminal.
;;; Send a #\bell to unix standard output.
;;;
(defun tty-beep (&optional device stream)
  (declare (ignore device stream))
  (when (variable-value 'ed::bell-style)
    (mach:unix-write 1 *editor-bell* 0 1)))

(proclaim '(special *current-window*))

;;; BITMAP-BEEP is used in Hemlock for beeping when running under windowed
;;; input.
;;;
(defun bitmap-beep (display stream)
  (declare (ignore stream))
  (ecase (variable-value 'ed::bell-style)
    (:border-flash
     (flash-window-border *current-window*))
    (:feep
     (xlib:bell display)
     (xlib:display-force-output display))
    (:border-flash-and-feep
     (xlib:bell display)
     (xlib:display-force-output display)
     (flash-window-border *current-window*))
    (:flash
     (flash-window *current-window*))
    (:flash-and-feep
     (xlib:bell display)
     (xlib:display-force-output display)
     (flash-window *current-window*))
    ((nil) ;Do nothing.
     )))

(proclaim '(special *foreground-background-xor*))

(defun flash-window-border (window)
  (let* ((hunk (window-hunk window))
	 (xwin (bitmap-hunk-xwindow hunk))
	 (gcontext (bitmap-hunk-gcontext hunk))
	 (display (bitmap-device-display (device-hunk-device hunk)))
	 (border (variable-value 'ed::beep-border-width))
	 (h (or (bitmap-hunk-modeline-pos hunk) (bitmap-hunk-height hunk)))
	 (top-border (min (ash h -1) border))
	 (w (bitmap-hunk-width hunk))
	 (side-border (min (ash w -1) border))
	 (top-width (max 0 (- w (ash side-border 1))))
	 (right-x (- w side-border))
	 (bottom-y (- h top-border)))
    (xlib:with-gcontext (gcontext :function xlib::boole-xor
				  :foreground *foreground-background-xor*)
      (dotimes (i 8)
	(xlib:draw-rectangle xwin gcontext 0 0 side-border h t)
	(xlib:display-force-output display)
	(xlib:draw-rectangle xwin gcontext side-border bottom-y
			     top-width top-border t)
	(xlib:display-force-output display)
	(xlib:draw-rectangle xwin gcontext right-x 0 side-border h t)
	(xlib:display-force-output display)
	(xlib:draw-rectangle xwin gcontext side-border 0 top-width top-border t)
	(xlib:display-force-output display)))))

(defun flash-window (window)
  (let* ((hunk (window-hunk window))
	 (xwin (bitmap-hunk-xwindow hunk))
	 (gcontext (bitmap-hunk-gcontext hunk))
	 (display (bitmap-device-display (device-hunk-device hunk)))
	 (width (bitmap-hunk-width hunk))
	 (height (or (bitmap-hunk-modeline-pos hunk)
		     (bitmap-hunk-height hunk))))
    (xlib:with-gcontext (gcontext :function xlib::boole-xor
				  :foreground *foreground-background-xor*)
      (xlib:draw-rectangle xwin gcontext 0 0 width height t)
      (xlib:display-force-output display)
      (xlib:draw-rectangle xwin gcontext 0 0 width height t)
      (xlib:display-force-output display))))



(defun hemlock-beep (stream)
  "Using the current window, calls the device's beep function on stream."
  (let ((device (device-hunk-device (window-hunk (current-window)))))
    (funcall (device-beep device) (bitmap-device-display device) stream)))



;;;; GC messages.

;;; HEMLOCK-GC-NOTIFY-BEFORE and HEMLOCK-GC-NOTIFY-AFTER both MESSAGE GC
;;; notifications when Hemlock is not running under X11.  It cannot affect
;;; its window's without using its display connection.  Since GC can occur
;;; inside CLX request functions, using the same display confuses CLX.
;;;

(defun hemlock-gc-notify-before (bytes-in-use)
  (let ((control "~%[GC threshold exceeded with ~:D bytes in use.  ~
  		  Commencing GC.]~%"))
    (cond ((not hi::*editor-windowed-input*)
	   (beep)
	   #|(message control bytes-in-use)|#)
	  (t
	   ;; Can't call BEEP since it would use Hemlock's display connection.
	   (lisp::default-beep-function *standard-output*)
	   (format t control bytes-in-use)
	   (finish-output)))))

(defun hemlock-gc-notify-after (bytes-retained bytes-freed trigger)
  (let ((control
	 "[GC completed with ~:D bytes retained and ~:D bytes freed.]~%~
	  [GC will next occur when at least ~:D bytes are in use.]~%"))
    (cond ((not hi::*editor-windowed-input*)
	   (beep)
	   #|(message control bytes-retained bytes-freed)|#)
	  (t
	   ;; Can't call BEEP since it would use Hemlock's display connection.
	   (lisp::default-beep-function *standard-output*)
	   (format t control bytes-retained bytes-freed trigger)
	   (finish-output)))))



;;;; Site-Wrapper-Macro and standard device init/exit functions.

(defun in-hemlock-standard-input-read (stream &rest ignore)
  (declare (ignore ignore))
  (error "You cannot read off this stream while in Hemlock -- ~S"
	 stream))

(defvar *illegal-read-stream*
  (lisp::make-stream :in #'in-hemlock-standard-input-read))

(defmacro site-wrapper-macro (&body body)
  `(unwind-protect
     (progn
       (when *editor-has-been-entered*
	 (let ((device (device-hunk-device (window-hunk (current-window)))))
	   (funcall (device-init device) device)))
       (let ((*beep-function* #'hemlock-beep)
	     (*gc-notify-before* #'hemlock-gc-notify-before)
	     (*gc-notify-after* #'hemlock-gc-notify-after)
	     (*standard-input* *illegal-read-stream*)
	     (*query-io* *illegal-read-stream*))
	 (cond ((not *editor-windowed-input*)
		,@body)
	       (t
		(ext:with-clx-event-handling
		    (*editor-windowed-input* #'ext:object-set-event-handler)
		  ,@body)))))
     (let ((device (device-hunk-device (window-hunk (current-window)))))
       (funcall (device-exit device) device))))

(defun standard-device-init ()
  (setup-input))

(defun standard-device-exit ()
  (reset-input))

(proclaim '(special *echo-area-window*))

;;; Maybe bury/unbury hemlock window when we go to and from Lisp.
;;; This should do something more sophisticated when we know what that is.
;;; 
(defun default-hemlock-window-mngt (display on)
  (let ((win (bitmap-hunk-xwindow (window-hunk *current-window*)))
	(ewin (bitmap-hunk-xwindow (window-hunk *echo-area-window*))))
    (cond (on (setf (xlib:window-priority ewin) :above)
	      (clear-input *editor-input*)
	      (setf (xlib:window-priority win) :above))
	  (t (setf (xlib:window-priority ewin) :below)
	     (setf (xlib:window-priority win) :below))))
  (xlib:display-force-output display))

(defvar *hemlock-window-mngt* #'default-hemlock-window-mngt
  "This function is called by HEMLOCK-WINDOW, passing its arguments.  This may
   be nil.")

(defun hemlock-window (display on)
  "Calls *hemlock-window-mngt* on the argument ON when *current-window* is
  bound.  This is called in the device init and exit methods for X bitmap
  devices."
  (when (and *hemlock-window-mngt* *current-window*)
    (funcall *hemlock-window-mngt* display on)))



;;;; Current terminal character translation.

(defvar *terminal-translation-table* (make-array 128))

;;; Converting ASCII control characters to Common Lisp control characters:
;;; ASCII control character codes are separated from the codes of the
;;; "non-controlified" characters by the code of atsign.  The ASCII control
;;; character codes range from ^@ (0) through ^_ (one less than the code of
;;; space).  We iterate over this range adding the ASCII code of atsign to
;;; get the "non-controlified" character code.  With each of these, we turn
;;; the code into a Common Lisp character and set its :control bit.  Certain
;;; ASCII control characters have to be translated to special Common Lisp
;;; characters outside of the loop.
;;;    With the advent of Hemlock running under X, and all the key bindings
;;; changing, we also downcase each Common Lisp character (where normally
;;; control characters come in upcased) in an effort to obtain normal command
;;; bindings.  Commands bound to uppercase modified characters will not be
;;; accessible to terminal interaction.
;;; 
(let ((@-code (char-code #\@)))
  (dotimes (i (char-code #\space))
    (setf (svref *terminal-translation-table* i)
	  (set-char-bit (char-downcase (code-char (+ i @-code))) :control t))))
(setf (svref *terminal-translation-table* 9) #\tab)
(setf (svref *terminal-translation-table* 10) #\linefeed)
(setf (svref *terminal-translation-table* 13) #\return)
(setf (svref *terminal-translation-table* 27) #\alt)
(setf (svref *terminal-translation-table* 8) #\backspace)
;;;
;;; Other ASCII codes are exactly the same as the Common Lisp codes.
;;; 
(do ((i (char-code #\space) (1+ i)))
    ((= i 128))
  (setf (svref *terminal-translation-table* i) (code-char i)))

;;; TRANSLATE-TTY-CHAR is our interface to be used in GET-EDITOR-INPUT.
;;; 
(proclaim '(inline translate-tty-char))
(defun translate-tty-char (char)
  (svref *terminal-translation-table* char))


(defconstant termcap-file "/etc/termcap")

(defun cl-termcap-char (char)
  (if (char-bit char :control)
      (code-char (the fixnum
		      (- (the fixnum (char-code char))
			 64))) ;(char-code #\@)
      (case char
	(#\alt (code-char 27))
	(#\newline (code-char 10))
	(#\return (code-char 13))
	(#\tab (code-char 9))
	(#\backspace (code-char 8))
	(#\formfeed (code-char 12))
	(t char))))



;;;; Common editor input: stream def, event queue mngt, kbdmac waiting,
;;;; more prompt, input method macro.

;;; This is the basic editor stream definition.  More particular stream
;;; definitions below include this.
;;; 
(defstruct (editor-input-stream
	    (:include stream)
	    (:print-function
	     (lambda (s stream d)
	       (declare (ignore s d))
	       (write-string "#<Editor-Input stream>" stream)))
	    (:constructor make-editor-input-stream
			  (head &optional (tail head))))
  ;;
  ;; FIFO queue of events on this stream.  The queue always contains
  ;; at least one one element, which is the character most recently read.
  ;; If no event has been read, the event is a dummy with a NIL char.
  head		; First key event in queue.
  tail)		; Last event in queue.


;;; Key event queue.
;;; 

(defstruct (key-event
	    (:constructor make-key-event ())) 
  next		; Next queued event, or NIL if none.
  hunk		; Screen hunk event was read from.
  char		; Character read.
  x		; X and Y character position of mouse cursor.
  y
  unread-p)

(defvar *free-key-events* ())

(defun new-event (char x y hunk next &optional unread-p)
  (let ((res (if *free-key-events*
		 (shiftf *free-key-events* (key-event-next *free-key-events*))
		 (make-key-event))))
    (setf (key-event-char res) char)
    (setf (key-event-x res) x)
    (setf (key-event-y res) y)
    (setf (key-event-hunk res) hunk)
    (setf (key-event-next res) next)
    (setf (key-event-unread-p res) unread-p)
    res))

(defvar *last-character-typed* ()
  "This variable contains the last character typed to the command
  interpreter.") 

;;; *character-history* is setup in SITE-INIT.
;;;
(defvar *character-history* nil
  "This ring holds the last 60 characters read by the command interpreter.")

(proclaim '(special *input-transcript*))

;;; DQ-EVENT is used in editor stream methods for popping off input.
;;; If there is an event not yet read in Stream, then pop the queue
;;; and return the character.  If there is none, return NIL.
;;;
(defun dq-event (stream)
  (without-interrupts
   (let* ((head (editor-input-stream-head stream))
	  (next (key-event-next head)))
     (if next
	 (let ((char (key-event-char next)))
	   (setf (editor-input-stream-head stream) next)
	   (shiftf (key-event-next head) *free-key-events* head)
	   (ring-push char *character-history*)
	   (setq *last-character-typed* char)
	   (when *input-transcript* 
	     (vector-push-extend char *input-transcript*))
	   char)))))

;;; Q-EVENT is used in low level input fetching routines to add input to the
;;; editor stream.
;;; 
(defun q-event (stream char &optional x y hunk)
  (without-interrupts
   (let ((new (new-event char x y hunk nil))
	 (tail (editor-input-stream-tail stream)))
     (setf (key-event-next tail) new)
     (setf (editor-input-stream-tail stream) new))))

(defun un-event (char stream)
  (without-interrupts
   (let* ((head (editor-input-stream-head stream))
	  (next (key-event-next head))
	  (new (new-event char (key-event-x head) (key-event-y head)
			  (key-event-hunk head) next t)))
     (setf (key-event-next head) new)
     (unless next (setf (editor-input-stream-tail stream) new)))))


;;; Keyboard macro hacks.
;;; 

(defvar *input-transcript* ()
  "If this variable is non-null then it should contain an adjustable vector
  with a fill pointer into which all keyboard input will be pushed.")

;;; INPUT-WAITING  --  Internal
;;;
;;;    An Evil hack that tells us whether there is an unread character on
;;; *editor-input*.  Note that this is applied to the real *editor-input*
;;; rather than to a kbdmac stream.
;;;
(defun input-waiting ()
  "Returns true if there is a character which has been unread-char'ed
   on *editor-input*.  Used by the keyboard macro stuff."
  (let ((next (key-event-next (editor-input-stream-head *real-editor-input*))))
    (and next (key-event-unread-p next))))


;;; Random typeout hacks.
;;; 

(defun wait-for-more (stream)
  (let ((ch (more-read-ch)))
    (cond ((logical-char= ch :yes))
	  ((or (logical-char= ch :do-all)
	       (logical-char= ch :exit))
	   (setf (random-typeout-stream-no-prompt stream) t)
	   (random-typeout-cleanup stream))
	  ((logical-char= ch :keep)
	   (setf (random-typeout-stream-no-prompt stream) t)
	   (maybe-keep-random-typeout-window stream)
	   (random-typeout-cleanup stream))
	  ((logical-char= ch :no)
	   (random-typeout-cleanup stream)
	   (throw 'more-punt nil))
	  (t
	   (unread-char ch *editor-input*)
	   (random-typeout-cleanup stream)
	   (throw 'more-punt nil)))))

(proclaim '(special *more-prompt-action*))

(defun maybe-keep-random-typeout-window (stream)
  (let* ((window (random-typeout-stream-window stream))
	 (buffer (window-buffer window))
	 (start (buffer-start-mark buffer)))
    (when (typep (hi::device-hunk-device (hi::window-hunk window))
		 'hi::bitmap-device)
      (let ((*more-prompt-action* :normal))
	(update-modeline-field buffer window :more-prompt)
	(random-typeout-redisplay window))
      (buffer-start (buffer-point buffer))
      (unless (make-window start :window (make-xwindow-like-hwindow window))
	(editor-error "Could not create random typeout window.")))))

(defun end-random-typeout (stream)
  (let ((*more-prompt-action* :flush)
	(window (random-typeout-stream-window stream)))
    (update-modeline-field (window-buffer window) window :more-prompt)
    (random-typeout-redisplay window))
  (unless (random-typeout-stream-no-prompt stream)
    (let* ((ch (more-read-ch))
	   (keep-p (logical-char= ch :keep)))
      (when keep-p (maybe-keep-random-typeout-window stream))
      (random-typeout-cleanup stream)
      (unless (or (logical-char= ch :do-all)
		  (logical-char= ch :exit)
		  (logical-char= ch :no)
		  (logical-char= ch :yes)
		  keep-p)
	(unread-char ch *editor-input*)))))

;;; MORE-READ-CH gets some input from the type of stream bound to
;;; *editor-input*.  Need to loop over SERVE-EVENT since it returns on any kind
;;; of event (not necessarily a key or button event).
;;;
;;; Currently this does not work for keyboard macro streams!
;;; 
(defun more-read-ch ()
  (clear-input *editor-input*)
  (let ((ch (do ((ch (dq-event *editor-input*) (dq-event *editor-input*)))
		(ch ch)
	      (system:serve-event))))
    (when (or (char= ch #\control-g) (char= ch #\control-\g))
      (beep)
      (throw 'editor-top-level-catcher nil))
    ch))


;;; Input method macro.
;;; 

(defvar *in-hemlock-stream-input-method* nil
  "This keeps us from undefined nasties like re-entering Hemlock stream
   input methods from input hooks and scheduled events.")

(proclaim '(special *screen-image-trashed*))

;;; EDITOR-INPUT-METHOD-MACRO is used in EDITOR-TTY-IN and EDITOR-WINDOW-IN.
;;; Somewhat odd stuff goes on here because this is the place where Hemlock
;;; waits, so this is where we redisplay, check the time for scheduled
;;; events, etc.  In the loop, we call the input hook when we get a character
;;; and leave the loop.  If there isn't any input, invoke any scheduled
;;; events whose time is up.  Unless SERVE-EVENT returns immediately and did
;;; something, (serve-event 0), call redisplay, note that we are going into
;;; a read wait, and call SERVE-EVENT with a wait or infinite timeout.  Upon
;;; exiting the loop, turn off the read wait note and check for the abort
;;; character.  Return the character we got.
;;; We bind an error condition handler here because the default Hemlock
;;; error handler goes into a little debugging prompt loop, but if we got
;;; an error in getting input, we should prompt the user using the input
;;; method (recursively even).
;;; 
(eval-when (compile eval)
(defmacro editor-input-method-macro (&optional screen-image-trashed-concern)
  `(handler-bind ((error #'(lambda (condition)
			     (let ((device (device-hunk-device
					    (window-hunk (current-window)))))
			       (funcall (device-exit device) device))
			     (invoke-debugger condition))))
;     (when *in-hemlock-stream-input-method*
;       (error "Entering Hemlock stream input method recursively!"))
     (let ((*in-hemlock-stream-input-method* t)
	   (nrw-fun (device-note-read-wait
		     (device-hunk-device (window-hunk (current-window)))))
	   char)
       (loop
	 (when (setf char (dq-event stream))
	   (dolist (f (variable-value 'ed::input-hook)) (funcall f))
	   (return))
	 (invoke-scheduled-events)
	 (unless (system:serve-event 0)
	   (internal-redisplay)
	   ,@(if screen-image-trashed-concern
		 '((when *screen-image-trashed* (internal-redisplay))))
	   (when nrw-fun (funcall nrw-fun t))
	   (let ((wait (next-scheduled-event-wait)))
	     (if wait (system:serve-event wait) (system:serve-event)))))
       (when nrw-fun (funcall nrw-fun nil))
       (when (and (or (char= char #\control-g) (char= char #\control-\g))
		  eof-error-p)
	 (beep)
	 (throw 'editor-top-level-catcher nil))
       char)))
) ;eval-when



;;;; Editor tty input streams.

(defstruct (editor-tty-input-stream
	    (:include editor-input-stream
		      (:in #'editor-tty-in)
		      (:misc #'editor-tty-misc))
	    (:print-function
	     (lambda (obj stream n)
	       (declare (ignore obj n))
	       (write-string "#<Editor-Tty-Input stream>" stream)))
	    (:constructor make-editor-tty-input-stream
			  (fd &optional (head (make-key-event)) (tail head))))
  fd)


(defun editor-tty-misc (stream operation &optional arg1 arg2)
  (declare (ignore arg2))
  (case operation
    (:listen (cond ((key-event-next (editor-input-stream-head stream)) t)
		   ((editor-tty-listen stream) t)
		   (t nil)))
    (:unread
     (un-event arg1 stream))
    (:clear-input
     (without-interrupts
      (let* ((head (editor-input-stream-head stream))
	     (next (key-event-next head)))
	(when next
	  (setf (key-event-next head) nil)
	  (shiftf (key-event-next (editor-input-stream-tail stream))
		  *free-key-events* next)
	  (setf (editor-input-stream-tail stream) head)))))
    (:element-type 'character)))


(defun editor-tty-in (stream eof-error-p eof-value)
  (declare (ignore eof-value))
  (editor-input-method-macro t))



;;;; Editor window input streams.

(defstruct (editor-window-input-stream
	    (:include editor-input-stream
		      (:in #'editor-window-in)
		      (:misc #'editor-window-misc))
	    (:print-function
	     (lambda (s stream d)
	       (declare (ignore s d write))
	       (write-string "#<Editor-Window-Input stream>" stream)))
	    (:constructor make-editor-window-input-stream
			  (&optional (head (make-key-event)) (tail head))))
  hunks)    ; List of bitmap-hunks which input to this stream.


(defun editor-window-misc (stream operation &optional arg1 arg2)
  (declare (ignore arg2))
  (case operation
    (:listen
     (loop (unless (system:serve-event 0)
	     ;; If nothing is pending, check the queued input.
	     (return (not (null (key-event-next
				 (editor-input-stream-head stream))))))
           (when (key-event-next (editor-input-stream-head stream))
	     ;; Don't service anymore events if we just got some input.
	     (return t))))
    (:unread
     (un-event arg1 stream))
    (:clear-input
     (loop (unless (system:serve-event 0) (return)))
     (without-interrupts
      (let* ((head (editor-input-stream-head stream))
	     (next (key-event-next head)))
	(when next
	  (setf (key-event-next head) nil)
	  (shiftf (key-event-next (editor-input-stream-tail stream))
		  *free-key-events* next)
	  (setf (editor-input-stream-tail stream) head)))))
    (:element-type 'character)))


(defun editor-window-in (stream eof-error-p eof-value)
  (declare (ignore eof-value))
  (editor-input-method-macro))



;;; LAST-KEY-EVENT-CURSORPOS  --  Public
;;;
;;;    Just look up the saved info in the last read key event.
;;;
(defun last-key-event-cursorpos ()
  "Return as values, the (X, Y) character position and window where the
  last key event happened.  If this cannot be determined, Nil is returned.
  If in the modeline, return a Y position of NIL and the correct X and window.
  Returns nil for terminal input."
  (let* ((ev (editor-input-stream-head *real-editor-input*))
	 (hunk (key-event-hunk ev))
	 (window (and hunk (device-hunk-window hunk))))
    (when window
      (values (key-event-x ev) (key-event-y ev) window))))


;;; Window-Input-Handler  --  Internal
;;;
;;;    This is the input-handler function for hunks that implement windows.
;;; It just queues the events on the *real-editor-input* stream.
;;;
(defun window-input-handler (hunk char x y)
  (q-event *real-editor-input* char x y hunk))



;;;; Event scheduling.

;;; The time queue provides a ROUGH mechanism for scheduling events to
;;; occur after a given amount of time has passed, optionally repeating
;;; using the given time as an interval for rescheduling.  When the input
;;; loop goes around, it will check the current time and process all events
;;; that should have happened before or at this time.  The function gets
;;; called on the number of seconds that have elapsed since it was last
;;; called.
;;;
;;; NEXT-SCHEDULED-EVENT-WAIT and INVOKE-SCHEDULED-EVENTS are used in the
;;; editor stream in methods.
;;;
;;; SCHEDULE-EVENT and REMOVE-SCHEDULED-EVENT are exported interfaces.

(defstruct (tq-event (:print-function print-tq-event)
		     (:constructor make-tq-event
				   (time last-time interval function)))
  time		; When the event should happen.
  last-time	; When the event was scheduled.
  interval	; When non-nil, how often the event should happen.
  function)	; What to do.

(defun print-tq-event (obj stream n)
  (declare (ignore n))
  (format stream "#<Tq-Event ~S>" (tq-event-function obj)))

(defvar *time-queue* nil
  "This is the time priority queue used in Hemlock input streams for event
   scheduling.")

;;; QUEUE-TIME-EVENT inserts event into the time priority queue *time-queue*.
;;; Event is inserted before the first element that it is less than (which
;;; means that it gets inserted after elements that are the same).
;;; *time-queue* is returned.
;;; 
(defun queue-time-event (event)
  (let ((time (tq-event-time event)))
    (if *time-queue*
	(if (< time (tq-event-time (car *time-queue*)))
	    (push event *time-queue*)
	    (do ((prev *time-queue* rest)
		 (rest (cdr *time-queue*) (cdr rest)))
		((or (null rest)
		     (< time (tq-event-time (car rest))))
		 (push event (cdr prev))
		 *time-queue*)))
	(push event *time-queue*))))

;;; NEXT-SCHEDULED-EVENT-WAIT returns nil or the number of seconds to wait for
;;; the next event to happen.
;;; 
(defun next-scheduled-event-wait ()
  (if *time-queue*
      (let ((wait (round (- (tq-event-time (car *time-queue*))
			    (get-internal-real-time))
			 internal-time-units-per-second)))
	(if (plusp wait) wait 0))))

;;; INVOKE-SCHEDULED-EVENTS invokes all the functions in *time-queue* whose
;;; time has come.  If we run out of events, or there are none, then we get
;;; out.  If we popped an event whose time hasn't come, we push it back on the
;;; queue.  Each function is called on how many seconds, roughly, went by since
;;; the last time it was called (or scheduled).  If it has an interval, we
;;; re-queue it.  While invoking the function, bind *time-queue* to nothing in
;;; case the event function tries to read off *editor-input*.
;;;
(defun invoke-scheduled-events ()
  (let ((time (get-internal-real-time)))
    (loop
      (unless *time-queue* (return))
      (let* ((event (car *time-queue*))
	     (event-time (tq-event-time event)))
	(cond ((>= time event-time)
	       (let ((*time-queue* nil))
		 (funcall (tq-event-function event)
			  (round (- time (tq-event-last-time event))
				 internal-time-units-per-second)))
	       (without-interrupts
		(let ((interval (tq-event-interval event)))
		  (when interval
		    (setf (tq-event-time event) (+ time interval))
		    (setf (tq-event-last-time event) time)
		    (pop *time-queue*)
		    (queue-time-event event)))))
	      (t (return)))))))

(defun schedule-event (time function &optional (repeat t))
  "This causes function to be called after time seconds have passed,
   optionally repeating every time seconds.  This is a rough mechanism
   since commands can take an arbitrary amount of time to run; the function
   will be called at the first possible moment after time has elapsed.
   Function takes the time that has elapsed since the last time it was
   called (or since it was scheduled for the first invocation)."
  (let ((now (get-internal-real-time))
	(itime (* internal-time-units-per-second time)))
    (queue-time-event (make-tq-event (+ itime now) now (if repeat itime)
				     function))))

(defun remove-scheduled-event (function)
  "Removes function queued with SCHEDULE-EVENT."
  (setf *time-queue* (delete function *time-queue* :key #'tq-event-function)))



;;;; Editor sleeping.

(defun editor-sleep (time)
  "Sleep for approximately Time seconds."
  (unless (or (zerop time) (listen *editor-input*))
    (internal-redisplay)
    (sleep-for-time time)
    nil))

(defun sleep-for-time (time)
  (let ((nrw-fun (device-note-read-wait
		  (device-hunk-device (window-hunk (current-window)))))
	(end (+ (get-internal-real-time)
		(truncate (* time internal-time-units-per-second)))))
    (loop
      (when (listen *editor-input*) (return))
      (let ((left (- end (get-internal-real-time))))
	(unless (plusp left) (return nil))
	(when nrw-fun (funcall nrw-fun t))
	(system:serve-event (/ (float left)
			       (float internal-time-units-per-second)))))
    (when nrw-fun (funcall nrw-fun nil))))



;;;; Showing a mark.

(defun show-mark (mark window time)
  "Highlights the position of Mark within Window for Time seconds,
   possibly by moving the cursor there.  If Mark is not displayed within
   Window return NIL.  The wait may be aborted if there is pending input."
  (let* ((result t))
    (catch 'redisplay-catcher
      (redisplay-window window)
      (setf result
	    (multiple-value-bind (x y) (mark-to-cursorpos mark window)
	      (funcall (device-show-mark
			(device-hunk-device (window-hunk window)))
		       window x y time))))
    result))

(defun tty-show-mark (window x y time)
  (cond ((listen *editor-input*))
	(x (internal-redisplay)
	   (let* ((hunk (window-hunk window))
		  (device (device-hunk-device hunk)))
	     (funcall (device-put-cursor device) hunk x y)
	     (when (device-force-output device)
	       (funcall (device-force-output device)))
	     (sleep-for-time time))
	   t)
	(t nil)))

(defun bitmap-show-mark (window x y time)
  (cond ((listen *editor-input*))
	(x (let* ((hunk (window-hunk window))
		  (display (bitmap-device-display (device-hunk-device hunk))))
	     (internal-redisplay)
	     (hunk-show-cursor hunk x y)
	     (drop-cursor)
	     (xlib:display-finish-output display)
	     (sleep-for-time time)
	     (lift-cursor)
	     t))
	(t nil)))



;;;; Funny character stuff.

;;; TEXT-CHARACTER and PRINT-PRETTY-CHARACTER are documented Hemlock primitives.
;;;

(defun text-character (char)
  "Translate a character as read from *editor-input* into one suitable for
   inserting into text.  If this is not possible, nil is returned."
  (cond ((or (char-bit char :meta)
	     (char-bit char :super)
	     (char-bit char :hyper))
	 nil)
	((char= char #\return) #\newline)
	((char-bit char :control)
	 (let* ((nchar (char-upcase (make-char char)))
		(code (char-code nchar)))
	   (if (<= 64 code 95)
	       (code-char (- code 64))
	       nil)))
	(t char)))

(defun print-pretty-character (char stream)
  "Prints char to stream suitably for documentation, data displays, etc.
   Control, Meta, Super, and Hyper bits are shown as C-, M-, S-, and H-,
   respectively.  If the character is not a standard character other than
   #\space or #\newline, and it has a name, then the name is printed."
  (when (char-bit char :control) (write-string "C-" stream))
  (when (char-bit char :meta) (write-string "M-" stream))
  (when (char-bit char :super) (write-string "S-" stream))
  (when (char-bit char :hyper) (write-string "H-" stream))
  (let ((code (char-code char))
	(safe-char (make-char char)))
    (if (<= (char-code #\!) code (char-code #\~))
	(write-char safe-char stream)
	(let ((name (char-name (code-char code))))
	  (cond (name (write-string (string-capitalize name) stream))
		((< code (char-code #\space))
		 (write-char #\^ stream)
		 (write-char (code-char (+ code (char-code #\@))) stream))
		(t
		 (write-char safe-char stream)))))))

(defvar *line-wrap-char* #\!
  "The character to be displayed to indicate wrapped lines.")



;;;; Function description and defined-from.

;;; FUN-DEFINED-FROM-PATHNAME takes a symbol or function object.  It
;;; returns a pathname for the file the function was defined in.  If it was
;;; not defined in some file, then nil is returned.
;;; 
(defun fun-defined-from-pathname (function)
  "Takes a symbol or function and returns the pathname for the file the function
   was defined in.  If it was not defined in some file, nil is returned."
  (typecase function
    (symbol (fun-defined-from-pathname (careful-symbol-function function)))
    (compiled-function
     (let* ((string (%primitive header-ref function
				system:%function-defined-from-slot))
	    (file (subseq string 0 (position #\space string :test #'char=))))
       (declare (simple-string file))
       (if (or (char= #\# (schar file 0))
	       (string-equal file "lisp"))
	   nil
	   (if (string= file "/.." :end1 3)
	       (pathname (subseq file
				 (position #\/ file :test #'char= :start 4)))
	       (pathname file)))))
    (t nil)))


(defvar *editor-describe-stream*
  (system:make-indenting-stream *standard-output*))

;;; EDITOR-DESCRIBE-FUNCTION has to mess around to get indenting streams to
;;; work.  These apparently work fine for DESCRIBE, for which they were defined,
;;; but not in general.  It seems they don't indent initial text, only that
;;; following a newline, so inside our use of INDENTING-FURTHER, we need some
;;; form before the WRITE-STRING.  To get this to work, I had to remove the ~%
;;; from the FORMAT string, and use FRESH-LINE; simply using FRESH-LINE with
;;; the ~% caused an extra blank line.  Possibly I should not have glommed onto
;;; this hack whose interface comes from three different packages, but it did
;;; the right thing ....
;;;
;;; Also, we have set INDENTING-STREAM-STREAM to make sure the indenting stream
;;; is based on whatever *standard-output* is when we are called.
;;;
(defun editor-describe-function (fun sym)
  "Calls DESCRIBE on fun.  If fun is compiled, and its original name is not sym,
   then this also outputs any 'function documentation for sym to
   *standard-output*."
  (describe fun)
  (when (and (compiled-function-p fun)
	     (not (eq (%primitive header-ref fun %function-name-slot) sym)))
    (let ((doc (documentation sym 'function)))
      (when doc
	(format t "~&Function documentation for ~S:" sym)
	(setf (lisp::indenting-stream-stream *editor-describe-stream*)
	      *standard-output*)
	(ext:indenting-further *editor-describe-stream* 2
	  (fresh-line *editor-describe-stream*)
	  (write-string doc *editor-describe-stream*))))))




;;;; X Stuff.

;;; Setting window cursors ...
;;; 

(proclaim '(special *default-foreground-pixel* *default-background-pixel*))

(defvar *hemlock-cursor* nil "Holds cursor for Hemlock windows.")

;;; DEFINE-WINDOW-CURSOR in shoved on the "Make Window Hook".
;;; 
(defun define-window-cursor (window)
  (setf (xlib:window-cursor (bitmap-hunk-xwindow (window-hunk window)))
	*hemlock-cursor*))

;;; These are set in INIT-BITMAP-SCREEN-MANAGER and REVERSE-VIDEO-HOOK-FUN.
;;;
(defvar *cursor-foreground-color* nil)
(defvar *cursor-background-color* nil)
(defun make-white-color () (xlib:make-color :red 1.0 :green 1.0 :blue 1.0))
(defun make-black-color () (xlib:make-color :red 0.0 :green 0.0 :blue 0.0))


;;; GET-HEMLOCK-CURSOR is used in INIT-BITMAP-SCREEN-MANAGER to load the
;;; hemlock cursor for DEFINE-WINDOW-CURSOR.
;;;
(defun get-hemlock-cursor (display)
  (when *hemlock-cursor* (xlib:free-cursor *hemlock-cursor*))
  (let* ((cursor-file (truename (variable-value 'ed::cursor-bitmap-file)))
	 (mask-file (probe-file (make-pathname :type "mask"
					       :defaults cursor-file)))
	 (root (xlib:screen-root (xlib:display-default-screen display)))
	 (mask-pixmap (if mask-file (get-cursor-pixmap root mask-file))))
    (multiple-value-bind (cursor-pixmap cursor-x-hot cursor-y-hot)
			 (get-cursor-pixmap root cursor-file)
      (setf *hemlock-cursor*
	    (xlib:create-cursor :source cursor-pixmap :mask mask-pixmap
				:x cursor-x-hot :y cursor-y-hot
				:foreground *cursor-foreground-color*
				:background *cursor-background-color*))
      (xlib:free-pixmap cursor-pixmap)
      (when mask-pixmap (xlib:free-pixmap mask-pixmap)))))

(defun get-cursor-pixmap (root pathname)
  (let* ((image (xlib:read-bitmap-file pathname))
	 (pixmap (xlib:create-pixmap :width 16 :height 16
				     :depth 1 :drawable root))
	 (gc (xlib:create-gcontext
	      :drawable pixmap :function boole-1
	      :foreground *default-foreground-pixel*
	      :background *default-background-pixel*)))
    (xlib:put-image pixmap gc image :x 0 :y 0 :width 16 :height 16)
    (xlib:free-gcontext gc)
    (values pixmap (xlib:image-x-hot image) (xlib:image-y-hot image))))


;;; Setting up grey borders ...
;;; 

(defparameter hemlock-grey-bitmap-data
  '(#*10 #*01))

(defun get-hemlock-grey-pixmap (display)
  (let* ((screen (xlib:display-default-screen display))
	 (depth (xlib:screen-root-depth screen))
	 (root (xlib:screen-root screen))
	 (height (length hemlock-grey-bitmap-data))
	 (width (length (car hemlock-grey-bitmap-data)))
	 (image (apply #'xlib:bitmap-image hemlock-grey-bitmap-data))
	 (pixmap (xlib:create-pixmap :width width :height height
				     :depth depth :drawable root))
	 (gc (xlib:create-gcontext :drawable pixmap
				   :function boole-1
				   :foreground *default-foreground-pixel*
				   :background *default-background-pixel*)))
    (xlib:put-image pixmap gc image
		    :x 0 :y 0 :width width :height height :bitmap-p t)
    (xlib:free-gcontext gc)
    pixmap))


;;; Cut Buffer manipulation ...
;;;

(defun store-cut-string (display string)
  (check-type string simple-string)
  (setf (xlib:cut-buffer display) string))

(defun fetch-cut-string (display)
  (xlib:cut-buffer display))


;;; Window naming ...
;;;
(defun set-window-name-for-buffer-name (buffer new-name)
  (dolist (ele (buffer-windows buffer))
    (xlib:set-standard-properties (bitmap-hunk-xwindow (window-hunk ele))
				  :icon-name new-name)))
  
(defun set-window-name-for-window-buffer (window new-buffer)
  (xlib:set-standard-properties (bitmap-hunk-xwindow (window-hunk window))
				:icon-name (buffer-name new-buffer)))



;;;; Some hacks for supporting Hemlock under Mach.

;;; WINDOWED-MONITOR-P is used by the reverse video variable's hook function
;;; to determine if it needs to go around fixing all the windows.
;;;
(defun windowed-monitor-p ()
  "This returns whether the monitor is being used with a window system.  It
   returns the console's CLX display structure."
  *editor-windowed-input*)

(defun get-terminal-name ()
  (cdr (assoc :term *environment-list* :test #'eq)))

(defun get-termcap-env-var ()
  (cdr (assoc :termcap *environment-list* :test #'eq)))



(defvar *editor-buffer* (make-string 256))

;;; GET-EDITOR-TTY-INPUT reads from stream's Unix file descriptor queuing events
;;; in the stream's queue.
;;;
(defun get-editor-tty-input (fd)
  (let* ((buf *editor-buffer*)
	 (len (mach:unix-read fd buf 256))
	 (i 0))
    (declare (simple-string buf) (fixnum len i))
    (loop
      (when (>= i len) (return t))
      (q-event *real-editor-input*
	       (translate-tty-char (char-code (schar buf i))))
      (incf i))))

;;; This is used to get listening during smart redisplay to pick up input
;;; in between displaying each line by listening longer (or slowing down
;;; line output depending on your model).  10-20 seems to be good for 9600
;;; baud, and 250 seems to do it with 1200 baud.
;;; 
(defparameter listen-iterations-hack 1) ; 10-20 seems to really pick up input.

(defun editor-tty-listen (stream)
  (mach::with-trap-arg-block mach::int1 nc
    (dotimes (i listen-iterations-hack nil)
      (multiple-value-bind (val err) 
			   (mach::Unix-ioctl (editor-tty-input-stream-fd stream)
					     mach::FIONREAD
					     (lisp::alien-value-sap
					      mach::int1))
	(declare (ignore err))
	(when (and val
		   (> (alien-access (mach::int1-int (alien-value nc))) 0))
	  (return t))))))



(defvar old-flags)

(defvar old-tchars)

(defvar old-ltchars)

(defun setup-input ()
  (let ((fd *editor-file-descriptor*))
    (when (mach:unix-isatty 0)
      (mach:with-trap-arg-block mach:sgtty sg
	(multiple-value-bind
	    (val err)
	    (mach:unix-ioctl fd mach:TIOCGETP
			     (lisp::alien-value-sap mach:sgtty))
	  (if (null val)
	      (error "Could not get tty information, unix error ~S."
		     (mach:get-unix-error-msg err)))
	  (let ((flags (alien-access (mach::sgtty-flags (alien-value sg)))))
	    (setq old-flags flags)
	    (setf (alien-access (mach::sgtty-flags (alien-value sg)))
		  (logand (logior flags mach::tty-cbreak)
			  (lognot mach::tty-echo)
			  (lognot mach::tty-crmod)))
	    (multiple-value-bind
		(val err)
		(mach:unix-ioctl fd mach:TIOCSETP
				 (lisp::alien-value-sap mach:sgtty))
	      (if (null val)
		  (error "Could not set tty information, unix error ~S."
			 (mach:get-unix-error-msg err)))))))
      (mach:with-trap-arg-block mach:tchars tc
	(multiple-value-bind
	    (val err)
	    (mach:unix-ioctl fd mach:TIOCGETC
			     (lisp::alien-value-sap mach:tchars))
	  (if (null val)
	      (error "Could not get tty tchars information, unix error ~S."
		     (mach:get-unix-error-msg err)))
	  (setq old-tchars
		(vector (alien-access (mach::tchars-intrc (alien-value tc)))
			(alien-access (mach::tchars-quitc (alien-value tc)))
			(alien-access (mach::tchars-startc (alien-value tc)))
			(alien-access (mach::tchars-stopc (alien-value tc)))
			(alien-access (mach::tchars-eofc (alien-value tc)))
			(alien-access (mach::tchars-brkc (alien-value tc))))))
	(setf (alien-access (mach::tchars-intrc (alien-value tc)))
	      (if *editor-windowed-input* -1 28))
	(setf (alien-access (mach::tchars-quitc (alien-value tc))) -1)
	(setf (alien-access (mach::tchars-startc (alien-value tc))) -1)
	(setf (alien-access (mach::tchars-stopc (alien-value tc))) -1)
	(setf (alien-access (mach::tchars-eofc (alien-value tc))) -1)
	(setf (alien-access (mach::tchars-brkc (alien-value tc))) -1)
	(multiple-value-bind
	    (val err)
	    (mach:unix-ioctl fd mach:TIOCSETC
			     (lisp::alien-value-sap mach:tchars))
	  (if (null val) (error "Failed to set tchars, unix error ~S."
				(mach:get-unix-error-msg err)))))
      (mach:with-trap-arg-block mach:ltchars tc
	(multiple-value-bind
	    (val err)
	    (mach:unix-ioctl fd mach:TIOCGLTC
			     (lisp::alien-value-sap mach:ltchars))
	  (if (null val)
	      (error "Could not get tty ltchars information, unix error ~S."
		     (mach:get-unix-error-msg err)))
	  (setq old-ltchars
		(vector (alien-access (mach::ltchars-suspc (alien-value tc)))
			(alien-access (mach::ltchars-dsuspc (alien-value tc)))
			(alien-access (mach::ltchars-rprntc (alien-value tc)))
			(alien-access (mach::ltchars-flushc (alien-value tc)))
			(alien-access (mach::ltchars-werasc (alien-value tc)))
			(alien-access (mach::ltchars-lnextc (alien-value tc))))))
	(setf (alien-access (mach::ltchars-suspc (alien-value tc))) -1)
	(setf (alien-access (mach::ltchars-dsuspc (alien-value tc))) -1)
	(setf (alien-access (mach::ltchars-rprntc (alien-value tc))) -1)
	(setf (alien-access (mach::ltchars-flushc (alien-value tc))) -1)
	(setf (alien-access (mach::ltchars-werasc (alien-value tc))) -1)
	(setf (alien-access (mach::ltchars-lnextc (alien-value tc))) -1)
	(multiple-value-bind
	    (val err)
	    (mach:unix-ioctl fd mach:TIOCSLTC
			     (lisp::alien-value-sap mach:ltchars))
	  (if (null val) (error "Failed to set ltchars, unix error ~S."
				(mach:get-unix-error-msg err))))))))

	
(defun reset-input ()
  (when (mach:unix-isatty 0)
    (if (boundp 'old-flags)
	(let ((fd *editor-file-descriptor*))
	  (mach:with-trap-arg-block mach:sgtty sg
	    (multiple-value-bind
		(val err)
		(mach:unix-ioctl fd mach:TIOCGETP
				 (lisp::alien-value-sap mach:sgtty))
	      (if (null val)
		  (error "Could not get tty information, unix error ~S."
			 (mach:get-unix-error-msg err)))
	      (setf (alien-access (mach::sgtty-flags (alien-value sg)))
		    old-flags)
	      (multiple-value-bind
		  (val err)
		  (mach:unix-ioctl fd mach:TIOCSETP
				   (lisp::alien-value-sap mach:sgtty))
		(if (null val)
		    (error "Could not set tty information, unix error ~S."
			   (mach:get-unix-error-msg err))))))
	  (cond ((and (boundp 'old-tchars)
		      (simple-vector-p old-tchars)
		      (eq (length old-tchars) 6))
		 (mach:with-trap-arg-block mach:tchars tc
		   (setf (alien-access (mach::tchars-intrc (alien-value tc)))
			 (svref old-tchars 0))
		   (setf (alien-access (mach::tchars-quitc (alien-value tc)))
			 (svref old-tchars 1))
		   (setf (alien-access (mach::tchars-startc (alien-value tc)))
			 (svref old-tchars 2))
		   (setf (alien-access (mach::tchars-stopc (alien-value tc)))
			 (svref old-tchars 3))
		   (setf (alien-access (mach::tchars-eofc (alien-value tc)))
			 (svref old-tchars 4))
		   (setf (alien-access (mach::tchars-brkc (alien-value tc)))
			 (svref old-tchars 5))
		   (multiple-value-bind
		       (val err)
		       (mach:unix-ioctl fd mach:TIOCSETC
					(lisp::alien-value-sap mach:tchars))
		     (if (null val)
			 (error "Failed to set tchars, unix error ~S."
				(mach:get-unix-error-msg err)))))))
	  (cond ((and (boundp 'old-ltchars)
		      (simple-vector-p old-ltchars)
		      (eq (length old-ltchars) 6))
		 (mach:with-trap-arg-block mach:ltchars tc
		   (setf (alien-access (mach::ltchars-suspc (alien-value tc)))
			 (svref old-ltchars 0))
		   (setf (alien-access (mach::ltchars-dsuspc (alien-value tc)))
			 (svref old-ltchars 1))
		   (setf (alien-access (mach::ltchars-rprntc (alien-value tc)))
			 (svref old-ltchars 2))
		   (setf (alien-access (mach::ltchars-flushc (alien-value tc)))
			 (svref old-ltchars 3))
		   (setf (alien-access (mach::ltchars-werasc (alien-value tc)))
			 (svref old-ltchars 4))
		   (setf (alien-access (mach::ltchars-lnextc (alien-value tc)))
			 (svref old-ltchars 5))
		   (multiple-value-bind
		       (val err)
		       (mach:unix-ioctl fd mach:TIOCSLTC
					(lisp::alien-value-sap mach:ltchars))
		     (if (null val)
			 (error "Failed to set ltchars, unix error ~S."
				(mach:get-unix-error-msg err)))))))))))


(defun pause-hemlock ()
  "Pause hemlock and pop out to the Unix Shell."
  (mach:unix-kill (mach:unix-getpid) mach:sigtstp)
  T)
