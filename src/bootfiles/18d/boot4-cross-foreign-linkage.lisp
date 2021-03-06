;;; This script builds a cross compiler that can then build a new
;;; system with the linkage table changes.  It works well with Pierre
;;; Mai's build scripts.

(in-package :cl-user)

;;; Rename the X86 package and backend so that new-backend does the
;;; right thing.
(rename-package "X86" "OLD-X86")
(setf (c:backend-name c:*native-backend*) "OLD-X86")

(c::new-backend "X86"
   ;; Features to add here
   '(:x86 :i486
     :mp :gencgc
     :conservative-float-type
     :hash-new :random-mt19937
     :cmu :cmu18 :cmu18d
;;     :freebsd :freebsd4 :elf
     :linkage-table
     :relative-package-names
     )
   ;; Features to remove from current *features* here
   '(:x86-bootstrap :alpha :osf1 :mips
     :propagate-fun-type :propagate-float-type :constrain-float-type
     :openbsd :pentium ;;  :glibc2 :linux :freebsd
     :long-float :new-random :small))

;;; So compilation of make-fixup will work.
(setf (get 'lisp::fop-foreign-data-fixup 'lisp::fop-code) 150)

;;; Compile the new backend.
(pushnew :bootstrap *features*)
(pushnew :building-cross-compiler *features*)

(load "target:tools/comcom")
(comf "target:code/foreign-linkage")


;;; Load the new backend.
(setf (search-list "c:")
      '("target:compiler/"))
(setf (search-list "vm:")
      '("c:x86/" "c:generic/"))
(setf (search-list "assem:")
      '("target:assembly/" "target:assembly/x86/"))

;; Load the backend of the compiler.

(in-package "C")

(load "vm:vm-macs")
(load "vm:parms")
(load "vm:objdef")
(load "vm:interr")
(load "assem:support")

(load "target:compiler/srctran")
(load "vm:vm-typetran")
(load "target:compiler/float-tran")
(load "target:compiler/saptran")

(load "vm:macros")
(load "vm:utils")

(load "vm:vm")
(load "vm:insts")
(load "vm:primtype")
(load "vm:move")
(load "vm:sap")
(load "vm:system")
(load "vm:char")
(load "vm:float")

(load "vm:memory")
(load "vm:static-fn")
(load "vm:arith")
(load "vm:cell")
(load "vm:subprim")
(load "vm:debug")
(load "vm:c-call")
(load "vm:print")
(load "vm:alloc")
(load "vm:call")
(load "vm:nlx")
(load "vm:values")
(load "vm:array")
(load "vm:pred")
(load "vm:type-vops")

(load "assem:assem-rtns")

(load "assem:array")
(load "assem:arith")
(load "assem:alloc")

(load "c:pseudo-vops")

(check-move-function-consistency)

(load "target:code/foreign-linkage")
(load "target:compiler/dump")
(load "vm:new-genesis")

;;; OK, the cross compiler backend is loaded.

(setf *features* (remove :building-cross-compiler *features*))

;;; Info environment hacks.
(macrolet ((frob (&rest syms)
	     `(progn ,@(mapcar #'(lambda (sym)
				   `(defconstant ,sym
				      (symbol-value
				       (find-symbol ,(symbol-name sym)
						    :vm))))
			       syms))))
  (frob OLD-X86:BYTE-BITS OLD-X86:WORD-BITS
	#+long-float OLD-X86:SIMPLE-ARRAY-LONG-FLOAT-TYPE 
	OLD-X86:SIMPLE-ARRAY-DOUBLE-FLOAT-TYPE 
	OLD-X86:SIMPLE-ARRAY-SINGLE-FLOAT-TYPE
	#+long-float OLD-X86:SIMPLE-ARRAY-COMPLEX-LONG-FLOAT-TYPE 
	OLD-X86:SIMPLE-ARRAY-COMPLEX-DOUBLE-FLOAT-TYPE 
	OLD-X86:SIMPLE-ARRAY-COMPLEX-SINGLE-FLOAT-TYPE
	OLD-X86:SIMPLE-ARRAY-UNSIGNED-BYTE-2-TYPE 
	OLD-X86:SIMPLE-ARRAY-UNSIGNED-BYTE-4-TYPE
	OLD-X86:SIMPLE-ARRAY-UNSIGNED-BYTE-8-TYPE 
	OLD-X86:SIMPLE-ARRAY-UNSIGNED-BYTE-16-TYPE 
	OLD-X86:SIMPLE-ARRAY-UNSIGNED-BYTE-32-TYPE 
	OLD-X86:SIMPLE-ARRAY-SIGNED-BYTE-8-TYPE 
	OLD-X86:SIMPLE-ARRAY-SIGNED-BYTE-16-TYPE
	OLD-X86:SIMPLE-ARRAY-SIGNED-BYTE-30-TYPE 
	OLD-X86:SIMPLE-ARRAY-SIGNED-BYTE-32-TYPE
	OLD-X86:SIMPLE-BIT-VECTOR-TYPE
	OLD-X86:SIMPLE-STRING-TYPE OLD-X86:SIMPLE-VECTOR-TYPE 
	OLD-X86:SIMPLE-ARRAY-TYPE OLD-X86:VECTOR-DATA-OFFSET
	))

