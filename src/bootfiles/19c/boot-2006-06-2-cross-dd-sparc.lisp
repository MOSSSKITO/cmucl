;;;; This is the cross-compile script for adding the (complex
;;;; double-double-float), (simple-array double-double-float (*)), and
;;;; (simple-array (complex double-double-float) (*)) types for sparc.
;;;;
;;;; Use the standard src/tools/cross-build-world.sh script with this
;;;; cross-compile script to generate a double-double-float build.
;;;; Something like
;;;;
;;;;   src/tools/cross-build-world.sh xtarget xcross <this-file> <dd-reader>
;;;;
;;;; I think this has to be built using a version that has reader
;;;; support for double-double-float.  I didn't try it any othe way.
;;;;
;;;; Once that has been done, you still need to do a full set of
;;;; builds to get these new types completely integrated in.  Don't
;;;; need any special bootstrap files for this, so
;;;;
;;;;   src/tools/build.sh -C "sun4_solaris_sunc" -o "xtarget/lisp/lisp -noinit"
;;;;

(in-package :cl-user)

;;; Rename the SPARC package and backend so that new-backend does the
;;; right thing.
(rename-package "SPARC" "OLD-SPARC")
(setf (c:backend-name c:*native-backend*) "OLD-SPARC")

(c::new-backend "SPARC"
   ;; Features to add here
   '(:sparc
     :sparc-v9				; For Ultrasparc processors
     :complex-fp-vops			; Some slightly faster FP vops on complex numbers
     :linkage-table
     :stack-checking			; Throw error if we run out of stack
     :heap-overflow-check		; Throw error if we run out of heap
     :gencgc				; Generational GC
     :relative-package-names		; Relative package names from Allegro
     :conservative-float-type
     :hash-new
     :random-mt19937			; MT-19937 generator
     :cmu				; Announce this is CMUCL
     :cmu19 :cmu19c			; Current version identifier
     :modular-arith			; Modular arithmetic
     :double-double			; Add double-double-float support.
     )
   ;; Features to remove from current *features* here
   '(:sparc-v8 :sparc-v7		; Choose only one of :sparc-v7, :sparc-v8, :sparc-v9
     ;; Other architectures we aren't using.
     :x86 :x86-bootstrap
     :alpha :osf1 :mips
     ;; Really old stuff that should have been removed long ago.
     :propagate-fun-type :propagate-float-type :constrain-float-type
     ;; Other OSes were not using
     :openbsd :freebsd :glibc2 :linux
     :pentium
     :long-float
     :new-random
     :small))

;;; May need to add some symbols to *features* and
;;; sys::*runtime-features* as well.  This might be needed even if we
;;; have those listed above, because of the code checks for things in
;;; *features* and not in the backend-features..  So do that here.


