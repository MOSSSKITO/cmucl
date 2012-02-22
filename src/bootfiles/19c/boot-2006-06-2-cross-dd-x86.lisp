;;; Cross-compile script for adding (complex double-double-float),
;;; (simple-array double-double-float (*)) and (simple-array (complex
;;; double-double-float) (*)).
;;;
;;; Use this to cross-compile from a version that supports
;;; double-double-float type with reader support.  Once this is done,
;;; do a full rebuild to get a version with support for these new
;;; types.

(in-package :cl-user)

;;; Rename the X86 package and backend so that new-backend does the
;;; right thing.
(rename-package "X86" "OLD-X86")
(setf (c:backend-name c:*native-backend*) "OLD-X86")

(c::new-backend "X86"
   ;; Features to add here
   '(:x86 :i486 :pentium
     :stack-checking
     :heap-overflow-check
     :relative-package-names
     :mp
     :gencgc
     :conservative-float-type
     :hash-new :random-mt19937
     :linux :glibc2 :glibc2.1
     :cmu :cmu19 :cmu19c
     :double-double			; double-double-float
     )
   ;; Features to remove from current *features* here
   '(:x86-bootstrap :alpha :osf1 :mips
     :propagate-fun-type :propagate-float-type :constrain-float-type
     :openbsd :freebsd :glibc2 :linux
     :long-float :new-random :small))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Things needed to cross-compile double-double changes.
(in-package "C")

(eval-when (compile load eval)
(defknown simple-array-double-double-float-p (t)
  boolean
  (movable foldable flushable))
(defknown double-double-float-p (t)
  boolean
  (movable foldable flushable))
(defknown complex-double-double-float-p (t)
  boolean
  (movable foldable flushable))
(defknown simple-array-complex-double-double-float-p (t)
  boolean
  (movable foldable flushable))
)

(in-package "LISP")
(define-fop (fop-double-double-float-vector 88)
  (let* ((length (read-arg 4))
	 (result (make-array length :element-type 'double-double-float)))
    (read-n-bytes *fasl-file* result 0 (* length 4 4))
    result))

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
	OLD-X86:DOUBLE-FLOAT-EXPONENT-BYTE
	OLD-X86:DOUBLE-FLOAT-NORMAL-EXPONENT-MAX 
	OLD-X86:DOUBLE-FLOAT-SIGNIFICAND-BYTE
	OLD-X86:SINGLE-FLOAT-EXPONENT-BYTE
	OLD-X86:SINGLE-FLOAT-NORMAL-EXPONENT-MAX
	OLD-X86:SINGLE-FLOAT-SIGNIFICAND-BYTE
	))

;; Modular arith hacks
(setf (fdefinition 'vm::ash-left-mod32) #'old-x86::ash-left-mod32)
(setf (fdefinition 'vm::lognot-mod32) #'old-x86::lognot-mod32)

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

;; hack, hack, hack: Make old-x86::any-reg the same as
;; x86::any-reg as an SC.  Do this by adding old-x86::any-reg
;; to the hash table with the same value as x86::any-reg.
(let ((ht (c::backend-sc-names c::*target-backend*)))
  (setf (gethash 'old-x86::any-reg ht)
	(gethash 'x86::any-reg ht)))