(let ((function (symbol-function 'kernel:error-number-or-lose)))
  (let ((*info-environment* (c:backend-info-environment c:*target-backend*)))
    (setf (symbol-function 'kernel:error-number-or-lose) function)
    (setf (info function kind 'kernel:error-number-or-lose) :function)
    (setf (info function where-from 'kernel:error-number-or-lose) :defined)))

(defun fix-class (name)
  (let* ((new-value (find-class name))
	 (new-layout (kernel::class-layout new-value))
	 (new-cell (kernel::find-class-cell name))
	 (*info-environment* (c:backend-info-environment c:*target-backend*)))
    (remhash name kernel::*forward-referenced-layouts*)
    (kernel::%note-type-defined name)
    (setf (info type kind name) :instance)
    (setf (info type class name) new-cell)
    (setf (info type compiler-layout name) new-layout)
    new-value))
(fix-class 'c::vop-parse)
(fix-class 'c::operand-parse)

#+random-mt19937
(declaim (notinline kernel:random-chunk))

(setf c:*backend* c:*target-backend*)

;;; Extern-alien-name for the new backend.
(in-package :vm)
(defun extern-alien-name (name)
  (declare (type simple-string name))
  #+(and bsd (not elf))
  (concatenate 'string "_" name)
  #-(and bsd (not elf))
  name)
(export 'extern-alien-name)
(export 'fixup-code-object)
(export 'sanctify-for-execution)

(in-package :cl-user)

;;; Don't load compiler parts from the target compilation

(defparameter *load-stuff* nil)

;; hack, hack, hack: Make old-x86::any-reg the same as
;; x86::any-reg as an SC.  Do this by adding old-x86::any-reg
;; to the hash table with the same value as x86::any-reg.
(let ((ht (c::backend-sc-names c::*target-backend*)))
  (setf (gethash 'old-x86::any-reg ht)
	(gethash 'x86::any-reg ht)))

(in-package "ALIEN")

(defun %def-alien-variable (lisp-name alien-name type)
  (setf (info variable kind lisp-name) :alien)
  (setf (info variable where-from lisp-name) :defined)
  (clear-info variable constant-value lisp-name)
  (setf (info variable alien-info lisp-name)
	(make-heap-alien-info :type type
			      :sap-form `(foreign-symbol-address
					  ',alien-name :flavor :data))))
(defmacro extern-alien (name type)
  "Access the alien variable named NAME, assuming it is of type TYPE.  This
   is setfable."
  (let* ((alien-name (etypecase name
		       (symbol (guess-alien-name-from-lisp-name name))
		       (string name)))
	 (alien-type (parse-alien-type type))
	 (flavor (if (alien-function-type-p alien-type)
		     :code
		     :data)))
    `(%heap-alien ',(make-heap-alien-info
		     :type alien-type
		     :sap-form `(foreign-symbol-address ',alien-name
				 :flavor ',flavor)))))

(defmacro with-alien (bindings &body body)
  "Establish some local alien variables.  Each BINDING is of the form:
     VAR TYPE [ ALLOCATION ] [ INITIAL-VALUE | EXTERNAL-NAME ]
   ALLOCATION should be one of:
     :LOCAL (the default)
       The alien is allocated on the stack, and has dynamic extent.
     :STATIC
       The alien is allocated on the heap, and has infinate extent.  The alien
       is allocated at load time, so the same piece of memory is used each time
       this form executes.
     :EXTERN
       No alien is allocated, but VAR is established as a local name for
       the external alien given by EXTERNAL-NAME."
  (with-auxiliary-alien-types
    (dolist (binding (reverse bindings))
      (destructuring-bind
	  (symbol type &optional (opt1 nil opt1p) (opt2 nil opt2p))
	  binding
	(let* ((alien-type (parse-alien-type type))
	       (flavor (if (alien-function-type-p alien-type)
			   :code
			   :data)))
	  (multiple-value-bind
	      (allocation initial-value)
	      (if opt2p
		  (values opt1 opt2)
		  (case opt1
		    (:extern
		     (values opt1 (guess-alien-name-from-lisp-name symbol)))
		    (:static
		     (values opt1 nil))
		    (t
		     (values :local opt1))))
	    (setf body
		  (ecase allocation
		    #+nil
		    (:static
		     (let ((sap
			    (make-symbol (concatenate 'string "SAP-FOR-"
						      (symbol-name symbol)))))
		       `((let ((,sap (load-time-value (%make-alien ...))))
			   (declare (type system-area-pointer ,sap))
			   (symbol-macrolet
			    ((,symbol (sap-alien ,sap ,type)))
			    ,@(when initial-value
				`((setq ,symbol ,initial-value)))
			    ,@body)))))
		    (:extern
		     (let ((info (make-heap-alien-info
				  :type alien-type
				  :sap-form `(foreign-symbol-address
					      ',initial-value
					      :flavor ',flavor))))
		       `((symbol-macrolet
			  ((,symbol (%heap-alien ',info)))
			  ,@body))))
		    (:local
		     (let ((var (gensym))
			   (initval (if initial-value (gensym)))
			   (info (make-local-alien-info
				  :type alien-type)))
		       `((let ((,var (make-local-alien ',info))
			       ,@(when initial-value
				   `((,initval ,initial-value))))
			   (note-local-alien-type ',info ,var)
			   (multiple-value-prog1
			       (symbol-macrolet
				((,symbol (local-alien ',info ,var)))
				,@(when initial-value
				    `((setq ,symbol ,initval)))
				,@body)
			       (dispose-local-alien ',info ,var)
			       )))))))))))
    (verify-local-auxiliaries-okay)
    `(compiler-let ((*auxiliary-type-definitions*
		     ',(append *new-auxiliary-types*
			       *auxiliary-type-definitions*)))
       ,@body)))

