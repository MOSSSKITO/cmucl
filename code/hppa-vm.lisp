;;; -*- Package: HPPA -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
(ext:file-comment
  "$Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/code/hppa-vm.lisp,v 1.2 1992/06/13 08:39:52 wlott Exp $")
;;;
;;; **********************************************************************
;;;
;;; This file contains the HPPA specific runtime stuff.
;;;
(in-package "HPPA")
(use-package "SYSTEM")
(use-package "ALIEN")
(use-package "C-CALL")
(use-package "UNIX")

(export '(fixup-code-object internal-error-arguments
	  sigcontext-register sigcontext-float-register
	  sigcontext-floating-point-modes extern-alien-name))


;;;; The sigcontext structure.

(def-alien-type save-state
  (struct nil
    (regs (array unsigned-long 32))
    (filler (array unsigned-long 32))
    (fpregs (array unsigned-long 32))))

(def-alien-type sigcontext
  (struct nil
    (sc-onstack unsigned-long)
    (sc-mask unsigned-long)
    (sc-sp system-area-pointer)
    (sc-fp system-area-pointer)
    (sc-ap (* save-state))
    (sc-pcsqh unsigned-long)
    (sc-pc system-area-pointer) ; HP calls it the sc-pcoqh.
    (sc-pcsqt unsigned-long)
    (sc-pcoqt system-area-pointer)
    (sc-ps unsigned-long)))


;;;; Add machine specific features to *features*

(pushnew :hppa *features*)



;;;; MACHINE-TYPE and MACHINE-VERSION

(defun machine-type ()
  "Returns a string describing the type of the local machine."
  "HPPA")

(defun machine-version ()
  "Returns a string describing the version of the local machine."
  "HPPA")



;;; FIXUP-CODE-OBJECT -- Interface
;;;
(defun fixup-code-object (code offset value kind)
  (unless (zerop (rem offset word-bytes))
    (error "Unaligned instruction?  offset=#x~X." offset))
  (system:without-gcing
   (let* ((sap (truly-the system-area-pointer
			  (%primitive c::code-instructions code)))
	  (inst (sap-ref-32 sap offset)))
     (setf (sap-ref-32 sap offset)
	   (ecase kind
	     (:load
	      (logior (ash (ldb (byte 11 0) value) 1)
		      (logand inst #xffffc000)))
	     (:load-short
	      (let ((low-bits (ldb (byte 11 0) value)))
		(assert (<= 0 low-bits (1- (ash 1 4))))
		(logior (ash low-bits 17)
			(logand inst #xffe0ffff))))
	     (:hi
	      (logior (ash (ldb (byte 5 13) value) 16)
		      (ash (ldb (byte 2 18) value) 14)
		      (ash (ldb (byte 2 11) value) 12)
		      (ash (ldb (byte 11 20) value) 1)
		      (ldb (byte 1 31) value)
		      (logand inst #xffe00000)))
	     (:branch
	      (let ((bits (ldb (byte 9 2) value)))
		(assert (zerop (ldb (byte 2 0) value)))
		(dpb (ash bits 1)
		     (byte 11 2)
		     (logand inst #xffe0e0002)))))))))



;;;; Internal-error-arguments.

;;; INTERNAL-ERROR-ARGUMENTS -- interface.
;;;
;;; Given the sigcontext, extract the internal error arguments from the
;;; instruction stream.
;;; 
(defun internal-error-arguments (scp)
  (declare (type (alien (* sigcontext)) scp))
  (with-alien ((scp (* sigcontext) scp))
    (let ((pc (slot scp 'sc-pc)))
      (declare (type system-area-pointer pc))
      (let* ((length (sap-ref-8 pc 4))
	     (vector (make-array length :element-type '(unsigned-byte 8))))
	(declare (type (unsigned-byte 8) length)
		 (type (simple-array (unsigned-byte 8) (*)) vector))
	(copy-from-system-area pc (* byte-bits 5)
			       vector (* word-bits
					 vector-data-offset)
			       (* length byte-bits))
	(let* ((index 0)
	       (error-number (c::read-var-integer vector index)))
	  (collect ((sc-offsets))
	    (loop
	      (when (>= index length)
		(return))
	      (sc-offsets (c::read-var-integer vector index)))
	    (values error-number (sc-offsets))))))))


;;;; Sigcontext access functions.

;;; SIGCONTEXT-REGISTER -- Internal.
;;;
;;; An escape register saves the value of a register for a frame that someone
;;; interrupts.  
;;;
(defun sigcontext-register (scp index)
  (declare (type (alien (* sigcontext)) scp))
  (with-alien ((scp (* sigcontext) scp))
    (deref (slot (slot scp 'sc-ap) 'regs) index)))

(defun %set-sigcontext-register (scp index new)
  (declare (type (alien (* sigcontext)) scp))
  (with-alien ((scp (* sigcontext) scp))
    (setf (deref (slot (slot scp 'sc-ap) 'regs) index) new)
    new))

(defsetf sigcontext-register %set-sigcontext-register)


;;; SIGCONTEXT-FLOAT-REGISTER  --  Internal
;;;
;;; Like SIGCONTEXT-REGISTER, but returns the value of a float register.
;;; Format is the type of float to return.
;;;
(defun sigcontext-float-register (scp index format)
  (declare (type (alien (* sigcontext)) scp))
  (error "sigcontext-float-register not implimented." scp index format)
  #+nil
  (with-alien ((scp (* sigcontext) scp))
    (let ((sap (alien-sap (slot scp 'sc-fpregs))))
      (ecase format
	(single-float (system:sap-ref-single sap (* index vm:word-bytes)))
	(double-float (system:sap-ref-double sap (* index vm:word-bytes)))))))
;;;
(defun %set-sigcontext-float-register (scp index format new-value)
  (declare (type (alien (* sigcontext)) scp))
  (error "%set-sigcontext-float-register not implimented."
	 scp index format new-value)
  #+nil
  (with-alien ((scp (* sigcontext) scp))
    (let ((sap (alien-sap (slot scp 'sc-fpregs))))
      (ecase format
	(single-float
	 (setf (sap-ref-single sap (* index vm:word-bytes)) new-value))
	(double-float
	 (setf (sap-ref-double sap (* index vm:word-bytes)) new-value))))))
;;;
(defsetf sigcontext-float-register %set-sigcontext-float-register)


;;; SIGCONTEXT-FLOATING-POINT-MODES  --  Interface
;;;
;;;    Given a sigcontext pointer, return the floating point modes word in the
;;; same format as returned by FLOATING-POINT-MODES.
;;;
(defun sigcontext-floating-point-modes (scp)
  (declare (type (alien (* sigcontext)) scp))
  (error "sigcontext-floating-point-modes not implimented." scp)
  #+nil
  (with-alien ((scp (* sigcontext) scp))
    (slot scp 'sc-fpc-csr)))



;;; EXTERN-ALIEN-NAME -- interface.
;;;
;;; The loader uses this to convert alien names to the form they occure in
;;; the symbol table (for example, prepending an underscore).  On the HPPA
;;; we just leave it alone.
;;; 
(defun extern-alien-name (name)
  (declare (type simple-base-string name))
  name)


