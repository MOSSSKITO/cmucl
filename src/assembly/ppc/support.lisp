;;; -*- Package: PPC -*-
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
(ext:file-comment
  "$Header: src/assembly/ppc/support.lisp $")
;;;
;;; **********************************************************************
;;;
(in-package "PPC")

(def-vm-support-routine generate-call-sequence (name style vop)
  (ecase style
    (:raw
     (let ((temp (make-symbol "TEMP")))
       (values 
	`((inst lr ,temp (make-fixup ',name :assembly-routine))
	  (inst mtctr ,temp)
	  (inst bctrl))
	`((:temporary (:scs (non-descriptor-reg) :from (:eval 0) :to (:eval 1))
	              ,temp)))))
    (:full-call
     (let ((temp (make-symbol "TEMP"))
	   (nfp-save (make-symbol "NFP-SAVE"))
	   (lra (make-symbol "LRA")))
       (values
	`((let ((lra-label (gen-label))
		(cur-nfp (current-nfp-tn ,vop)))
	    (when cur-nfp
	      (store-stack-tn ,nfp-save cur-nfp))
	    (inst compute-lra-from-code ,lra code-tn lra-label ,temp)
	    (note-next-instruction ,vop :call-site)
	    (inst lr ,temp (make-fixup ',name :assembly-routine))
	    (inst mtctr ,temp)
	    (inst bctr)
	    (emit-return-pc lra-label)
	    (note-this-location ,vop :single-value-return)
	    (without-scheduling ()
				(move csp-tn ocfp-tn)
				(inst nop))
	    (inst compute-code-from-lra code-tn code-tn
		  lra-label ,temp)
	    (when cur-nfp
	      (load-stack-tn cur-nfp ,nfp-save))))
	`((:temporary (:scs (non-descriptor-reg) :from (:eval 0) :to (:eval 1))
	   ,temp)
	  (:temporary (:sc descriptor-reg :offset lra-offset
		       :from (:eval 0) :to (:eval 1))
	   ,lra)
	  (:temporary (:scs (control-stack) :offset nfp-save-offset)
	   ,nfp-save)
	  (:save-p :compute-only)))))
    (:none
     (let ((temp (make-symbol "TEMP")))
       (values
	`((inst lr ,temp (make-fixup ',name :assembly-routine))
	  (inst mtctr ,temp)
	  (inst bctr))
	`((:temporary (:scs (non-descriptor-reg) :from (:eval 0) :to (:eval 1))
		      ,temp)))))))

(def-vm-support-routine generate-return-sequence (style)
  (ecase style
    (:raw
     `((inst blr)))
    (:full-call
     `((lisp-return (make-random-tn :kind :normal
				    :sc (sc-or-lose 'descriptor-reg *backend*)
				    :offset lra-offset)
		    (make-random-tn :kind :normal
		                    :sc (sc-or-lose 'interior-reg *backend*)
				    :offset lip-offset)
		    :offset 2)))
    (:none)))
