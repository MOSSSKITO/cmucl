;;; -*- Package: C; Log: C.Log -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public
;;; domain.  If you want to use this code or any part of CMU Common
;;; Lisp, please contact Scott Fahlman (Scott.Fahlman@CS.CMU.EDU)
;;; **********************************************************************
;;;
;;; $Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/compiler/mips/static-fn.lisp,v 1.13 1990/11/03 03:25:52 wlott Exp $
;;;
;;; This file contains the VOPs and macro magic necessary to call static
;;; functions.
;;;
;;; Written by William Lott.
;;;
(in-package "MIPS")



(define-vop (static-function-template)
  (:save-p t)
  (:policy :safe)
  (:variant-vars symbol)
  (:vop-var vop)
  (:temporary (:scs (non-descriptor-reg)) temp)
  (:temporary (:scs (descriptor-reg)) move-temp)
  (:temporary (:sc descriptor-reg :offset lra-offset) lra)
  (:temporary (:sc descriptor-reg :offset cname-offset) cname)
  (:temporary (:scs (interior-reg) :type interior) lip)
  (:temporary (:sc any-reg :offset nargs-offset) nargs)
  (:temporary (:sc any-reg :offset old-fp-offset) old-fp)
  (:temporary (:sc control-stack :offset nfp-save-offset) nfp-save))


(eval-when (compile load eval)


(defun static-function-template-name (num-args num-results)
  (intern (format nil "~:@(~R-arg-~R-result-static-function~)"
		  num-args num-results)))


(defun moves (dst src)
  (collect ((moves))
    (do ((dst dst (cdr dst))
	 (src src (cdr src)))
	((or (null dst) (null src)))
      (moves `(move ,(car dst) ,(car src))))
    (moves)))

(defun static-function-template-vop (num-args num-results)
  (assert (and (<= num-args register-arg-count)
	       (<= num-results register-arg-count))
	  (num-args num-results)
	  "Either too many args (~D) or too many results (~D).  Max = ~D"
	  num-args num-results register-arg-count)
  (let ((num-temps (max num-args num-results)))
    (collect ((temp-names) (temps) (arg-names) (args) (result-names) (results))
      (dotimes (i num-results)
	(let ((result-name (intern (format nil "RESULT-~D" i))))
	  (result-names result-name)
	  (results `(,result-name :scs (any-reg descriptor-reg)))))
      (dotimes (i num-temps)
	(let ((temp-name (intern (format nil "TEMP-~D" i))))
	  (temp-names temp-name)
	  (temps `(:temporary (:sc descriptor-reg
			       :offset ,(nth i register-arg-offsets)
			       ,@(when (< i num-args)
				   `(:from (:argument ,i)))
			       ,@(when (< i num-results)
				   `(:to (:result ,i)
				     :target ,(nth i (result-names)))))
			      ,temp-name))))
      (dotimes (i num-args)
	(let ((arg-name (intern (format nil "ARG-~D" i))))
	  (arg-names arg-name)
	  (args `(,arg-name
		  :scs (any-reg descriptor-reg)
		  :target ,(nth i (temp-names))))))
      `(define-vop (,(static-function-template-name num-args num-results)
		    static-function-template)
	 (:args ,@(args))
	 ,@(temps)
	 (:results ,@(results))
	 (:generator ,(+ 50 num-args num-results)
	   (let ((lra-label (gen-label))
		 (cur-nfp (current-nfp-tn vop)))
	     ,@(moves (temp-names) (arg-names))
	     (inst li nargs (fixnum ,num-args))
	     (load-symbol cname symbol)
	     (inst lw lip cname
		   (- (ash vm:symbol-raw-function-addr-slot vm:word-shift)
		      vm:other-pointer-type))
	     (when cur-nfp
	       (store-stack-tn nfp-save cur-nfp))
	     (inst move old-fp fp-tn)
	     (inst compute-lra-from-code lra code-tn lra-label temp)
	     (inst j lip)
	     (inst move fp-tn csp-tn)
	     (emit-return-pc lra-label)
	     (note-this-location vop :unknown-return)
	     ,(collect ((bindings) (links))
		(do ((temp (temp-names) (cdr temp))
		     (name 'values (gensym))
		     (prev nil name)
		     (i 0 (1+ i)))
		    ((= i num-results))
		  (bindings `(,name
			      (make-tn-ref ,(car temp) nil)))
		  (when prev
		    (links `(setf (tn-ref-across ,prev) ,name))))
		`(let ,(bindings)
		   ,@(links)
		   (default-unknown-values
		       ,(if (zerop num-results) nil 'values)
		       ,num-results move-temp temp lra-label)))
	     (when cur-nfp
	       (load-stack-tn cur-nfp nfp-save))
	     ,@(moves (result-names) (temp-names))))))))


) ; eval-when (compile load eval)


(expand
 (collect ((templates (list 'progn)))
   (dotimes (i register-arg-count)
     (templates (static-function-template-vop i 1)))
   (templates)))


(defmacro define-static-function (name args &key (results '(x)) translate
				       policy cost arg-types result-types)
  `(define-vop (,name
		,(static-function-template-name (length args)
						(length results)))
     (:variant ',name)
     (:note ,(format nil "static-function ~@(~S~)" name))
     ,@(when translate
	 `((:translate ,translate)))
     ,@(when policy
	 `((:policy ,policy)))
     ,@(when cost
	 `((:generator-cost ,cost)))
     ,@(when arg-types
	 `((:arg-types ,@arg-types)))
     ,@(when result-types
	 `((:result-types ,@result-types)))))
