;; IL Runtime Interface

;; Contains definitions for classes, types, methods, etc used to refer to 
;; the runtime.

;; Load AFTER il-gen.sch

(define il:scheme-assembly-name "Scheme")

(define-syntax define-il-class/type*
  (syntax-rules ()
    ((_ def ...)
     (begin (define-il-class/type . def) ...))))
(define-syntax define-il-class/type
  (syntax-rules ()
    ((_ realm class-id type-id class-string type-string)
     (begin
       (define-il-class class-id realm class-string)
       (define type-id (make-il-primtype type-string class-id))))
    ((_ realm class-id type-id class-string)
     (begin
       (define-il-class class-id realm class-string)
       (define type-id (make-il-classtype class-id))))
    ((_ realm class-id class-string)
     (define-il-class class-id realm class-string))))
(define-syntax define-il-class 
  (syntax-rules (mac so sys)
    ((_ class-id mac class-string)
     (define class-id 
       (make-il-class il:scheme-assembly-name '("Scheme" "RT") class-string)))
    ((_ class-id sys class-string)
     (define class-id
       (make-il-class "mscorlib" '("System") class-string)))
    ((_ class-id so class-string)
     (define class-id 
       (make-il-class il:scheme-assembly-name '("Scheme" "Rep") class-string)))))

(define-il-class/type*
 (mac il-reg          "Reg")
 (mac il-call         "Call")
 (mac il-cont         "Cont")
 (mac il-exn          "Exn")
 (mac il-ops          "Ops")
 (mac il-ops-special  "OpsSpecial")
 (mac il-load         "Load")
 (mac il-instructions "Instructions")

 (so il-schemefactory                    "Factory")
 (so il-schemeobject iltype-schemeobject "SObject")
 (so il-codevector   iltype-codevector   "CodeVector")
 (so il-fixnum       iltype-fixnum       "SFixnum")
 (so il-immediate    iltype-immediate    "SImmediate")
 (so il-schemechar   iltype-schemechar   "SChar")
 (so il-procedure    iltype-procedure    "Procedure")
 (so il-schemepair   iltype-schemepair   "SPair")

 (so il-svl               iltype-svl               "SVL")
 (so il-sbytevl           iltype-sbytevl           "SByteVL")
 (so il-continuation      iltype-continuation      "Continuation")
 
 (so il-loader-thunk iltype-loader-thunk "Twobit_Loader_Thunk")
 (mac il-code-address       iltype-code-address       "CodeAddress")
 (mac il-cache-link         iltype-cache-link         "CacheLink")
 (mac il-cache-frame        iltype-cache-frame        "StackCacheFrame")
 (mac il-continuation-frame iltype-continuation-frame "ContinuationFrame"))

(define (iltype:array iltype) (make-il-arraytype iltype))
(define iltype-schemeobject-array (iltype:array iltype-schemeobject))
(define iltype-fixnum-array (iltype:array iltype-fixnum))
(define iltype-schemechar-array (iltype:array iltype-schemechar))
(define iltype-schemepair-array (iltype:array iltype-schemepair))
(define iltype-procedure-array (iltype:array iltype-procedure))

(define-il-class/type*
  (sys il-byte   iltype-byte   "Byte"    "unsigned int8")
  (sys il-char   iltype-char   "Char"    "char")
  (sys il-int16  iltype-int16  "Int16"   "int16")
  (sys il-int32  iltype-int32  "Int32"   "int32")
  (sys il-int64	 iltype-int64  "Int64"   "int64")
  (sys il-uint32 iltype-uint32 "UInt32"  "unsigned int32")
  (sys il-uint64 iltype-uint64 "UInt64"  "unsigned int64")
  (sys il-double iltype-double "Double"  "float64")
  (sys il-string iltype-string "String"  "string")
  (sys il-void	 iltype-void   "Void"    "void"  )
  (sys il-bool	 iltype-bool   "Boolean" "bool"))

(define iltype-byte-array (iltype:array iltype-byte))
(define iltype-string-array (iltype:array iltype-string))
(define iltype-int16-array (iltype:array iltype-int16))

(define iltype-object "object")
(define il-object (make-il-class "mscorlib" "System" "Object"))

(define (rep:make-fixnum)
  (il:call '() iltype-fixnum il-schemefactory "makeFixnum" 
           (list iltype-int32)))
(define (rep:make-boolean)
  (il:call '() iltype-immediate il-schemefactory "makeBoolean"
           (list iltype-bool)))
(define (rep:make-flonum)
  (il:call '() iltype-sbytevl il-schemefactory "makeFlonum" 
           (list iltype-double)))
(define (rep:make-bytevector)
  (il:call '() iltype-sbytevl il-schemefactory "makeByteVector" 
           (list iltype-byte-array)))
;(define (rep:make-flonum-from-int8)
;  (il:call '() iltype-sbytevl il-schemefactory "makeFlonum"
;           (list iltype-int64)))
;(define (rep:make-bignum/ulong/sign)
;  (il:call '() iltype-sbytevl il-schemefactory "makeBignum"
;           (list iltype-uint64 iltype-bool)))
(define (rep:make-bignum/data)
  (il:call '() iltype-sbytevl il-schemefactory "makeBignum"
           (list iltype-int16-array iltype-bool)))

(define (rep:make-ratnum)
  (il:call '() iltype-svl il-schemefactory "makeRatnum"
           (list iltype-schemeobject iltype-schemeobject)))
(define (rep:make-rectnum)
  (il:call '() iltype-svl il-schemefactory "makeRectnum"
           (list iltype-schemeobject iltype-schemeobject)))
(define (rep:make-compnum)
  (il:call '() iltype-sbytevl il-schemefactory "makeCompnum"
           (list iltype-double iltype-double)))
(define (rep:make-string)
  (il:call '() iltype-sbytevl il-schemefactory "makeUString" 
           (list iltype-string)))
(define (rep:make-char)
  (il:call '() iltype-schemechar il-schemechar "makeChar" 
           (list iltype-int32)))
(define (rep:make-interned-symbol)
  (il:call '() iltype-svl il-schemefactory "internSymbol" 
           (list iltype-string)))
(define (rep:make-pair)
  (il:call '() iltype-schemepair il-schemefactory "makePair"
           (list iltype-schemeobject iltype-schemeobject)))
(define (rep:make-pair-reversed)
  (il:call '() iltype-schemepair il-schemefactory "makePairReversed"
           (list iltype-schemeobject iltype-schemeobject)))
(define (rep:make-vector)
  (il:call '() iltype-svl il-schemefactory "makeVector" 
           (list iltype-schemeobject-array)))
(define (rep:make-constantvector)
  (il:call '(new instance) iltype-void il-constantvector ".ctor" 
           (list iltype-schemepair-array 
                 iltype-constantvector-array
                 iltype-schemeobject-array)))

;(define bignum/ulong/sign?
;  (let ((2^64 (expt 2 64)))
;    (lambda (n)
;      (and (number? n) (exact? n) (integer? n) 
;           (<= (abs n) (- 2^64 1))))))

(define (bignum? x)
  (and (number? x) (exact? x) (integer? x) (not (fixnum? x))))

;; =========================================================
;; Representation-Dependent Code
;; Data access, etc

(define (rep:fixnum-from-pool n)
  (list (il:ldsfld iltype-fixnum-array il-fixnum "pool")
        (il 'ldc.i4 (- n FIXNUM-POOL-MIN))
        (il 'ldelem.ref)))

(define (rep:fixnum-value)
  (il:ldfld iltype-int32 il-fixnum "value"))

(define (rep:char-from-pool c)
  (list (il:ldsfld iltype-schemechar-array il-schemechar "characters")
        (il 'ldc.i4 (char->integer c))
        (il 'ldelem.ref)))

(define (rep:pair-car)
  (il:ldfld iltype-schemeobject il-schemepair "first"))
(define (rep:pair-cdr)
  (il:ldfld iltype-schemeobject il-schemepair "rest"))

(define (rep:set-pair-car!)
  (il:stfld iltype-schemeobject il-schemepair "first"))
(define (rep:set-pair-cdr!)
  (il:stfld iltype-schemeobject il-schemepair "rest"))

(define (rep:procedure-entrypoint)
  (il:ldfld iltype-codevector il-procedure "entrypoint"))

;; rep:load-static-link : number -> ilpackage
;; IL to load the MacScheme Procedure the given number of levels up the 
;; static link chain.

(define (rep:load-static-link up)
  (list
   (il:load-register ENV-REGISTER)
   ;(il 'castclass iltype-procedure)
   (let loop ((count up))
     (cond ((zero? count) '())
           (else (list ;(rep:procedure-rib)
                       ;(il 'ldc.i4 0)
                       ;(il 'ldelem.ref)
                       ;(il 'castclass iltype-procedure)
                       (rep:procedure-parent)
                       (loop (- count 1))))))))

;; rep:load-rib : number -> ilpackage
;; IL to load the MacScheme rib (array) the given number of levels up 
;; the static link chain.

(define (rep:load-rib up)
  (list (rep:load-static-link up)
        (rep:procedure-rib)))

;; rep:procedure-parent : -> ilpackage
;; Pops procedure, loads procedure's parent

(define (rep:procedure-parent)
  (il:ldfld iltype-procedure il-procedure "parent"))

;; rep:procedure-rib : -> ilpackage
;; Pops procedure, loads procedure's env rib

(define (rep:procedure-rib)
  (il:ldfld iltype-schemeobject-array il-procedure "rib"))

;; rep:procedure-constants : -> ilpackage
;; Pops procedure, loads procedure's constant vector

(define (rep:procedure-constants)
  (il:ldfld iltype-schemeobject-array il-procedure "constants"))

(define (rep:set-implicit-continuation label)
  (lambda (as)
    (list (il 'ldc.i4 (intern-label as label))
          (il:stsfld iltype-int32 il-reg "implicitContinuation"))))

(define (rep:reset-implicit-continuation)
  (list (il 'ldc.i4 -1)
        (il:stsfld iltype-int32 il-reg "implicitContinuation")))

(define (rep:get-timer)
  (il:ldsfld iltype-int32 il-reg "timer"))

(define (rep:set-timer)
  (il:stsfld iltype-int32 il-reg "timer"))

;; =========================================================
;; CONTINUATIONS

;(define (il:load-current-frame)
;  (rep:current-frame))

(define (rep:current-frame)
  (il:ldsfld iltype-cache-frame il-cont "cont"))

(define (rep:load-frame-slot slot)
  (if (< slot CONTINUATION-FRAME-SLOTS)
      (list
       (il:ldfld (if (zero? slot)
                     iltype-procedure
                     iltype-schemeobject) il-continuation-frame
                 (twobit-format #f "s~s" slot)))
      (list
       (il:ldfld iltype-schemeobject-array il-continuation-frame "overflowSlots")
       (il 'ldc.i4 (- slot CONTINUATION-FRAME-SLOTS))
       (il 'ldelem.ref))))

(define (rep:set-frame-slot slot ilpackage)
  (if (< slot CONTINUATION-FRAME-SLOTS)
      (list
       ilpackage
       (il:stfld (if (zero? slot)
                     iltype-procedure
                     iltype-schemeobject)
                 il-continuation-frame
                 (twobit-format #f "s~s" slot)))
      (list
       (il:ldfld iltype-schemeobject-array
                 il-continuation-frame "overflowSlots")
       (il 'ldc.i4 (- slot CONTINUATION-FRAME-SLOTS))
       ilpackage
       (il 'stelem.ref))))

(define (rep:load-current-frame-slot slot)
  (list (rep:current-frame)
        (rep:load-frame-slot slot)))

(define (rep:set-current-frame-slot slot ilpackage)
  (list (rep:current-frame)
        (rep:set-frame-slot slot ilpackage)))

(define (rep:frame-return-index)
  (il:ldfld iltype-int32 il-continuation-frame "returnIndex"))

(define (rep:set-frame-return-index!)
  (il:stfld iltype-int32 il-continuation-frame "returnIndex"))