;;; Extern-alien-name for the new backend.
(in-package :vm)
(defun extern-alien-name (name)
  (declare (type simple-string name))
  #+(and bsd (not elf))
  (concatenate 'string "_" name)
  #-(and bsd (not elf))
  name)
;; When compiling the compiler, vm:fixup-code-object and
;; vm:sanctify-for-execution are undefined.  Import these to get rid
;; of that error.
(import 'old-sparc::fixup-code-object)
(import 'old-sparc::sanctify-for-execution)
(export 'extern-alien-name)
(export 'fixup-code-object)
(export 'sanctify-for-execution)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Things needed to cross-compile double-double changes.
(in-package "C")
(pushnew :double-double *features*)
(defknown simple-array-double-double-float-p (t)
  boolean
  (movable foldable flushable))

(defknown complex-double-double-float-p (t)
  boolean
  (movable foldable flushable))

(defknown simple-array-complex-double-double-float-p (t)
  boolean
  (movable foldable flushable))

(in-package "LISP")
#+double-double
(define-fop (fop-double-double-float-vector 88)
  (let* ((length (read-arg 4))
	 (result (make-array length :element-type 'double-double-float)))
    (read-n-bytes *fasl-file* result 0 (* length 4 4))
    result))

#+double-double
(define-fop (fop-complex-double-double-float 89)
  (prepare-for-fast-read-byte *fasl-file*
    (prog1
	(let* ((real-hi-lo (fast-read-u-integer 4))
	       (real-hi-hi (fast-read-s-integer 4))
	       (real-lo-lo (fast-read-u-integer 4))
	       (real-lo-hi (fast-read-s-integer 4))
	       (re (kernel::make-double-double-float
		    (make-double-float real-hi-hi real-hi-lo)
		    (make-double-float real-lo-hi real-lo-lo)))
	       (imag-hi-lo (fast-read-u-integer 4))
	       (imag-hi-hi (fast-read-s-integer 4))
	       (imag-lo-lo (fast-read-u-integer 4))
	       (imag-lo-hi (fast-read-s-integer 4))
	       (im (kernel::make-double-double-float
		    (make-double-float imag-hi-hi imag-hi-lo)
		    (make-double-float imag-lo-hi imag-lo-lo))))
	  (complex re im)) 
      (done-with-fast-read-byte))))

#+double-double
(define-fop (fop-complex-double-double-float-vector 90)
  (let* ((length (read-arg 4))
	 (result (make-array length :element-type '(complex double-double-float))))
    (read-n-bytes *fasl-file* result 0 (* length 4 8))
    result))

;; End changes for double-double
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package :cl-user)

;;; Compile the new backend.
(pushnew :bootstrap *features*)
(pushnew :building-cross-compiler *features*)
(load "target:tools/comcom")

;;; Load the new backend.
(setf (search-list "c:")
      '("target:compiler/"))
(setf (search-list "vm:")
      '("c:sparc/" "c:generic/"))
(setf (search-list "assem:")
      '("target:assembly/" "target:assembly/sparc/"))

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

(load "vm:new-genesis")

;;; OK, the cross compiler backend is loaded.

(setf *features* (remove :building-cross-compiler *features*))

;;; Info environment hacks.
(macrolet ((frob (&rest syms)
	     `(progn ,@(mapcar #'(lambda (sym)
				   `(handler-bind ((error #'(lambda (c)
							      (declare (ignore c))
							      (invoke-restart 'kernel::continue))))
				      (defconstant ,sym
					(symbol-value
					 (find-symbol ,(symbol-name sym)
						      :vm)))))
			       syms))))
  (frob OLD-SPARC:BYTE-BITS OLD-SPARC:WORD-BITS
	OLD-SPARC:LOWTAG-BITS
	#+long-float OLD-SPARC:SIMPLE-ARRAY-LONG-FLOAT-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-DOUBLE-FLOAT-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-SINGLE-FLOAT-TYPE
	#+long-float OLD-SPARC:SIMPLE-ARRAY-COMPLEX-LONG-FLOAT-TYPE
	#+double-double OLD-SPARC:SIMPLE-ARRAY-DOUBLE-DOUBLE-FLOAT-TYPE
	OLD-SPARC:SIMPLE-ARRAY-COMPLEX-DOUBLE-FLOAT-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-COMPLEX-SINGLE-FLOAT-TYPE
	OLD-SPARC:SIMPLE-ARRAY-UNSIGNED-BYTE-2-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-UNSIGNED-BYTE-4-TYPE
	OLD-SPARC:SIMPLE-ARRAY-UNSIGNED-BYTE-8-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-UNSIGNED-BYTE-16-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-UNSIGNED-BYTE-32-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-SIGNED-BYTE-8-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-SIGNED-BYTE-16-TYPE
	OLD-SPARC:SIMPLE-ARRAY-SIGNED-BYTE-30-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-SIGNED-BYTE-32-TYPE
	OLD-SPARC:SIMPLE-BIT-VECTOR-TYPE
	OLD-SPARC:SIMPLE-STRING-TYPE OLD-SPARC:SIMPLE-VECTOR-TYPE 
	OLD-SPARC:SIMPLE-ARRAY-TYPE OLD-SPARC:VECTOR-DATA-OFFSET
	OLD-SPARC:DOUBLE-FLOAT-DIGITS
	old-sparc:single-float-digits
	OLD-SPARC:DOUBLE-FLOAT-EXPONENT-BYTE
	OLD-SPARC:DOUBLE-FLOAT-NORMAL-EXPONENT-MAX
	OLD-SPARC:DOUBLE-FLOAT-SIGNIFICAND-BYTE
	OLD-SPARC:SINGLE-FLOAT-EXPONENT-BYTE
	OLD-SPARC:SINGLE-FLOAT-NORMAL-EXPONENT-MAX
	OLD-SPARC:SINGLE-FLOAT-SIGNIFICAND-BYTE
	))

;; Modular arith hacks
(setf (fdefinition 'vm::ash-left-mod32) #'old-sparc::ash-left-mod32)
(setf (fdefinition 'vm::lognot-mod32) #'old-sparc::lognot-mod32)

(let ((function (symbol-function 'kernel:error-number-or-lose)))
  (let ((*info-environment* (c:backend-info-environment c:*target-backend*)))
    (setf (symbol-function 'kernel:error-number-or-lose) function)
    (setf (info function kind 'kernel:error-number-or-lose) :function)
    (setf (info function where-from 'kernel:error-number-or-lose) :defined)))

(defun fix-class (name)
  (let* ((new-value (find-class name))
	 (new-layout (kernel::%class-layout new-value))
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

;; Sometimes during cross-compile sparc::any-reg isn't defined during
;; cross-compile.
;;
;; hack, hack, hack: Make old-sparc::any-reg the same as
;; sparc::any-reg as an SC.  Do this by adding old-sparc::any-reg
;; to the hash table with the same value as sparc::any-reg.
(let ((ht (c::backend-sc-names c::*target-backend*)))
  (setf (gethash 'old-sparc::any-reg ht)
	(gethash 'sparc::any-reg ht)))
