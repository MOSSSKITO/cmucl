;;; -*- Mode: LISP; Syntax: Common-Lisp; Base: 10; Package: x86 -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
(ext:file-comment
 "$Header: src/compiler/amd64/values.lisp $")
;;;
;;; **********************************************************************
;;;
;;; This file contains the implementation of unknown-values VOPs.
;;;
;;; Written by William Lott.
;;;
;;; Debugged by Paul F. Werkowski Spring/Summer 1995.
;;; %more-arg-values by Douglas Thomas Crosher, March 1996.
;;; Enhancements/debugging by Douglas T. Crosher 1996.

(in-package :amd64)

(define-vop (reset-stack-pointer)
  (:args (ptr :scs (any-reg)))
  (:generator 1
    (move rsp-tn ptr)))

;;; Push some values onto the stack, returning the start and number of values
;;; pushed as results.  It is assumed that the Vals are wired to the standard
;;; argument locations.  Nvals is the number of values to push.
;;;
;;; The generator cost is pseudo-random.  We could get it right by defining a
;;; bogus SC that reflects the costs of the memory-to-memory moves for each
;;; operand, but this seems unworthwhile.
;;;
(define-vop (push-values)
  (:args (vals :more t))
  (:temporary (:sc unsigned-reg :to (:result 0) :target start) temp)
  (:results (start) (count))
  (:info nvals)
  (:generator 20
    (move temp rsp-tn)			; WARN pointing 1 below
    (do ((val vals (tn-ref-across val)))
	((null val))
      (inst push (tn-ref-tn val)))
    (move start temp)
    (inst mov count (fixnumize nvals))))

;;; Push a list of values on the stack, returning Start and Count as used in
;;; unknown values continuations.
;;;
(define-vop (values-list)
  (:args (arg :scs (descriptor-reg) :target list))
  (:arg-types list)
  (:policy :fast-safe)
  (:results (start :scs (any-reg))
	    (count :scs (any-reg)))
  (:temporary (:sc descriptor-reg :from (:argument 0) :to (:result 1)) list)
  (:temporary (:sc descriptor-reg :to (:result 1)) nil-temp)
  (:temporary (:sc unsigned-reg :offset rax-offset :to (:result 1)) rax)
  (:vop-var vop)
  (:save-p :compute-only)
  (:generator 0
    (move list arg)
    (move start rsp-tn)			; WARN pointing 1 below
    (inst mov nil-temp nil-value)

    LOOP
    (inst cmp list nil-temp)
    (inst jmp :e done)
    (pushw list cons-car-slot list-pointer-type)
    (loadw list list cons-cdr-slot list-pointer-type)
    (inst mov rax list)
    (inst and al-tn lowtag-mask)
    (inst cmp al-tn list-pointer-type)
    (inst jmp :e loop)
    (error-call vop bogus-argument-to-values-list-error list)

    DONE
    (inst mov count start)		; start is high address
    (inst sub count rsp-tn)		; stackp is low address
    (inst shr count 1))) ; this is unnecessary if we use 4-bit low-tag

;;; Copy the more arg block to the top of the stack so we can use them
;;; as function arguments.
;;;
;;; Accepts a context as produced by more-arg-context; points to the first
;;; value on the stack, not 4 bytes above as in other contexts.
;;;
;;; Return a context that is 4 bytes above the first value, suitable for
;;; defining a new stack frame.
;;;
;;;
(define-vop (%more-arg-values)
  (:args (context :scs (descriptor-reg any-reg) :target src)
         (skip :scs (any-reg immediate))
         (num :scs (any-reg) :target count))
  (:arg-types * positive-fixnum positive-fixnum)
  (:temporary (:sc any-reg :offset rsi-offset :from (:argument 0)) src)
  (:temporary (:sc descriptor-reg :offset rax-offset) temp)
  (:temporary (:sc unsigned-reg :offset rcx-offset) temp1)
  (:results (start :scs (any-reg))
            (count :scs (any-reg)))
  (:generator 20
    (sc-case skip
      (immediate
       (cond ((zerop (tn-value skip))
	      (move src context)
	      (move count num))
	     (t
	      (inst lea src (make-ea :qword :base context
				     :disp (- (* (tn-value skip) word-bytes))))
	      (move count num)
	      (inst sub count (* (tn-value skip) word-bytes)))))
      
      (any-reg
       (move src context)
       (inst sub src skip)
       (move count num)
       (inst sub count skip)))
    
    (move temp1 count)
    (inst mov start rsp-tn)
    (inst jrcxz done)  ; check for 0 count?
    
    (inst shr temp1 word-shift) ; convert the fixnum to a count.
    
    (inst std) ; move down the stack as more value are copied to the bottom.
    LOOP
    (inst lods temp)
    (inst push temp)
    (inst loop loop)
    
    DONE))
 
