;;; -*- Package: C; Log: C.Log -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;;
(ext:file-comment
  "$Header: src/compiler/pseudo-vops.lisp $")
;;;
;;; **********************************************************************
;;;
;;;    This file contains definitions of VOPs used as internal markers by the
;;; compiler.  Since they don't emit any code, they should be portable. 
;;;
;;; Written by Rob MacLachlan
;;;
(in-package "C")
(intl:textdomain "cmucl")

;;; Notes the place at which the environment is properly initialized, for
;;; debug-info purposes.
;;;
(define-vop (note-environment-start)
  (:info start-lab)
  (:vop-var vop)
  (:save-p :compute-only)
  (:generator 0
    (emit-label start-lab)
    (note-debug-location vop start-lab :non-local-entry)))


;;; Call a move function.  Used for register save/restore and spilling.
;;;
(define-vop (move-operand)
  (:args (x))
  (:results (y))
  (:info name)
  (:vop-var vop)
  (:generator 0
    (funcall (symbol-function name) vop x y)))

