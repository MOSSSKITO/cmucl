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
;;;    Written by Bill Chiles.
;;;
;;; Device independent screen management functions.
;;;

(in-package "HEMLOCK-INTERNALS")

(export '(make-window delete-window next-window previous-window))



;;;; Screen management initialization.

(proclaim '(special *echo-area-buffer*))

;;; %INIT-SCREEN-MANAGER creates the initial windows and sets up the data
;;; structures used by the screen manager.  The "Main" and "Echo Area" buffer
;;; modelines are set here in case the user modified these Hemlock variables in
;;; his init file.  Since these buffers don't have windows yet, these sets
;;; won't cause any updates to occur.  This is called from %INIT-REDISPLAY.
;;;
(defun %init-screen-manager (display)
  (setf (buffer-modeline-fields *current-buffer*)
	(value ed::default-modeline-fields))
  (setf (buffer-modeline-fields *echo-area-buffer*)
	(value ed::default-status-line-fields))
  (if (windowed-monitor-p)
      (init-bitmap-screen-manager display)
      (init-tty-screen-manager (get-terminal-name))))



;;;; Window operations.

(defun make-window (start &key
			  (modelinep t)
			  (device nil)
			  window
			  (font-family *default-font-family*)
			  (ask-user nil)
			  x y
			  (width (value ed::default-window-width))
			  (height (value ed::default-window-height)))
  "Make a window that displays text starting at the mark Start.

   Modelinep specifies whether the window should display buffer modelines.

   Device is the Hemlock device to make the window on.  If it is nil, then
   the window is made on the same device as CURRENT-WINDOW.

   Window is an X window to be used for the Hemlock window.  If not specified,
   we make one by calling the function in *create-window-hook*.  This hook maps
   the window to the screen.

   Font-Family is the font-family used for displaying text in the window.

   If Ask-User is non-nil, the user is prompted for missing X, Y, Width, and
   Height arguments.  X and Y are supplied as pixels, but Width and Height are
   supplied in characters.  Otherwise, the current window's height is halved,
   and the new window fills the created space.  If halving the current window
   results in too small of a window, then a new one is made the same size as
   the current, offsetting its vertical placement on the screen some pixels."
  
  (let* ((device (or device (device-hunk-device (window-hunk (current-window)))))
	 (window (funcall (device-make-window device)
			  device start modelinep window font-family
			  ask-user x y width height)))
    (unless window (editor-error "Could not make a window."))
    (invoke-hook ed::make-window-hook window)
    window))

(defun delete-window (window)
  "Make Window go away, removing it from the screen.  Uses *delete-window-hook*
   to get rid of bitmap window system windows."
  (when (eq window *current-window*)
    (error "Cannot kill the current window."))
  (invoke-hook ed::delete-window-hook window)
  (setq *window-list* (delq window *window-list*))
  (funcall (device-delete-window (device-hunk-device (window-hunk window)))
	   window))

(defun next-window (window)
  "Return the next window after Window, wrapping around if Window is the
  bottom window."
  (check-type window window)
  (funcall (device-next-window (device-hunk-device (window-hunk window)))
	   window))

(defun previous-window (window)
  "Return the previous window after Window, wrapping around if Window is the
  top window."
  (check-type window window)
  (funcall (device-previous-window (device-hunk-device (window-hunk window)))
	   window))



;;;; Random typeout support.

;;; PREPARE-FOR-RANDOM-TYPEOUT  --  Internal
;;;
;;; The WITH-POP-UP-DISPLAY macro calls this just before displaying output
;;; for the user.  This goes to some effor to compute the height of the window
;;; in text lines if it is not supplied.  Whether it is supplied or not, we
;;; add one to the height for the modeline, and we subtract one line if the
;;; last line is empty.  Just before using the height, make sure it is at
;;; least two -- one for the modeline and one for text, so window making
;;; primitives don't puke.
;;;
(defun prepare-for-random-typeout (stream height)
  (let* ((buffer (line-buffer (mark-line (random-typeout-stream-mark stream))))
	 (real-height (1+ (or height (rt-count-lines buffer))))
	 (device (device-hunk-device (window-hunk (current-window)))))
    (funcall (device-random-typeout-setup device) device stream
	     (max (if (and (empty-line-p (buffer-end-mark buffer)) (not height))
		      (1- real-height)
		      real-height)
		  2))))

;;; RT-COUNT-LINES computes the correct height for a window.  This includes
;;; taking wrapping line characters into account.  Take the MARK-COLUMN at
;;; the end of each line.  This is how many characters long hemlock thinks
;;; the line is.  When it is displayed, however, end of line characters are
;;; added to the end of each line that wraps.  The second INCF form adds
;;; these to the current line length.  Then INCF the current height by the
;;; CEILING of the width of the random typeout window and the line length
;;; (with added line-end chars).  Use CEILING because there is always at
;;; least one line.  Finally, jump out of the loop if we're at the end of
;;; the buffer.
;;;
(defun rt-count-lines (buffer)
  (with-mark ((mark (buffer-start-mark buffer)))
    (let ((width (window-width (current-window)))
	  (count 0))
	(loop
	  (let* ((column (mark-column (line-end mark)))
		 (temp (ceiling (incf column (floor (1- column) width))
				width)))
	    ;; Lines with no characters yield zero temp.
	    (incf count (if (zerop temp) 1 temp))
	    (unless (line-offset mark 1) (return count)))))))


;;; RANDOM-TYPEOUT-CLEANUP  --  Internal
;;;
;;;    Clean up after random typeout.  This clears the area where the 
;;; random typeout was and redisplays any affected windows.
;;;
(defun random-typeout-cleanup (stream &optional (degree t))
  (let* ((window (random-typeout-stream-window stream))
	 (buffer (window-buffer window))
	 (device (device-hunk-device (window-hunk window)))
	 (*more-prompt-action* :normal))
    (update-modeline-field buffer window :more-prompt)
    (random-typeout-redisplay window)
    (setf (buffer-windows buffer) (delete window (buffer-windows buffer)))
    (funcall (device-random-typeout-cleanup device) stream degree)
    (when (device-force-output device)
      (funcall (device-force-output device)))))

;;; *more-prompt-action* is bound in random typeout streams before
;;; redisplaying.
;;;
(defvar *more-prompt-action* :normal)
(defvar *random-typeout-ml-fields*
  (list (make-modeline-field
	 :name :more-prompt
	 :function #'(lambda (buffer window)
		       (declare (ignore buffer window))
		       (ecase *more-prompt-action*
			 (:more "--More--")
			 (:flush "--Flush--")
			 (:empty "")
			 (:normal
			  (concatenate 'simple-string
				       "Random Typeout Buffer          ["
				       (buffer-name buffer)
				       "]")))))))
