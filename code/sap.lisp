;;; -*- Package: SYSTEM -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
(ext:file-comment
  "$Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/code/sap.lisp,v 1.7 1992/02/21 22:00:07 wlott Exp $")
;;;
;;; **********************************************************************
;;;
;;; This file holds the support for System Area Pointers (saps).
;;;
(in-package "SYSTEM")

(export '(system-area-pointer sap-ref-8 sap-ref-16 sap-ref-32 sap-ref-sap
	  signed-sap-ref-8 signed-sap-ref-16 signed-sap-ref-32
	  sap+ sap- sap< sap<= sap= sap>= sap>
	  allocate-system-memory reallocate-system-memory
	  deallocate-system-memory))

(in-package "KERNEL")
(export '(%set-sap-ref-sap %set-sap-ref-single %set-sap-ref-double
	  %set-sap-ref-8 %signed-set-sap-ref-8
	  %set-sap-ref-16 %set-signed-sap-ref-16
	  %set-sap-ref-32 %set-signed-sap-ref-32))
(in-package "SYSTEM")

(use-package "KERNEL")



;;;; Primitive SAP operations.

(defun sap< (x y)
  "Return T iff the SAP X points to a smaller address then the SAP Y."
  (declare (type system-area-pointer x y))
  (sap< x y))

(defun sap<= (x y)
  "Return T iff the SAP X points to a smaller or the same address as
   the SAP Y."
  (declare (type system-area-pointer x y))
  (sap<= x y))

(defun sap= (x y)
  "Return T iff the SAP X points to the same address as the SAP Y."
  (declare (type system-area-pointer x y))
  (sap= x y))

(defun sap>= (x y)
  "Return T iff the SAP X points to a larger or the same address as
   the SAP Y."
  (declare (type system-area-pointer x y))
  (sap>= x y))

(defun sap> (x y)
  "Return T iff the SAP X points to a larger address then the SAP Y."
  (declare (type system-area-pointer x y))
  (sap> x y))

(defun sap+ (sap offset)
  "Return a new sap OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (fixnum offset))
  (sap+ sap offset))

(defun sap- (sap1 sap2)
  "Return the byte offset between SAP1 and SAP2."
  (declare (type system-area-pointer sap1 sap2))
  (sap- sap1 sap2))

(defun sap-int (sap)
  "Converts a System Area Pointer into an integer."
  (declare (type system-area-pointer sap))
  (sap-int sap))

(defun int-sap (int)
  "Converts an integer into a System Area Pointer."
  (declare (type (unsigned-byte #.vm:word-bits) int))
  (int-sap int))

(defun sap-ref-8 (sap offset)
  "Returns the 8-bit byte at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (sap-ref-8 sap offset))

(defun sap-ref-16 (sap offset)
  "Returns the 16-bit word at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (sap-ref-16 sap offset))

(defun sap-ref-32 (sap offset)
  "Returns the 32-bit dualword at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (sap-ref-32 sap offset))

(defun sap-ref-sap (sap offset)
  "Returns the 32-bit system-area-pointer at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (sap-ref-sap sap offset))

(defun sap-ref-single (sap offset)
  "Returns the 32-bit single-float at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (sap-ref-single sap offset))

(defun sap-ref-double (sap offset)
  "Returns the 64-bit double-float at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (sap-ref-double sap offset))

(defun signed-sap-ref-8 (sap offset)
  "Returns the signed 8-bit byte at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (signed-sap-ref-8 sap offset))

(defun signed-sap-ref-16 (sap offset)
  "Returns the signed 16-bit word at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (signed-sap-ref-16 sap offset))

(defun signed-sap-ref-32 (sap offset)
  "Returns the signed 32-bit dualword at OFFSET bytes from SAP."
  (declare (type system-area-pointer sap)
	   (type index offset))
  (signed-sap-ref-32 sap offset))

(defun %set-sap-ref-8 (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type (unsigned-byte 8) new-value))
  (setf (sap-ref-8 sap offset) new-value))

(defun %set-sap-ref-16 (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type (unsigned-byte 16) new-value))
  (setf (sap-ref-16 sap offset) new-value))

(defun %set-sap-ref-32 (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type (unsigned-byte 32) new-value))
  (setf (sap-ref-32 sap offset) new-value))

(defun %set-signed-sap-ref-8 (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type (signed-byte 8) new-value))
  (setf (signed-sap-ref-8 sap offset) new-value))

(defun %set-signed-sap-ref-16 (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type (signed-byte 16) new-value))
  (setf (signed-sap-ref-16 sap offset) new-value))

(defun %set-signed-sap-ref-32 (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type (signed-byte 32) new-value))
  (setf (signed-sap-ref-32 sap offset) new-value))

(defun %set-sap-ref-sap (sap offset new-value)
  (declare (type system-area-pointer sap new-value)
	   (type index offset))
  (setf (sap-ref-sap sap offset) new-value))

(defun %set-sap-ref-single (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type single-float new-value))
  (setf (sap-ref-single sap offset) new-value))

(defun %set-sap-ref-double (sap offset new-value)
  (declare (type system-area-pointer sap)
	   (type index offset)
	   (type double-float new-value))
  (setf (sap-ref-double sap offset) new-value))



;;;; System memory allocation.

(alien:def-alien-routine ("os_allocate" allocate-system-memory)
			 system-area-pointer
  (bytes c-call:unsigned-long))

(alien:def-alien-routine ("os_reallocate" reallocate-system-memory)
			 system-area-pointer
  (old system-area-pointer)
  (old-size c-call:unsigned-long)
  (new-size c-call:unsigned-long))

(alien:def-alien-routine ("os_deallocate" deallocate-system-memory)
			 c-call:void
  (addr system-area-pointer)
  (bytes c-call:unsigned-long))
