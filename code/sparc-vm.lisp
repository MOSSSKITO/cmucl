;;; -*- Package: VM -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the Spice Lisp project at
;;; Carnegie-Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of Spice Lisp, please contact
;;; Scott Fahlman (FAHLMAN@CMUC). 
;;; **********************************************************************
;;;
;;; $Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/code/sparc-vm.lisp,v 1.2 1990/11/26 15:16:18 wlott Exp $
;;;
;;; This file contains the SPARC specific runtime stuff.
;;;
(in-package "SPARC")
(use-package "SYSTEM")

(export '(fixup-code-object internal-error-arguments))


;;;; Add machine specific features to *features*

(pushnew :SPARCstation *features*)
(pushnew :sparc *features*)
(pushnew :sun4 *features*)



;;; FIXUP-CODE-OBJECT -- Interface
;;;
(defun fixup-code-object (code offset fixup kind)
  (multiple-value-bind (word-offset rem) (truncate offset word-bytes)
    (unless (zerop rem)
      (error "Unaligned instruction?  offset=#x~X." offset))
    (system:without-gcing
     (let ((sap (truly-the system-area-pointer
			   (%primitive c::code-instructions code))))
       (ecase kind
	 (:call
	  (error "Can't deal with CALL fixups, yet."))
	 (:sethi
	  (setf (ldb (byte 22 0) (sap-ref-32 sap word-offset))
		(ldb (byte 22 10) fixup)))
	 (:add
	  (setf (ldb (byte 10 0) (sap-ref-32 sap word-offset))
		(ldb (byte 10 0) fixup))))))))



;;;; Internal-error-arguments.

;;; INTERNAL-ERROR-ARGUMENTS -- interface.
;;;
;;; Given the sigcontext, extract the internal error arguments from the
;;; instruction stream.
;;; 
(defun internal-error-arguments (scp)
  (alien-bind ((sc (make-alien 'mach:sigcontext
			       #.(c-sizeof 'mach:sigcontext)
			       scp)
		   mach:sigcontext
		   t)
	       (regs (mach:sigcontext-regs (alien-value sc)) mach:int-array t))
    (let* ((pc (alien-access (mach:sigcontext-pc (alien-value sc))))
	   (length (sap-ref-8 pc 4))
	   (vector (make-array length :element-type '(unsigned-byte 8))))
      (copy-from-system-area pc (* vm:byte-bits 5)
			     vector (* vm:word-bits
				       vm:vector-data-offset)
			     (* length vm:byte-bits))
      (let* ((index 0)
	     (error-number (c::read-var-integer vector index)))
	(collect ((sc-offsets))
	  (loop
	    (when (>= index length)
	      (return))
	    (sc-offsets (c::read-var-integer vector index)))
	  (values error-number (sc-offsets)))))))



