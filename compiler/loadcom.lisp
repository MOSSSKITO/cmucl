;;; -*- Package: C -*-
;;;
;;;    Load up the compiler.
;;;
(in-package "C")

(setf *load-verbose* t)

(load "vm:vm-macs")
(load "c:backend")
#-rt (load "vm:parms")
#+rt (load "vm:params")
(load "vm:objdef")
(load "c:macros")
(load "c:sset")
(load "c:node")
(load "c:alloc")
(load "c:ctype")
(load "c:knownfun")
(load "c:fndb")
(load "vm:vm-fndb")
(load "c:ir1util")
(load "c:ir1tran")
(load "c:ir1final")
(load "c:srctran")
(load "c:array-tran")
(load "c:seqtran")
(load "c:typetran")
(load "vm:vm-typetran")
(load "c:float-tran")
(load "c:locall")
(load "c:dfo")
(load "c:ir1opt")
;(load "c:loop")
(load "c:checkgen")
(load "c:constraint")
(load "c:envanal")
(load "c:vop")
(load "c:tn")
(load "c:bit-util")
(load "c:life")
(load "c:vmdef")
(load "c:gtn")
(load "c:ltn")
(load "c:stack")
(load "c:control")
(load "c:entry")
(load "c:ir2tran")
(load "c:pack")
(load "c:dyncount")
(load "c:statcount")
(load "c:codegen")
(load "c:main")
(load "c:disassem")
(load "c:assembler")
(load "c:assem-opt")
(load "assem:assemfile")
(load "assem:support")
(load "vm:macros")
(load "vm:utils")
(load "c:aliencomp")
(load "c:ltv")
(load "c:debug-dump")

(load "c:dump")
(load "vm:core")

(load "vm:vm")
(load "vm:insts")
#-rt (load "vm:primtype")
(load "vm:move")
(load "vm:sap")
(load "vm:system")
(load "vm:char")
#-rt (load "vm:float")
#+(and rt afpa) (load "vm:afpa")
#+(and rt (not afpa)) (load "vm:mc68881")

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
(load "vm:vm-tran")

(load "assem:assem-rtns")
#-rt (load "assem:bit-bash")
(load "assem:array")
(load "assem:arith")
(load "assem:alloc")

(load "c:pseudo-vops")
(load "vm:vm-tran")
(load "c:debug")
(load "c:assem-check")
(load "c:copyprop")
(load "c:represent")

(load "c:eval-comp")
(load "c:eval")

#+small
;;;
;;; If we want a small core, blow away the meta-compile time VOP info.
(setf (backend-parsed-vops *backend*) (make-hash-table :test #'eq))

(%proclaim '(optimize (speed 1) (safety 1)))
