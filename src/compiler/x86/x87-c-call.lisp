;;; -*- Mode: LISP; Syntax: Common-Lisp; Base: 10; Package: x86 -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
(ext:file-comment
 "$Header: src/compiler/x86/x87-c-call.lisp $")
;;;
;;; **********************************************************************
;;;
;;; This file contains the VOPs and other necessary machine specific support
;;; routines for call-out to C.
;;;

(in-package :x86)
(use-package :alien)
(use-package :alien-internals)
(intl:textdomain "cmucl-x87")

;; Note: other parts of the compiler depend on vops having exactly
;; these names.  Don't change them, unless you also change the other
;; parts of the compiler.

(define-vop (call-out)
  (:args (function :scs (sap-reg))
	 (args :more t))
  (:results (results :more t))
  (:temporary (:sc unsigned-reg :offset eax-offset
		   :from :eval :to :result) eax)
  (:temporary (:sc unsigned-reg :offset ecx-offset
		   :from :eval :to :result) ecx)
  (:temporary (:sc unsigned-reg :offset edx-offset
		   :from :eval :to :result) edx)
  (:node-var node)
  (:vop-var vop)
  (:save-p t)
  (:ignore args ecx edx)
  (:generator 0 
    (cond ((policy node (> space speed))
	   (move eax function)
	   (inst call (make-fixup (extern-alien-name "call_into_c") :foreign)))
	  (t
	   ;; Setup the NPX for C; all the FP registers need to be
	   ;; empty; pop them all.
	   (dotimes (i 8)
	     (fp-pop))

	   (inst call function)
	   ;; To give the debugger a clue. XX not really internal-error?
	   (note-this-location vop :internal-error)

	   ;; Restore the NPX for lisp; insure no regs are empty.
	   (dotimes (i 7)
	     (inst fldz))

	   (if (and results
		    (location= (tn-ref-tn results) fr0-tn))
	       ;; The return result is in fr0.
	       (inst fxch fr7-tn) ; move the result back to fr0
	       (inst fldz)) ; insure no regs are empty
	   ))))

(define-vop (alloc-number-stack-space)
  (:info amount)
  (:results (result :scs (sap-reg any-reg)))
  (:node-var node)
  (:generator 0
    (assert (location= result esp-tn))
    #+(or darwin linux)
    (progn
      (inst sub esp-tn 4)
      (inst fnstcw (make-ea :word :base esp-tn))
      (inst and (make-ea :word :base esp-tn) #xcff)
      (inst or (make-ea :word :base esp-tn) #x300)
      (inst fldcw (make-ea :word :base esp-tn))
      (inst add esp-tn 4))
    (unless (zerop amount)
      (let ((delta (logandc2 (+ amount 3) 3)))
	(inst sub esp-tn delta)))
    #+darwin (inst and esp-tn #xfffffff0)
    (move result esp-tn)))

(define-vop (dealloc-number-stack-space)
  (:info amount)
  (:node-var node)
  (:generator 0
    (unless (zerop amount)
      (let ((delta (logandc2 (+ amount 3) 3)))
	(inst add esp-tn delta)))
    #+(or darwin linux)
    (progn
      (inst sub esp-tn 4)
      (inst fnstcw (make-ea :word :base esp-tn))
      (inst and (make-ea :word :base esp-tn) #xcff)
      (inst or (make-ea :word :base esp-tn) #x200)
      (inst fldcw (make-ea :word :base esp-tn))
      (inst wait)
      (inst add esp-tn 4))))
