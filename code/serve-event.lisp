;;; -*- Log: code.log; Package: LISP -*-

;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
(ext:file-comment
  "$Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/code/serve-event.lisp,v 1.11 1991/05/23 16:30:20 ram Exp $")
;;;
;;; **********************************************************************
;;;
;;; SYSTEM:SERVE-EVENT, now in it's own file.
;;;
;;; Re-written by William Lott, July 1989 - January 1990.
;;; 
;;; **********************************************************************

(in-package "SYSTEM")

(export '(with-fd-handler add-fd-handler remove-fd-handler invalidate-descriptor
	  serve-event serve-all-events wait-until-fd-usable))

(in-package "EXTENSIONS")

(export '(*display-event-handlers*))

(in-package "LISP")



;;;; MACH Message receiving noise.

(defvar *in-server* NIL
  "*In-server* is set to T when the SIGMSG interrupt has been enabled
  in Server.")

#|

(defvar server-unique-object (cons 1 2)
  "Object thrown by the message interrupt handler.")

(defconstant server-message-size 4096)
(defalien server-message server-message (bytes server-message-size) 0)

(define-alien-stack server-message server-message (bytes server-message-size))

(defrecord server-message
  (msg mach:msg #.(record-size 'mach:msg)))
  
;;; Grab-message-loop calls the appropiate handler for an IPC message.
(defun grab-message-loop ()
  (let ((done-any nil))
    (loop
      (if (eql (server-grab-message)
	       mach:rcv-timed-out)
	(return done-any)
	(setf done-any t)))))


(defun server-grab-message ()
  (with-stack-alien (sm server-message)
    (alien-bind ((msg (server-message-msg (alien-value sm))))
      (setf (alien-access (mach:msg-msgsize (alien-value msg)))
	    server-message-size)
      (setf (alien-access (mach:msg-localport (alien-value msg)))
	    mach::port-enabled)
      (let ((gr (mach:msg-receive (alien-value sm) mach::rcv-timeout 0)))
	(when (eql gr mach:rcv-timed-out)
	  (return-from server-grab-message gr))
	(unless (eql gr mach:rcv-success)
	  (gr-error 'mach:msg-receive gr))
	(let* ((server-message (alien-value sm))
	       (port (alien-access (mach:msg-localport (alien-value msg))))
	       (id (alien-access (mach:msg-id (alien-value msg))))
	       (x (gethash port *port-table*))
	       (set (cdr x)))
	  (unless x
	    (error "~D is not known to server (operation: ~D)." port id))
	  (let ((gr (funcall (gethash id (object-set-table set)
				      (object-set-default-handler set))
			     (car x))))
	    (unless (eql gr mach:kern-success)
	      (gr-error 'server gr)))))))
  mach:kern-success)
|#


;;;; File descriptor IO noise.

(defstruct (handler
	    (:print-function %print-handler)
	    (:constructor make-handler (direction descriptor function)))
  (direction nil :type (member :input :output)) ; Either :input or :output
  (descriptor 0 :type (mod 32)) ; File descriptor this handler is tied to.
  active		      ; T iff this handler is running.
  (function nil :type function) ; Function to call.
  bogus			      ; T if this descriptor is bogus. 
  )

(defun %print-handler (handler stream depth)
  (declare (ignore depth))
  (format stream "#<Handler for ~A on ~:[~;BOGUS ~]descriptor ~D: ~S>"
	  (handler-direction handler)
	  (handler-bogus handler)
	  (handler-descriptor handler)
	  (handler-function handler)))

(defvar *descriptor-handlers* nil
  "List of all the currently active handlers for file descriptors")


;;; ADD-FD-HANDLER -- public
;;;
;;;   Add a new handler to *descriptor-handlers*.
;;;
(defun add-fd-handler (fd direction function)
  "Arange to call FUNCTION whenever FD is usable. DIRECTION should be
  either :INPUT or :OUTPUT. The value returned should be passed to
  SYSTEM:REMOVE-FD-HANDLER when it is no longer needed."
  (assert (member direction '(:input :output))
	  (direction)
	  "Invalid direction ~S, must be either :INPUT or :OUTPUT" direction)
  (let ((handler (make-handler direction fd function)))
    (push handler *descriptor-handlers*)
    handler))

;;; REMOVE-FD-HANDLER -- public
;;;
;;;   Remove an old handler from *descriptor-handlers*.
;;;
(defun remove-fd-handler (handler)
  "Removes HANDLER from the list of active handlers."
  (setf *descriptor-handlers*
	(delete handler *descriptor-handlers*
		:test #'eq)))

;;; INVALIDATE-DESCRIPTOR -- public
;;;
;;;   Search *descriptor-handlers* for any reference to fd, and nuke 'em.
;;; 
(defun invalidate-descriptor (fd)
  "Remove any handers refering to fd. This should only be used when attempting
  to recover from a detected inconsistancy."
  (setf *descriptor-handlers*
	(delete fd *descriptor-handlers*
		:key #'handler-descriptor)))

;;; WITH-FD-HANDLER -- Public.
;;;
;;; Add the handler to *descriptor-handlers* for the duration of BODY.
;;;
(defmacro with-fd-handler ((fd direction function) &rest body)
  "Establish a handler with SYSTEM:ADD-FD-HANDLER for the duration of BODY.
   DIRECTION should be either :INPUT or :OUTPUT, FD is the file descriptor to
   use, and FUNCTION is the function to call whenever FD is usable."
  (let ((handler (gensym)))
    `(let (,handler)
       (unwind-protect
	   (progn
	     (setf ,handler (add-fd-handler ,fd ,direction ,function))
	     ,@body)
	 (when ,handler
	   (remove-fd-handler ,handler))))))

;;; WAIT-UNTIL-FD-USABLE -- Public.
;;;
;;; Wait until FD is usable for DIRECTION. The timeout given to serve-event is
;;; recalculated each time through the loop so that WAIT-UNTIL-FD-USABLE will
;;; timeout at the correct time irrespective of how many events are handled in
;;; the meantime.
;;;
(defun wait-until-fd-usable (fd direction &optional timeout)
  "Wait until FD is usable for DIRECTION. DIRECTION should be either :INPUT or
  :OUTPUT. TIMEOUT, if supplied, is the number of seconds to wait before giving
  up."
  (declare (type (or index null) timeout))
  (let (usable)
    (multiple-value-bind
	(stop-sec stop-usec)
	(if timeout
	    (multiple-value-bind (okay sec usec)
				 (mach:unix-gettimeofday)
	      (declare (ignore okay))
	      (values (the (unsigned-byte 32) (+ sec timeout))
		      usec))
	    (values 0 0))
      (declare (type (unsigned-byte 32) stop-sec stop-usec))
      (with-fd-handler (fd direction #'(lambda (fd)
					 (declare (ignore fd))
					 (setf usable t)))
	(loop
	  (serve-event timeout)
	  
	  (when usable
	    (return t))
	  
	  (when timeout
	    (multiple-value-bind (okay sec usec)
				 (mach:unix-gettimeofday)
	      (declare (ignore okay))
	      (when (or (> sec stop-sec)
			(and (= sec stop-sec) (>= usec stop-usec)))
		(return nil))
	      (setq timeout (- stop-sec sec)))))))))


;;; HANDLER-DESCRIPTORS-ERROR -- Internal.
;;;
;;; First, get a list and mark bad file descriptors.  Then signal an error
;;; offering a few restarts.
;;;
(defun handler-descriptors-error ()
  (let ((bogus-handlers nil))
    (dolist (handler *descriptor-handlers*)
      (unless (or (handler-bogus handler)
		  (mach:unix-fstat (handler-descriptor handler)))
	(setf (handler-bogus handler) t)
	(push handler bogus-handlers)))
    (restart-case (error "~S ~[have~;has a~:;have~] bad file descriptor~:P."
			 bogus-handlers (length bogus-handlers))
      (remove-them () :report "Remove bogus handlers."
       (setf *descriptor-handlers*
	     (delete-if #'handler-bogus *descriptor-handlers*)))
      (retry-them () :report "Retry bogus handlers."
       (dolist (handler bogus-handlers)
	 (setf (handler-bogus handler) nil)))
      (continue () :report "Go on, leaving handlers marked as bogus."))))



;;;; Serve-all-events, serve-event, and friends.

(declaim (start-block serve-event serve-all-events))

(defvar *display-event-handlers* nil
  "This is an alist mapping displays to user functions to be called when
   SYSTEM:SERVE-EVENT notices input on a display connection.  Do not modify
   this directly; use EXT:ENABLE-CLX-EVENT-HANDLING.  A given display
   should be represented here only once.")

;;; SERVE-ALL-EVENTS -- public
;;;
;;;   Wait for up to timeout seconds for an event to happen. Make sure all
;;; pending events are processed before returning.
;;;
(defun serve-all-events (&optional timeout)
  "SERVE-ALL-EVENTS calls SERVE-EVENT with the specified timeout.  If
  SERVE-EVENT does something (returns T) it loops over SERVE-EVENT with timeout
  0 until all events have been served.  SERVE-ALL-EVENTS returns T if
  SERVE-EVENT did something and NIL if not."
  (do ((res nil)
       (sval (serve-event timeout) (serve-event 0)))
      ((null sval) res)
    (setq res t)))


;;; SERVE-EVENT -- public
;;;
;;;   Serve a single event.
;;;
(defun serve-event (&optional timeout)
  "Receive on all ports and Xevents and dispatch to the appropriate handler
  function.  If timeout is specified, server will wait the specified time (in
  seconds) and then return, otherwise it will wait until something happens.
  Server returns T if something happened and NIL otherwise."
  ;; First, check any X displays for any pending events.
  #+clx
  (dolist (d/h *display-event-handlers*)
    (let* ((d (car d/h))
	   (disp-fd (fd-stream-fd (xlib::display-input-stream d))))
      (declare (inline member))
      ;;
      ;; If in the *descriptor-handlers*, then we are already waiting for input
      ;; on that display, and we don't want to do it recursively.
      (when (and (dolist (hand *descriptor-handlers* t)
		   (when (and (eql (handler-descriptor hand) disp-fd)
			      (not (eq (handler-function hand)
				       #'ext::call-display-event-handler)))
		     (return nil)))
		 (xlib::event-listen d))
	(handler-bind ((error #'(lambda (condx)
				  (declare (ignore condx))
				  (flush-display-events d))))
	  (funcall (cdr d/h) d))
	(return-from serve-event t))))
  ;; Next, wait for something to happen.
  (multiple-value-bind
      (value readable writeable)
      (wait-for-event timeout)
    (declare (type (unsigned-byte 32) readable writeable))
    ;; Now see what it was (if anything)
    (cond ((fixnump value)
	   (unless (zerop value)
	     ;; Check the descriptors.
	     (let ((result nil))
	       (dolist (handler *descriptor-handlers*)
		 (when (logbitp (handler-descriptor handler)
				(ecase (handler-direction handler)
				  (:input readable)
				  (:output writeable)))
		   (unwind-protect
		       (progn
			 ;; Doesn't work -- ACK
			 ;(setf (handler-active handler) t)
			 (funcall (handler-function handler)
				  (handler-descriptor handler)))
		     (setf (handler-active handler) nil))
		   (macrolet ((frob (var)
				`(setf ,var
				       (logand (32bit-logical-not
						(ash 1
						     (handler-descriptor
						      handler)))
					       ,var))))
		     (ecase (handler-direction handler)
		       (:input (frob readable))
		       (:output (frob writeable))))
		   (setf result t)))
	       result)))
	  ((eql readable mach:eintr)
	   ;; We did an interrupt.
	   t)
	  (t
	   ;; One of the file descriptors is bad.
	   (handler-descriptors-error)
	   nil))))


;;; CALC-MASKS -- Internal.
;;;
;;; Return the correct masks to use for UNIX-SELECT.  The four return values
;;; are: fd count, read mask, write mask, and exception mask.  The exception
;;; mask is currently unused.
;;;
(defun calc-masks ()
  (let ((count 0)
	(read-mask 0)
	(write-mask 0)
	(except-mask 0))
    (declare (type index count)
	     (type (unsigned-byte 32) read-mask write-mask except-mask))
    (dolist (handler *descriptor-handlers*)
      (unless (or (handler-active handler)
		  (handler-bogus handler))
	(let ((fd (handler-descriptor handler)))
	  (ecase (handler-direction handler)
	    (:input
	     (setf read-mask
		   (logior read-mask
			   (the (unsigned-byte 32) (ash 1 fd)))))
	    (:output
	     (setf write-mask
		   (logior write-mask
			   (the (unsigned-byte 32) (ash 1 fd))))))
	  (when (> fd count)
	    (setf count fd)))))
    (values (1+ count)
	    read-mask
	    write-mask
	    except-mask)))

;;; WAIT-FOR-EVENT -- internal
;;;
;;;   Wait for something to happen. 
;;;
(defun wait-for-event (&optional timeout)
  "Wait for an something to show up on one of the file descriptors or a message
  interupt to fire. Timeout is in seconds."
  (multiple-value-bind
      (timeout-sec timeout-usec)
      (typecase timeout
	(integer (values timeout 0))
	(null (values nil 0))
	(t
	 (multiple-value-bind (q r)
			      (truncate (coerce timeout 'single-float))
	   (declare (type index q) (single-float r))
	   (values q (truncate (* r 1f6))))))
    (declare (type index timeout-usec)
	     (type (or index null) timeout-sec))
    (multiple-value-bind (count read-mask write-mask except-mask)
			 (calc-masks)
      ;; Do the select.
      (mach:unix-select count read-mask write-mask except-mask
			timeout-sec timeout-usec))))
