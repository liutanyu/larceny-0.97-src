(define (assembly-table) $il-lcg-assembly-table$)
(define (assembly-start as)
  (let* ((old-source (as-source as))
	 (source*jlmap (establish-jump-points old-source))
	 (new-source (car source*jlmap))
	 (jump-table (cadr source*jlmap)))
    (as-source! as (cons (list $.entry jump-table -1) new-source))))
(define (assembly-end as segment) 
  segment)

(define (assembly-user-data) #f)
(define (assembly-user-local) #f)
(define (assembly-declarations user-data) '())
(define (assembly-postpass-segment as segment) 
  ;; (display `(assembly-postpass-segment as ,segment)) (newline)
  segment)

(define (as.dyn-meth as) (vector-ref (as-code as) 0))
(define (as.ilgen as)    (vector-ref (as-code as) 1))
(define (as.msgcount as) (vector-ref (as-code as) 3))
(define (as.incr-msgcount! as)
  (vector-set! (as-code as) 3 (+ 1 (vector-ref (as-code as) 3))))

;; The establish-jump-points procedure traverses MacScheme source,
;; generating jump indices for both explcit label instructions in the
;; source code and for implicit labels associated with opX
;; instructions that have an implicit continutation.  Each implicit
;; label is associated directly with a particular opX instruction,
;; which I am representing as an extra operand for the opX; that means
;; I need to either modify the given source code or generate a fresh
;; source structure.  I am currently taking the latter approach.
;;
;; Note that this function currently conservatively assumes that *any*
;; label might be a jump point, but this assumption might be much more 
;; conservative than necessary.  For example, it might suffice to only 
;; treat labels passed to setrtn as jump points.  I assume that 
;; over-conservativeness here implies that the initial switch table
;; might be larger than it should be and thus the initial dispatch 
;; might be less efficient than possible.

;; establish-jump-points : MalSource -> (list MalSource JLMap)
(define (establish-jump-points old-source)
  (let rec ((jl-map (new-jump-label-map))
	    (old-source old-source)
	    (new-source-rev '()))
    (cond
     ((null? old-source)
      (list (reverse new-source-rev) jl-map))
     (else
      (let* ((instruction (car old-source))
	     (malop (operand0 instruction)))
	;; (display instruction) (newline)
	(cond 
	 ((= malop $.label)
	  (let ()
	    (rec (found-jump-label jl-map (operand1 instruction))
		 (cdr old-source)
		 (cons instruction new-source-rev))))
	 ((or (and (= malop $op1) 
		   (op1-implicit-continuation? (operand1 instruction)))
	      (and (= malop $op2)
		   (op2-implicit-continuation? (operand1 instruction)))
	      (and (= malop $op2imm)
		   (op2-implicit-continuation? (operand1 instruction)))
	      (and (= malop $op3)
		   (op3-implicit-continuation? (operand1 instruction))))
	  (let* ((neg*jlmap (fresh-jump-label jl-map))
		 (neg (car neg*jlmap))
		 (jlmap* (cadr neg*jlmap))
		 (new-instruction (append instruction (list neg))))
	    (rec jlmap*
		 (cdr old-source)
		 (cons new-instruction
		       new-source-rev))))
	 (else 
	  (let ()
	    (rec jl-map
		 (cdr old-source)
		 (cons instruction new-source-rev))))))))))

;; A LopLabel is an Int
;; 
;; interpretation: non-negative lop labels correspond to MAL labels
;; from the input to the assembler; negative labels are implicit
;; continuation labels.

;; A JumpIndex is a Nat
;;
;; interpreration: index in the switch table at the entrypoint for
;; codevectors that are broken down into more than one basic block.

;; JLMap: ADT mapping from LopLabel to JumpIndex
;; new-jump-label-map     : () -> JLMap
;; found-jump-label       : JLMap Pos -> JLMap
;; fresh-jump-label       : JLMap -> (list Neg JLMap)
;; jump-label-map->alist  : JLMap -> AssocListof[ (list JumpIndex LopLabel) ]
;; jump-label-map->vector : JLMap -> Vectorof[ LopLabel ]

(define new-jump-label-map (unspecified))
(define found-jump-label (unspecified))
(define fresh-jump-label (unspecified))
(define jump-label-lmap->alist     (unspecified))

(let () 
  ;; JLMap implementation:
  ;; A JLMap is a AssocListof[ (list Int Nat) ]
  (define (new-jump-label-map*) '())
  (define (found-jump-label* jl-map num)
    (cond 
     ((assv num jl-map) jl-map)
     (else
      (let ((new-idx (+ 1 (length jl-map))))
	(cons (list num new-idx) jl-map)))))
  (define (fresh-jump-label* jl-map)
    (let* ((new-idx (+ 1 (length jl-map)))
	   (neg (- new-idx))
	   (jl-map* (cons (list neg new-idx) jl-map)))
      (list neg jl-map*)))
  (define (jump-label-map->alist* jl-map)
    (map reverse jl-map))
  (define (jump-label-map->vector* jl-map)
    (let ((vec (make-vector (length jl-map) #f)))
      (for-each (lambda (x)
		  (let ((idx (cadr x)))
		    (cond ((vector-ref vec idx) (error)))
		    (vector-set! vec idx (car x))))
		jl-map)
      vec))

  (set! new-jump-label-map new-jump-label-map*)
  (set! found-jump-label found-jump-label*)
  (set! fresh-jump-label fresh-jump-label*)
  (set! jump-label-map->alist jump-label-map->alist*)
  (set! jump-label-map->vector jump-label-map->vector*)
  )
  
(define (as-jump-table as)
  (vector-ref (as-code as) 2))
(define (as-jump-table! as new-jump-table)
  (vector-set! (as-code as) 2 new-jump-table))

;; entry-label! : Asm Label -> ()
(define (entry-label! as label)
  (let ((index (as-jump-table as)))
    (if (assq 'entry index) 
	(error 'entry-label! "entry should be set only once."))
    (if (and #f (not (null? index)))
	(error 'entry-label! "entry should be set before any other label."))
    (as-jump-table! as (cons (list 'entry 0 label) index))))

;; intern-label : Asm Num -> (Num . Label)
(define (intern-label as num)
  (let* ((index (as-jump-table as))
	 (jump-count (length index)))
    (cond 
     ((assv num index) => (lambda (entry) 
			    (let ((jump-idx (cadr entry))
				  (lcg-label (caddr entry)))
			      (cons jump-idx lcg-label))))
     (else 
      (error 'intern-label "now should never fail a lookup.")
      (let* ((lcg-label (fresh-lcg-label as num))
	     (jump-idx jump-count)
	     (new-index (cons (list num jump-count lcg-label) index)))
	(as-jump-table! as new-index)
	(cons jump-idx lcg-label))))))

;; (This function is redefined by Asm/IL/pass5p1, so I am redefining
;;  it here as well even though this code does not use the il:delay
;;  constructions.)
;; 
;; assemble-pasteup : assembler -> (cons code constants)
(define (assemble-pasteup as)
  '(begin (display `(assemble-pasteup as ,(as.msgcount as))) (newline))
  (let* ((dyn-meth (as.dyn-meth as))
	 ;;(control-point-count (length (as-labels as)))
	 (control-point-count (length (as-jump-table as)))
	 (foreign-codevector 
	  (lcg:makeCodeVector (clr/int->foreign control-point-count) 
			      dyn-meth))
	 (code (clr/%foreign->schemeobject foreign-codevector))
	 (constants (list->vector (as-constants as))))
    (cons code constants)))

(define $il-lcg-assembly-table$
  (make-vector
   *number-of-mnemonics*
   (lambda (instruction as)
     (error "Unrecognized mnemonic " instruction))))

(define-syntax define-instruction
  (syntax-rules () 
    ((define-instruction i proc)
     (begin 
       (let ((idx i))
	 (define i proc)
	 (vector-set! $il-lcg-assembly-table$ idx i)
	 #t)))))

(define (lcg:type-getter prefix) 
  (lambda (x) (clr/%get-type (string-append prefix x))))
(define lcg:rep-type  (lcg:type-getter "Scheme.Rep."))
(define lcg:rts-type  (lcg:type-getter "Scheme.RT."))
(define lcg:sys-type  (lcg:type-getter "System."))
(define lcg:emit-type (lcg:type-getter "System.Reflection.Emit."))
(define lcg:refl-type (lcg:type-getter "System.Reflection."))

(define lcg:type:dynamicmethod      (lcg:emit-type "DynamicMethod"))
(define lcg:type:schemeobject       (lcg:rep-type "SObject"))
(define lcg:type:schemeobject-array (lcg:rep-type "SObject[]"))
(define lcg:type:code-address       (lcg:rts-type "CodeAddress"))
(define lcg:type:void               (lcg:sys-type "Void"))
(define lcg:type:instructions       (lcg:rts-type "Instructions"))
(define lcg:type:reg                (lcg:rts-type "Reg"))
(define lcg:type:exn                (lcg:rts-type "Exn"))
(define lcg:type:codevector         (lcg:rep-type "CodeVector"))
(define lcg:type:fixnum             (lcg:rep-type "SFixnum"))
(define lcg:type:fixnum-array       (lcg:rep-type "SFixnum[]"))
(define lcg:type:factory            (lcg:rep-type "Factory"))
(define lcg:type:call               (lcg:rts-type "Call"))
(define lcg:type:immediate          (lcg:rep-type "SImmediate"))
(define lcg:type:schemechar         (lcg:rep-type "SChar"))
(define lcg:type:schemechar-array   (lcg:rep-type "SChar[]"))
(define lcg:type:schemepair         (lcg:rep-type "SPair"))
(define lcg:type:cont               (lcg:rts-type "Cont"))
(define lcg:type:cache-frame        (lcg:rts-type "StackCacheFrame"))
(define lcg:type:continuation-frame (lcg:rts-type "ContinuationFrame"))
(define lcg:type:procedure          (lcg:rep-type "Procedure"))
(define lcg:type:ilgenerator        (lcg:emit-type "ILGenerator"))
(define lcg:type:label              (lcg:emit-type "Label"))
(define lcg:type:opcode             (lcg:emit-type "Opcode"))
(define lcg:type:opcodes            (lcg:emit-type "Opcodes"))
(define lcg:type:fieldinfo          (lcg:refl-type "FieldInfo"))
(define lcg:type:methodinfo         (lcg:refl-type "MethodInfo"))
(define lcg:type:localbuilder       (lcg:emit-type "LocalBuilder"))
(define lcg:type:type               (lcg:sys-type  "Type"))
(define lcg:type:byte               (lcg:sys-type  "Byte"))
(define lcg:type:int16              (lcg:sys-type  "Int16"))
(define lcg:type:int32              (lcg:sys-type "Int32"))
(define lcg:type:int64              (lcg:sys-type "Int64"))
(define lcg:type:double             (lcg:sys-type "Double"))
(define lcg:type:string             (lcg:sys-type "String"))
(define lcg:type:boolean            (lcg:sys-type "Boolean"))
(define lcg:type:type-array         (lcg:sys-type "Type[]"))
(define lcg:type:label-array        (lcg:emit-type "Label[]"))

(define (vector->foreign-array base-type vec)
  (let* ((len (vector-length vec))
	 (arr (allocate-clr-array base-type len)))
    (let loop ((i 0))
      (cond ((< i len)
	     (clr/%foreign-aset arr i (vector-ref vec i))
	     (loop (+ i 1)))))
    arr))

(define new-dynamic-method-of
  (let* ((type-recv lcg:type:dynamicmethod)
	 (type-arg1 lcg:type:string)
	 (type-arg2 lcg:type:type)
	 (type-arg3 lcg:type:type-array)
	 (type-arg4 lcg:type:type)
	 (type-arg5 lcg:type:boolean)
	 (ctor (clr-method->procedure
		(clr/%get-constructor 
		 type-recv (vector type-arg1 type-arg2 type-arg3 
				   type-arg4 type-arg5)))))
    (lambda (name ret-type arg-typev class skip-checks)
      (ctor (clr/string->foreign name)
	    ret-type
	    (vector->foreign-array lcg:type:type arg-typev)
	    class
	    (clr/bool->foreign skip-checks)))))

(define new-dynamic-method 
  (let* ((type-recv (clr/%get-type "System.Reflection.Emit.DynamicMethod"))
	 (type-arg1 (clr/%get-type "System.String"))
	 (type-arg2 (clr/%get-type "System.Type"))
	 (type-arg3 (clr/%get-type "System.Type[]"))
	 (ctor (clr-method->procedure 
		(clr/%get-constructor 
		 type-recv (vector type-arg1 type-arg2 type-arg3 )))))
    (define new-dynamic-method
      (lambda (name ret-type type-array)
	(ctor name ret-type type-array)))
    new-dynamic-method))

(define new-codevector-dynamic-method
  (let ((type-array (vector->foreign-array 
		     lcg:type:type
		     (vector clr-type-handle/system-int32))))
    (lambda (name)
      (new-dynamic-method (clr/string->foreign name)
			  lcg:type:code-address
			  type-array))))

(define dynamic-method->il-generator
  (let* ((type-recv lcg:type:dynamicmethod)
	 (meth (clr/%get-method type-recv "GetILGenerator" '#()))
	 (get-ilgen (clr-method->procedure meth)))
    (define dynamic-method->il-generator
      (lambda (dyn-meth)
	(get-ilgen dyn-meth)))
    dynamic-method->il-generator))

(define (lcg:iota n) 
  (let loop ((i (- n 1)) (l '()))
    (if (< i 0) l (loop (- i 1) (cons i l)))))

(define (lcg:static-method ret-type recv-type method-name arg-types)
  (or (clr/%get-method recv-type method-name (list->vector arg-types))
      (error 'lcg:static-method "unknown method " method-name 
	     " with params " arg-types " for " recv-type)))
(define (lcg:instance-method ret-type recv-type method-name arg-types)
  (or (clr/%get-method recv-type method-name (list->vector arg-types))
      (error 'lcg:instance-method "unknown method " method-name 
	     " with params " arg-types " for " recv-type)))
(define lcg:op-instance-method
  (let* ((op->method 
	  (lambda (opcode arg-types)
	    (let* ((method-name 
		    (twobit-format #f "op_~a" (csharp-op-name opcode))))
	      (lcg:instance-method lcg:type:void 
				   lcg:type:schemeobject 
				   method-name
				   arg-types))))
	 (op1->method (lambda (opcode) (op->method opcode '())))
	 (op2->method (lambda (opcode) 
			(op->method opcode (list lcg:type:schemeobject))))
	 (op3->method (lambda (opcode) 
			(op->method opcode (list lcg:type:schemeobject
						 lcg:type:schemeobject)))))
    (letrec-syntax
	((method-cache 
	  (syntax-rules (op1 op2 op3)
	    ((_ () (METHOD-BINDING ...) (OP-CASE ...))
	     (let (METHOD-BINDING ...)
	       (lambda (ret-type opcode arg-types)
		 (case opcode
		   OP-CASE ...
		   (else 
		    (begin
		      (display 
		       `(lcg:op-instance-method ,opcode ,arg-types))
		      (newline))
		    (op->method opcode arg-types))))))
	    ((_ ((OP->METHOD NAME) OPS ...) (METHOD-BINDING ...) (OP-CASE ...))
	     (method-cache (OPS ...) 
			   ((fresh (OP->METHOD 'NAME)) METHOD-BINDING ...)
			   (((NAME) fresh) OP-CASE ...)))))
	 (build-method-cache
	  (syntax-rules ()
	    ((build-method-cache (OP->METHOD NAME) ...)
	     (method-cache ((OP->METHOD NAME) ...) () ()))))
	 (gather-ops
	  (syntax-rules (op1 op2 op3)
	    ((gather-ops (op1 OP1-NAMES ...)
			 (op2 OP2-NAMES ...)
			 (op3 OP3-NAMES ...))
	     (build-method-cache
	      (op1->method OP1-NAMES) ...
	      (op2->method OP2-NAMES) ...
	      (op3->method OP3-NAMES) ...))))
	 )
      (gather-ops

       (op1 -- break bytevector? bytevector-length 
	    car car:pair cdr cdr:pair cell-ref 
	    char? char->integer complex? 
	    disable-interrupts
	    enable-interrupts
	    eof-object eof-object? exact? exact->inexact 
	    fixnum? flonum? fxlognot imag-part inexact? inexact->exact 
	    integer? integer->char 
	    make-bytevector make-cell make-procedure
	    most-positive-fixnum
	    not null? pair? port? procedure? procedure-length
	    rational? real-part structure? symbol? typetag
	    undefined unspecified ustring? ustring-length:str 
	    vector? vector-length:vec zero?)

       (op2 * + = - > >= < <:fix:fix <= <=:fix:fix / 
	    bytevector-ref cell-set! char=? char<=? cons 
	    eq? eqv? fxlogand fxlogior fxlogxor fxlsh fxrshl 
	    make-ustring make-vector procedure-ref quotient 
	    remainder set-car! set-cdr! typetag-set! 
	    ustring-ref:trusted vector-ref:trusted)

       (op3 bytevector-like-set! bytevector-set! procedure-set!
	    ustring-set!:trusted vector-like-set! vector-set!:trusted)

       ))))

(define (lcg:fieldinfo field-type recv-type field-name)
  (or (clr/%get-field recv-type field-name)
      (error 'lcg:fieldinfo "unknown field " field-name
	     " for " recv-type)))

(define lcg:method:makeCodeVector
  (lcg:static-method lcg:type:codevector lcg:type:factory "makeCodeVector" (list lcg:type:int32 lcg:type:dynamicmethod)))
(define lcg:makeCodeVector
  (clr-method->procedure lcg:method:makeCodeVector))
(define lcg:method:get_Register0
  (lcg:static-method lcg:type:schemeobject lcg:type:reg "get_Register0" '()))
(define lcg:method:faultGlobal
  (lcg:static-method lcg:type:code-address lcg:type:exn "faultGlobal" (list lcg:type:int32)))
(define lcg:method:global
  (lcg:static-method lcg:type:void lcg:type:instructions "global" (list lcg:type:int32 lcg:type:string)))
(define lcg:method:lambda
  (lcg:static-method lcg:type:void lcg:type:instructions "lambda" (list lcg:type:codevector lcg:type:int32 lcg:type:int32)))
(define lcg:method:lexes
  (lcg:static-method lcg:type:void lcg:type:instructions "lexes" (list lcg:type:int32)))
(define lcg:method:faultArgCount
  (lcg:static-method lcg:type:void lcg:type:exn "faultArgCount" (list lcg:type:int32)))
(define lcg:method:argsge
  (lcg:static-method lcg:type:void lcg:type:instructions "argsge" (list lcg:type:int32)))
(define lcg:method:faultInvokeNonProc
  (lcg:static-method lcg:type:code-address lcg:type:exn "faultInvokeNonProc" (list lcg:type:int32)))
(define lcg:method:makeFixnum
  (lcg:static-method lcg:type:fixnum lcg:type:factory "makeFixnum" (list lcg:type:int32)))
(define lcg:method:get_ProcRegister0
  (lcg:static-method lcg:type:procedure lcg:type:reg "get_ProcRegister0" '()))
(define lcg:method:set_ProcRegister0
  (lcg:static-method lcg:type:void lcg:type:reg "set_ProcRegister0" (list lcg:type:procedure)))
(define lcg:method:faultTimer
  (lcg:static-method lcg:type:code-address lcg:type:exn "faultTimer" (list lcg:type:int32)))
(define lcg:method:call
  (lcg:static-method lcg:type:code-address lcg:type:call "call" (list lcg:type:codevector lcg:type:int32)))
(define lcg:method:faultApplyNonProc
  (lcg:static-method lcg:type:code-address lcg:type:exn "faultApplyNonProc" (list lcg:type:int32 lcg:type:int32)))
(define lcg:method:applySetup
  (lcg:static-method lcg:type:int32 lcg:type:call "applySetup" (list lcg:type:int32 lcg:type:int32)))
(define lcg:method:save
  (lcg:static-method lcg:type:void lcg:type:instructions "save" (list lcg:type:int32)))
(define lcg:method:offset->save 
  (let ((save-methods
	 (let ((n->save-method 
		(lambda (n)
		  (lcg:static-method lcg:type:void
				     lcg:type:instructions 
				     (string-append "save" (number->string n)) 
				     '()))))
	   (list->vector (map n->save-method (lcg:iota 8))))))
    (lambda (n)
      (vector-ref save-methods n))))
    
(define lcg:method:save_storem_uniform
  (lcg:static-method lcg:type:void lcg:type:instructions "save_storem_uniform" (list lcg:type:int32)))
(define lcg:method:loadm_uniform
  (lcg:static-method lcg:type:void lcg:type:instructions "loadm_uniform" (list lcg:type:int32)))
(define lcg:method:offset->pop 
  (let ((pop-methods 
	 (let ((n->pop-method 
		(lambda (n)
		  (lcg:static-method lcg:type:void
				     lcg:type:instructions 
				     (string-append "pop" (number->string n)) 
				     '()))))
	   (list->vector (map n->pop-method (lcg:iota 8))))))
    (lambda (n)
      (vector-ref pop-methods n))))
;; (define lcg:method:restore
;;   (lcg:static-method lcg:type:void lcg:type:instructions "restore" (list lcg:type:int32)))
(define lcg:method:pop
  (lcg:static-method lcg:type:void lcg:type:instructions "pop" (list lcg:type:int32)))

(define lcg:method:offset->set_register 
  (let ((methods 
	 (let ((n->setreg-method
		(lambda (n)
		  (let* ((nstr (number->string n))
			 (name (string-append "set_Register" nstr)))
		    (lcg:static-method lcg:type:void
				       lcg:type:reg
				       name
				       (list lcg:type:schemeobject))))))
	   (list->vector (map n->setreg-method (lcg:iota 32))))))
    (lambda (n) 
      (vector-ref methods n))))
(define lcg:method:offset->get_register
  (let ((methods
	 (let ((n->getreg-method 
		(lambda (n)
		  (let* ((nstr (number->string n))
			 (name (string-append "get_Register" nstr)))
		    (lcg:static-method lcg:type:schemeobject 
				       lcg:type:reg 
				       name
				       '())))))
	   (list->vector (map n->getreg-method (lcg:iota 32))))))
    (lambda (n)
      (vector-ref methods n))))
(define lcg:method:offset->reg_to_result 
  (let ((methods 
	 (let ((n->reg-method 
		(lambda (n)
		  (let* ((nstr (number->string n))
			 (name (string-append "reg" nstr)))
		  (lcg:static-method lcg:type:void lcg:type:instructions 
				     name
				     '())))))
	   (list->vector (map n->reg-method (lcg:iota 32))))))
    (lambda (n)
      (vector-ref methods n))))       
(define lcg:method:offset->result_to_reg 
  (let ((methods 
	 (let ((n->setreg-method
		(lambda (n)
		  (let* ((nstr (number->string n))
			 (name (string-append "setreg" nstr)))
		    (lcg:static-method lcg:type:void lcg:type:instructions 
				       name
				       '())))))
	   (list->vector (map n->setreg-method (lcg:iota 32))))))
    (lambda (n)
      (vector-ref methods n))))
(define lcg:method:fault
  (lcg:static-method lcg:type:code-address lcg:type:exn "fault" (list lcg:type:int32)))

(define lcg:method:op_cell_ref 
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject "op_cell_ref" '()))
(define lcg:method:rtn
  (lcg:static-method lcg:type:code-address lcg:type:instructions "rtn" (list)))
(define lcg:method:setrtn
  (lcg:static-method lcg:type:void lcg:type:instructions "setrtn" 
		     (list lcg:type:codevector lcg:type:int32)))
(define lcg:method:setstk
  (lcg:static-method lcg:type:void lcg:type:instructions "setstk"
		     (list lcg:type:int32)))
(define lcg:method:op_eqp_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject "op_eqp_int32" 
		       (list lcg:type:int32)))
(define lcg:method:op_plus_int32
  (lcg:instance-method lcg:type:void lcg:type:schemeobject "op_plus_int32" 
		       (list lcg:type:int32)))
(define lcg:method:op_minus_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject "op_minus_int32" 
		       (list lcg:type:int32)))
(define lcg:method:op_numeric_equals_int32
  (lcg:instance-method lcg:type:void lcg:type:schemeobject "op_numeric_equals_int32" 
		       (list lcg:type:int32)))
(define lcg:method:op_fxless_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject "op_fxless_int32" 
		       (list lcg:type:int32)))

(define lcg:method:op_vector_length_vec
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject "op_vector_length_vec" '()))
(define lcg:method:op_greaterequal_fix_fix_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject "op_greaterequal_fix_fix_int32" (list lcg:type:int32)))
(define lcg:method:isEqpInt32
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject "isEqpInt32" 
		       (list lcg:type:int32)))
(define lcg:method:isPair
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject "isPair" '()))
(define lcg:method:isFixnum
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject "isFixnum" '()))
(define lcg:method:isCharEqualsInt32
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject "isCharEqualsInt32"
		       (list lcg:type:int32)))
(define lcg:method:makePair
  (lcg:static-method lcg:type:schemepair lcg:type:factory "makePair" 
		     (list lcg:type:schemeobject lcg:type:schemeobject)))
(define lcg:method:makeBoolean
  (lcg:static-method lcg:type:immediate lcg:type:factory "makeBoolean" 
		     (list lcg:type:boolean)))
(define lcg:method:op_charequals_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject 
		       "op_charequals_int32" (list lcg:type:int32)))
(define lcg:method:op_vector_ref_trusted_int32 
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject
		       "op_vector_ref_trusted_int32" (list lcg:type:int32)))
(define lcg:method:op_less_fix_fix_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject
		       "op_less_fix_fix_int32" (list lcg:type:int32)))
(define lcg:method:op_plus_idx_idx_int32
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject
		       "op_plus_idx_idx_int32" (list lcg:type:int32)))
(define lcg:method:op_char2integer
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject 
		       "op_char2integer" '()))
(define lcg:method:isVector
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject
		       "isVector" '()))
(define lcg:method:op_charp
  (lcg:instance-method lcg:type:schemeobject lcg:type:schemeobject
		       "op_charp" '()))
(define lcg:method:isChar
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject
		       "isChar" '()))
(define lcg:method:isNumericEqualFixFixInt32
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject
		       "isNumericEqualFixFixInt32" (list lcg:type:int32)))
(define lcg:method:isLessFixFixInt32
  (lcg:instance-method lcg:type:boolean lcg:type:schemeobject
		       "isLessFixFixInt32" (list lcg:type:int32)))

(define lcg:field:null (lcg:fieldinfo lcg:type:immediate lcg:type:factory "Null"))
(define lcg:field:true (lcg:fieldinfo lcg:type:immediate lcg:type:factory "True"))
(define lcg:field:false (lcg:fieldinfo lcg:type:immediate lcg:type:factory "False"))
(define lcg:field:eof (lcg:fieldinfo lcg:type:immediate lcg:type:factory "Eof"))
(define lcg:field:unspecified (lcg:fieldinfo lcg:type:immediate lcg:type:factory "Unspecified"))
(define lcg:field:undefined (lcg:fieldinfo lcg:type:immediate lcg:type:factory "Undefined"))
(define lcg:field:zero  (lcg:fieldinfo lcg:type:fixnum lcg:type:fixnum "zero"))
(define lcg:field:one   (lcg:fieldinfo lcg:type:fixnum lcg:type:fixnum "one"))
(define lcg:field:two   (lcg:fieldinfo lcg:type:fixnum lcg:type:fixnum "two"))
(define lcg:field:three (lcg:fieldinfo lcg:type:fixnum lcg:type:fixnum "three"))
(define lcg:field:four  (lcg:fieldinfo lcg:type:fixnum lcg:type:fixnum "four"))
(define (lcg:field:N->enn n)
  (case n
    ((0) lcg:field:zero) ((1) lcg:field:one) ((2) lcg:field:two)
    ((3) lcg:field:three) ((4) lcg:field:four)))
(define lcg:field:characters (lcg:fieldinfo lcg:type:schemechar-array lcg:type:schemechar "characters"))
(define lcg:field:constants (lcg:fieldinfo lcg:type:schemeobject-array lcg:type:procedure "constants"))
(define lcg:field:result (lcg:fieldinfo lcg:type:schemeobject lcg:type:reg "Result"))
(define lcg:field:first (lcg:fieldinfo lcg:type:schemeobject lcg:type:schemepair "first"))
(define lcg:field:rest (lcg:fieldinfo lcg:type:schemeobject lcg:type:schemepair "rest"))
(define lcg:field:value (lcg:fieldinfo lcg:type:int32 lcg:type:fixnum "value"))
(define lcg:field:second (lcg:fieldinfo lcg:type:schemeobject lcg:type:reg "Second"))
(define lcg:field:third (lcg:fieldinfo lcg:type:schemeobject lcg:type:reg "Third"))
(define lcg:field:pool (lcg:fieldinfo lcg:type:fixnum-array lcg:type:fixnum "pool"))
(define lcg:field:timer (lcg:fieldinfo lcg:type:int32 lcg:type:reg "timer"))
(define lcg:field:entrypoint (lcg:fieldinfo lcg:type:codevector lcg:type:procedure "entrypoint"))
(define lcg:field:cont (lcg:fieldinfo lcg:type:cache-frame lcg:type:cont "cont"))
(define lcg:field:offset->slot 
  (let ((slots
	 (let ((n->fieldinfo
		(lambda (n)
		  (let* ((nstr (string-append "s" (number->string n)))
			 (ftype (if (zero? n) 
				    lcg:type:procedure lcg:type:schemeobject)))
		    (lcg:fieldinfo ftype lcg:type:continuation-frame nstr)))))
	   (list->vector (map n->fieldinfo (lcg:iota 8))))))
    (lambda (n)
      (vector-ref slots n))))
(define lcg:field:overflowSlots (lcg:fieldinfo lcg:type:schemeobject-array lcg:type:continuation-frame "overflowSlots"))
(define lcg:field:returnIndex (lcg:fieldinfo lcg:type:int32 lcg:type:continuation-frame "returnIndex"))
(define lcg:field:parent (lcg:fieldinfo lcg:type:procedure lcg:type:procedure "parent"))
(define lcg:field:rib (lcg:fieldinfo lcg:type:schemeobject-array lcg:type:procedure "rib"))
(define lcg:field:implicit-continuation (lcg:fieldinfo lcg:type:int32 lcg:type:reg "implicitContinuation"))

(define (lcg:op:beq p)        `(beq ,p))
(define (lcg:op:beq.s p)      `(beq.s ,p))
(define (lcg:op:bne.un.s p)   `(bne.un.s ,p))
(define (lcg:op:br p)         `(br ,p))
(define (lcg:op:brtrue p)     `(brtrue ,p))
(define (lcg:op:brtrue.s p)   `(brtrue.s ,p))
(define (lcg:op:brfalse p)    `(brfalse ,p))
(define (lcg:op:brfalse.s p)  `(brfalse.s ,p))
(define (lcg:op:call p)       `(call ,p))
(define (lcg:op:callvirt p)   `(callvirt ,p))
(define (lcg:op:castclass p)  `(castclass ,p))
(define (lcg:op:ceq)          `(ceq))
(define (lcg:op:dup)          `(dup))
(define (lcg:op:isinst p)     `(isinst ,p))
(define (lcg:op:ldarg p)      `(ldarg ,p))
(define (lcg:op:ldarg.0)      `(ldarg.0))
(define (lcg:op:ldarg.1)      `(ldarg.1))
(define (lcg:op:ldc.i4 p)     `(ldc.i4 ,p))
(define (lcg:op:ldelem.ref)   `(ldelem.ref))
(define (lcg:op:ldfld p)      `(ldfld ,p))
(define (lcg:op:ldloc p)      `(ldloc ,p))
(define (lcg:op:ldsfld p)     `(ldsfld ,p))
(define (lcg:op:ldstr p)      `(ldstr ,p))
(define (lcg:op:pop)          `(pop))
(define (lcg:op:ret)          `(ret))
(define (lcg:op:stelem.ref)   `(stelem.ref))
(define (lcg:op:stfld p)      `(stfld ,p))
(define (lcg:op:stloc p)      `(stloc ,p))
(define (lcg:op:stsfld p)     `(stsfld ,p))
(define (lcg:op:sub)          `(sub))
(define (lcg:op:switch ps)    `(switch ,ps))

(define lcg:sym->opcode 
  (let* ((get-opcode (lambda (name)
		       (or (clr/%field-ref 
			    (clr/%get-field lcg:type:opcodes name) #f)
			   (error 'lcg:sym->opcode ": unknown field " name)))))
    (let-syntax ((op-dispatcher 
		  (syntax-rules ()
		    ((op-dispatcher (op name) ...)
		     (let ((op (get-opcode name))
			   ...)
		       (lambda (sym)
			 (case sym
			   ((op) op)
			   ...
			   (else (error 'lcg:sym->opcode "unknown opcode " sym))
			   )))))))
      (op-dispatcher 
       (beq "Beq") (beq.s "Beq_S") (bne.un.s "Bne_Un_S") (br "Br") 
       (brfalse "Brfalse") (brfalse.s "Brfalse_S")
       (brtrue "Brtrue") (brtrue.s "Brtrue_S")
       (call "Call") (callvirt "Callvirt") (castclass "Castclass")
       (ceq "Ceq")
       (dup "Dup")
       (isinst "Isinst")
       (ldarg "Ldarg")
       (ldarg.0 "Ldarg_0") (ldarg.1 "Ldarg_1") 
       (ldarg.2 "Ldarg_2") (ldarg.3 "Ldarg_3") 
       (ldc.i4 "Ldc_I4") (ldelem.ref "Ldelem_Ref")
       (ldloc "Ldloc") (ldfld "Ldfld") (ldnull "Ldnull") (ldsfld "Ldsfld")
       (ldstr "Ldstr")
       (pop "Pop")
       (ret "Ret")
       (stelem.ref "Stelem_Ref") (stfld "Stfld")
       (stloc "Stloc") (stsfld "Stsfld") (sub "Sub") (switch "Switch")
       ))))

(define ilgen-msg!
  (let* ((type-recv         lcg:type:ilgenerator)
	 (type-label        lcg:type:label)
	 (type-opcode       lcg:type:opcode)
	 (type-fieldinfo    lcg:type:fieldinfo)
	 (type-methodinfo   lcg:type:methodinfo)
	 (type-localbuilder lcg:type:localbuilder)
	 (type-type         lcg:type:type)
	 (type-byte         lcg:type:byte)
	 (type-int16        lcg:type:int16)
	 (type-int32        lcg:type:int32)
	 (type-int64        lcg:type:int64)
	 (type-double       lcg:type:double)
	 (type-string       lcg:type:string)
	 (type-typearr      lcg:type:type-array)
	 (type-labelarr     lcg:type:label-array)
	 (get-method 
	  (lambda (name . types)
	    (clr-method->procedure
	     (or (clr/%get-method type-recv name (list->vector types))
		 (error 'get-method ": failed for " name types)))))
	 (define-label/meth    (get-method "DefineLabel"))
	 (declare-local/meth   (get-method "DeclareLocal" type-type))
	 (mark-label/meth      (get-method "MarkLabel" type-label))
	 (emit-call/meth       (get-method "EmitCall" 
					   type-opcode 
					   type-methodinfo 
					   type-typearr))
	 (emit-write-line/meth (get-method "EmitWriteLine"
					   type-string))
	 (get-emit-method (lambda types
			    (apply get-method "Emit" type-opcode types)))
	 (emit/meth              (get-emit-method))
	 (emit-label/meth        (get-emit-method type-label))
	 (emit-byte/meth         (get-emit-method type-byte))
	 (emit-int16/meth        (get-emit-method type-int16))
	 (emit-int32/meth        (get-emit-method type-int32))
	 (emit-int64/meth        (get-emit-method type-int64))
	 (emit-double/meth       (get-emit-method type-double))
	 (emit-string/meth       (get-emit-method type-string))
	 (emit-type/meth         (get-emit-method type-type))
	 (emit-localbuilder/meth (get-emit-method type-localbuilder))
	 (emit-fieldinfo/meth    (get-emit-method type-fieldinfo))
	 (emit-methodinfo/meth   (get-emit-method type-methodinfo))
	 (emit-labelarr/meth     (get-emit-method type-labelarr))
	 )
    (define (ilgen-msg! as msg . package)
      (as.incr-msgcount! as)
      ;; (begin (display `(ilgen-msg! as ,msg . ,package)) (newline))
      (let ((ilgen (as.ilgen as)))
	(case msg
	  ((begin-catch-block) ...)
	  ((begin-except-filter-block) ...)
	  ((begin-exception-block) ...)
	  ((begin-fault-block) ...)
	  ((begin-finally-block) ...)
	  ((begin-scope) ...)
	  ((declare-local) (declare-local/meth ilgen (car package)))
	  ((define-label)  (define-label/meth ilgen))
	  ((emit-call)     (emit-call/meth ilgen 
					   (car package) 
					   (cadr package) 
					   (caddr package)))
	  ((emit)          (emit/meth ilgen (car package)))
	  ((emit-byte)     (emit-byte/meth ilgen 
					   (car package)
					   (cadr package)))
	  ((emit-double)   (emit-double/meth ilgen
					     (car package)
					     (cadr package)))
	  ((emit-int16)    (emit-int16/meth ilgen 
					    (car package) 
					    (cadr package)))
	  ((emit-int32)    (emit-int32/meth ilgen 
					    (car package) 
					    (cadr package)))
	  ((emit-int64)    (emit-int64/meth ilgen 
					    (car package) 
					    (cadr package)))
	  ((emit-label)    (emit-label/meth ilgen 
					    (car package) 
					    (cadr package)))
	  ((emit-labelarr) (emit-labelarr/meth ilgen 
					       (car package) 
					       (cadr package)))
	  ((emit-string)   (emit-string/meth ilgen 
					     (car package) 
					     (cadr package)))
	  ((emit-type)         (emit-type/meth ilgen 
					       (car package) 
					       (cadr package)))
	  ((emit-fieldinfo)    (emit-fieldinfo/meth ilgen
						    (car package)
						    (cadr package)))
	  ((emit-methodinfo)   (emit-methodinfo/meth ilgen
						     (car package)
						     (cadr package)))
	  ((emit-localbuilder) (emit-localbuilder/meth ilgen
						       (car package)
						       (cadr package)))
	  ((emit-write-line)   (emit-write-line/meth ilgen (car package)))
	  ((mark-label!)       (mark-label/meth ilgen (car package)))
	  (else
	   (error 'ilgen-msg! ": unknown msg " msg))
	  )))
    ilgen-msg!))

(define ilgen!
  (lambda (as package)
    (define sym->op lcg:sym->opcode)
    (define opc (car package))
    ;; (begin (display `(ilgen! as ,package)) (newline))
    (case opc
      ((beq beq.s bne.un.s br brtrue brtrue.s brfalse brfalse.s)
       (let ((label (cadr package)))
	 (ilgen-msg! as 'emit-label (sym->op opc) (car label) (cadr label))))
      ((call callvirt) ;; ( ILGenerator.emitCall is used for varargs methods )
       (let ((method-info (cadr package)))
	 (ilgen-msg! as 'emit-methodinfo (sym->op opc) method-info)))
      ((castclass isinst)
       (let ((type (cadr package)))
	 (ilgen-msg! as 'emit-type (sym->op opc) type)))
      ((ceq dup ldelem.ref pop ret stelem.ref sub 
	ldarg.0 ldarg.1 ldarg.2 ldarg.3) 
       (let ()
	 (ilgen-msg! as 'emit (sym->op opc))))
      ((label)
       (let ((label (cadr package)))
	 (ilgen-msg! as 'mark-label! (car label) (cadr label))))
      ((ldarg ldc.i4)
       (let ((int (clr/int->foreign (cadr package))))
	 (ilgen-msg! as 'emit-int32 (sym->op opc) int)))
      ((ldfld ldsfld stelem.ref stfld stsfld)
       (let ((field-info (cadr package)))
	 (ilgen-msg! as 'emit-fieldinfo (sym->op opc) field-info)))
      ((ldloc stloc)
       (let ((local-builder (cadr package)))
	 (ilgen-msg! as 'emit-localbuilder (sym->op opc) local-builder)))
      ((ldstr)
       (let ((string (clr/string->foreign (cadr package))))
	 (ilgen-msg! as 'emit-string (sym->op opc) string)))
      ((switch)
       (let* ((switch-labels (map car (vector->list (cadr package))))
	      (foreign-labels (vector->foreign-array
			       lcg:type:label (list->vector switch-labels))))
	 (ilgen-msg! as 'emit-labelarr (sym->op opc) foreign-labels)))
      (else 
       (error 'ilgen! 
	      "unknown msg:" (car package) 
	      "input:" package)))))

(define listify? #f)

(define (list-instruction name instruction)
  (if listify?
      (begin (display list-indentation)
             (display "        ")
             (display name)
             (display (make-string (max (- 12 (string-length name)) 1)
                                   #\space))
             (if (not (null? (cdr instruction)))
                 (begin (write (cadr instruction))
                        (do ((operands (cddr instruction)
                                       (cdr operands)))
                            ((null? operands))
                            (write-char #\,)
                            (write (car operands)))))
             (newline)
	     (flush-output-port))))

(define (list-label instruction)
  (if listify?
      (begin (display list-indentation)
             (write-char #\L)
             (write (cadr instruction))
             (newline))))

(define (list-lambda-start instruction)
  (list-instruction "lambda" (list $lambda '* (operand2 instruction)))
  (set! list-indentation (string-append list-indentation "|   ")))

(define (list-lambda-end)
  (set! list-indentation
        (substring list-indentation
                   0
                   (- (string-length list-indentation) 4))))

(define list-indentation "")

(define (lcg:cov as n) 'do-nothing)
(define (lcg:trace as n) (ilgen-msg! as 'emit-write-line
				     (clr/string->foreign 
				      (string-append 
				       "lcg:trace "
				       (number->string n)))))
;; (define lcg:reach? (lambda (n) (error 'pass5p2 ": reached" n)))
(define lcg:reach? 
  (let ((reached '()))
    (lambda (n) 
      (cond ((not (member n reached))
	     (set! reached (cons n reached))
	     (display "pass5p2: lcg:reach reached ")
	     (display n)
	     (newline))))))

;; PSEUDO INSTRUCTIONS

(define-instruction $.align
  (lambda (instruction as)
    (list-instruction ".align" instruction)))

(define-instruction $.cont
  (lambda (instruction as)
    (list-instruction ".cont" instruction)))

(define-instruction $.end
  (lambda (instruction as)
    (list-instruction ".end" instruction)
    
    ))

(define-instruction $.entry ;; Dispatches on jump-index
  (lambda (instruction as)
    (list-instruction ".entry" instruction)

    ;; note that in Asm/IL-LCG it is passed via param 0,
    ;; not param 1 like in Asm/IL.
    (let* ((dyn-meth (new-codevector-dynamic-method 
		      (string-append "someclosure " (number->string (operand2 instruction)))))
	   (ilgen (dynamic-method->il-generator dyn-meth)))
      (as-code! as (vector dyn-meth ilgen #f 0)) ;; XXX evil

      (let* ((switch-table (jump-label-map->alist (operand1 instruction)))
	     (switch-table (cons (list 0 'entry) switch-table))
	     (switch-count (length switch-table))
	     (switches (make-vector switch-count #f))
	     (jump-table ; : AList of (Int Nat Label)
	      (map (lambda (entry)
		     (let* ((lop-label (cadr entry))
			    (jump-index (car entry))
			    (lcg-label (fresh-lcg-label as lop-label)))
		       (or (not (vector-ref switches jump-index)) (error))
		       (vector-set! switches jump-index lcg-label)
		       (list (cadr entry)
			     (car entry)
			     lcg-label)))
		   switch-table))
	     (entry-label (vector-ref switches 0)))
	(as-code! as (vector dyn-meth ilgen jump-table 0))
	'(ilgen-msg! as 'emit-write-line 
		    (clr/string->foreign (string-append "Starting someclosure "
							(number->string (operand2 instruction)))))
	(case switch-count
	  ((1) (lcg:cov as 1.1) "jump index ignored" (unspecified))
	  ((2) (lcg:cov as 1.2)
	   (for-each 
	    (lambda (p) (ilgen! as p))
	    (list
	     (lcg:op:ldarg.0)
	     (lcg:op:brtrue (vector-ref switches 1)))))
	  ((3) (lcg:cov as 1.3)
	   (for-each
	    (lambda (p) (ilgen! as p))
	    (list
	     (lcg:op:ldarg.0)
	     (lcg:op:brfalse.s entry-label)
	     (lcg:op:ldarg.0)
	     (lcg:op:ldc.i4 1)
	     (lcg:op:beq (vector-ref switches 1))
	     (lcg:op:br  (vector-ref switches 2)))))
	  (else (lcg:cov as 1.4)
	   (for-each
	    (lambda (p) (ilgen! as p))
	    (list
	     (lcg:op:ldarg.0)
	     (lcg:op:switch switches)))))
	(ilgen! as `(label ,entry-label))
	))))
	  

(define-instruction $.label ;; XXX
  (lambda (instruction as)
    (list-label instruction)
    (let* ((label-num (operand1 instruction))
	   (asm-label (make-asm-label as label-num))
	   (label (intern-label as label-num))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      (set-cdr! asm-label jump-idx) ;; this replaces effect of emit-label!
      (lcg:cov as 2) ;; XXX
      (ilgen! as `(label ,lcg-label)))))

(define-instruction $.proc
  (lambda (instruction as)
    (list-instruction ".proc" instruction)
    (lcg:cov as 3)))

(define-instruction $.proc-doc
  (lambda (instruction as)
    (list-instruction ".proc-doc" instruction)
    (lcg:cov as 4)))

(define-instruction $.singlestep
  (lambda (instruction as)
    (error "pass5p2.sch: singlestep unhandled")))

;; INSTRUCTION IMPLEMENTATIONS

(define lcg:load-constant 
  (lambda (datum as)
    (define (gen/fld p)
      (ilgen! as (lcg:op:ldsfld p)))
    (define (gen! p)
      (ilgen! as p))
    (lcg:cov as 6)
    (cond ((immediate-fixnum? datum) 
	   (lcg:cov as 6.1)
	   (cond ((<= 0 datum 4)
		  (lcg:cov as 6.11)
		  (gen! (lcg:op:ldsfld (lcg:field:N->enn datum))))
		 (else
		  (lcg:cov as 6.12)
		  (for-each 
		   (lambda (x) (gen! x))
		   (list (lcg:op:ldsfld lcg:field:pool)
			 (lcg:op:ldc.i4 (- datum FIXNUM-POOL-MIN))
			 (lcg:op:ldelem.ref))))))
	  ((null? datum)
	   (lcg:cov as 6.2)
	   (gen/fld lcg:field:null))
	  ((equal? datum #t)            
	   (lcg:cov as 6.3)
	   (gen/fld lcg:field:true))
	  ((equal? datum #f)
	   (lcg:cov as 6.4)
	   (gen/fld lcg:field:false))
	  ((immediate-char? datum)   
	   (lcg:cov as 6.5)
	   (for-each
	    (lambda (x) (gen! x))
	    (list (lcg:op:ldsfld lcg:field:characters)
		  (lcg:op:ldc.i4 (char->integer datum))
		  (lcg:op:ldelem.ref))))
	  ((equal? datum (eof-object))  
	   (lcg:reach? 6.6)
	   (gen/fld lcg:field:eof))
	  ((equal? datum (unspecified)) 
	   (lcg:reach? 6.7)
	   (gen/fld lcg:field:unspecified))
	  ((equal? datum (undefined))   
	   (lcg:reach? 6.8)
	   (gen/fld lcg:field:undefined))
	  (else ;; non-immediate
	   (lcg:cov as 6.9)
	   (let ((offs (emit-datum as datum)))
	     (for-each 
	      (lambda (p) (ilgen! as p))
	      (list (lcg:op:call lcg:method:get_ProcRegister0)
		    (lcg:op:ldfld lcg:field:constants)
		    (lcg:op:ldc.i4 offs)
		    (lcg:op:ldelem.ref))))))))

(define-instruction $const
  (lambda (instruction as)
    (list-instruction "const" instruction)
    (lcg:cov as 7)
    (let ((datum (operand1 instruction)))
      (lcg:load-constant datum as)
      (ilgen! as (lcg:op:stsfld lcg:field:result)))))

(define (fresh-lcg-label as name) 
  (list (ilgen-msg! as 'define-label name) name))

(define-instruction $global
  (lambda (instruction as)
    (list-instruction "global" instruction)
    (let* ((global-sym (operand1 instruction))
	   (global-index (emit-global as global-sym))
	   (global-name (symbol->string global-sym)))
      (lcg:cov as 8)
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldc.i4 global-index)
	(lcg:op:ldstr global-name)
	(lcg:op:call lcg:method:global))))))

'(define-instruction $global
  (lambda (instruction as)
    (list-instruction "global" instruction)
    (let ((defined-label (fresh-lcg-label as 'global:defined))
          (global-index (emit-global as (operand1 instruction))))
      (lcg:reach? 9)
      (for-each 
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:call lcg:method:get_Register0)
	(lcg:op:ldfld lcg:field:constants)
	(lcg:op:ldc.i4 global-index)
	(lcg:op:ldelem.ref)
	(lcg:op:callvirt lcg:method:op_cell_ref)
	(lcg:op:dup)
	(lcg:op:ldsfld lcg:field:undefined)
	(lcg:op:bne.un.s defined-label)
	(lcg:op:pop)
	(lcg:op:ldc.i4 global-index)
	(lcg:op:call lcg:method:faultGlobal)
	(lcg:op:ret)))
      (ilgen! as `(label ,defined-label))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:stsfld lcg:field:result)
	)))))

(define-instruction $setglbl
  (lambda (instruction as)
    (list-instruction "setglbl" instruction)
    (let ((global-index (emit-global as (operand1 instruction))))
      (lcg:cov as 10)
      (for-each 
       (lambda (p) (ilgen! as p))
       (list 
	(lcg:op:call lcg:method:get_ProcRegister0)
	(lcg:op:ldfld lcg:field:constants)
	(lcg:op:ldc.i4 global-index)
	(lcg:op:ldelem.ref)
	(lcg:op:castclass lcg:type:schemepair)
	(lcg:op:ldsfld lcg:field:result)
	(lcg:op:stfld lcg:field:first)
	)))))
  
(define-instruction $lambda
  (lambda (instruction as)
    (let* ((const-offset #f)
	   (code-offset  #f)
	   (old-source (operand1 instruction))
	   (source*jlmap (establish-jump-points old-source))
	   (new-source (car source*jlmap))
	   (jump-table (cadr source*jlmap)))
      (lcg:cov as 11)
      (list-lambda-start instruction)
      (let ((doc (operand3 instruction)) ; documentation
	    (user (as-user as)))
	(assemble-nested-lambda
	 as
	 (cons (list $.entry jump-table (operand2 instruction)) ;; FSK: using operand2 as way to guess which closure is being invoked when error occurs...
	       new-source)
	 doc
	 (lambda (nested-as segment)
	   ;; (display `(invoke nested ,nested-as ,segment)) (newline)
	   ;; segment offsets must be (CodeVector . Constants)
	   (set-constant! as code-offset (car segment))
	   (set-constant! as const-offset (cdr segment)))
	 user)
	)
      (list-lambda-end)

      ;; allocate two fresh offsets here; they will be replaced when
      ;; closure passed to assemble-nested-lambda above is invoked.
      (set! code-offset (emit-codevector as 0))
      (set! const-offset (emit-constantvector as 0))
      
      (for-each 
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:call lcg:method:get_ProcRegister0)
	(lcg:op:ldfld lcg:field:constants) ;; XXX overload, just pass code idx?
	(lcg:op:ldc.i4 code-offset)
	(lcg:op:ldelem.ref)
	(lcg:op:castclass lcg:type:codevector)
	(lcg:op:ldc.i4 const-offset)
	(lcg:op:ldc.i4 (operand2 instruction))
	(lcg:op:call lcg:method:lambda)
	)))))

;; the original CommonLarceny dev team seems to think that lexes is
;; unused, but Felix found cases where it was used when he developed
;; the IAssassin backend...
;; Anyway they *did* implement it in the runtime...

(define-instruction $lexes
  (lambda (instruction as)
    (list-instruction "lexes" instruction)
    (lcg:cov as 12)
    (for-each
     (lambda (p) (ilgen! as p))
     (list
      (lcg:op:ldc.i4 (operand1 instruction))
      (lcg:op:call lcg:method:lexes)))))

(define-instruction $args=
  (lambda (instruction as)
    (list-instruction "args=" instruction)
    (lcg:cov as 13)
    (ilgen! as (lcg:op:ldsfld lcg:field:result))
    (let ((required (operand1 instruction)))
      (cond ((< required NAMED-FIXNUM-LIMIT)
	     (lcg:cov as 13.1)
	     (ilgen! as (lcg:op:ldsfld (lcg:field:N->enn required))))
            (else
	     (lcg:cov as 13.2)
	     (for-each 
	      (lambda (p) (ilgen! as p))
	      (list
	       ;; unchecked: we trust call convention
	       (lcg:op:castclass lcg:type:fixnum)
	       (lcg:op:ldfld lcg:field:value)
	       (lcg:op:ldc.i4 required)
	       ))))
      (let ((okay-label (fresh-lcg-label as 'args=:okay)))
	(for-each 
	 (lambda (p) (ilgen! as p))
	 (list 
	  (lcg:op:beq.s okay-label)
	  (lcg:op:ldc.i4 required)
	  (lcg:op:call lcg:method:faultArgCount)
	  (lcg:op:ret)))
	(ilgen! as `(label ,okay-label))
	))))

(define-instruction $args>=
  (lambda (instruction as)
    (list-instruction "args>=" instruction)
    (lcg:cov as 14)
    (ilgen! as (lcg:op:ldc.i4 (operand1 instruction)))
    (ilgen! as (lcg:op:call lcg:method:argsge))))

(define (lcg:generate-timer-check as 
				  timer-nonfault-label-object
				  post-fault-jump-index)
  (for-each 
   (lambda (p) (ilgen! as p))
   (list
	  (lcg:op:ldsfld lcg:field:timer)
	  (lcg:op:ldc.i4 1)
	  (lcg:op:sub)
	  (lcg:op:dup)
	  (lcg:op:stsfld lcg:field:timer)
	  (lcg:op:brtrue timer-nonfault-label-object)
	  (lcg:op:ldc.i4 post-fault-jump-index)
	  (lcg:op:call lcg:method:faultTimer)
	  (lcg:op:ret)
	  )))

(define-instruction $invoke
  (lambda (instruction as)
    (list-instruction "invoke" instruction)
    (lcg:cov as 15)
    (let ((procedure-local (ilgen-msg! as 'declare-local lcg:type:procedure))
	  (success-label (fresh-lcg-label as 'invoke:isproc-success)))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldsfld lcg:field:result)
	(lcg:op:isinst lcg:type:procedure)
	(lcg:op:dup)
	(lcg:op:brtrue.s success-label)
	(lcg:op:pop)
	(lcg:op:ldc.i4 (operand1 instruction))
	(lcg:op:call lcg:method:faultInvokeNonProc)
	(lcg:op:ret)))
      (ilgen! as `(label ,success-label))
      (for-each
       (lambda (p) (ilgen! as p))
       (list 
	(lcg:op:stloc procedure-local)
	;; Stack is empty
	(lcg:op:call lcg:method:get_Register0)
	(lcg:op:stsfld lcg:field:second)))
      (let ((arg-count (operand1 instruction))
	    (label-okay (fresh-lcg-label as 'invoke:timer-success)))
	(for-each 
	 (lambda (p) (ilgen! as p))
	 (cond ((<= 0 arg-count 4)
		(lcg:cov as 15.1)
		(list (lcg:op:ldsfld (lcg:field:N->enn arg-count))))
	       ((immediate-fixnum? arg-count)
		(lcg:cov as 15.2)
		(list 
		 (lcg:op:ldsfld lcg:field:pool)
		 (lcg:op:ldc.i4 (- arg-count FIXNUM-POOL-MIN))
		 (lcg:op:ldelem.ref)))
	       (else 
		(lcg:reach? 15.3)
		;; can this really happen?  If so, is it cheaper to
		;; emit and load the fixnum from the constant vector?
		(list
		 (lcg:op:ldc.i4 arg-count)
		 (lcg:op:call lcg:method:makeFixnum)
		 ))))
	(for-each
	 (lambda (p) (ilgen! as p))
	 (list
	  (lcg:op:stsfld lcg:field:result)
	  (lcg:op:ldloc procedure-local)
	  (lcg:op:call lcg:method:set_ProcRegister0)))
	(lcg:generate-timer-check as label-okay FIRST-JUMP-INDEX)
	(ilgen! as `(label ,label-okay))
	(for-each
	 (lambda (p) (ilgen! as p))
	 (list 
	  (lcg:op:ldloc procedure-local)
	  (lcg:op:ldfld lcg:field:entrypoint)
	  (lcg:op:ldc.i4 FIRST-JUMP-INDEX)
	  (lcg:op:call lcg:method:call)
	  (lcg:op:ret)
	  ))))))

(define-instruction $apply
  (lambda (instruction as)
    (list-instruction "apply" instruction)
    (let ((procedure-local (ilgen-msg! as 'declare-local lcg:type:procedure))
	  (success-label (fresh-lcg-label as 'apply:isproc-success))
	  (time-okay-label (fresh-lcg-label as 'apply:timer-success)))
      (lcg:reach? 16)
      (for-each 
       (lambda (p) (ilgen! as p))
       (list 
	(lcg:op:ldsfld lcg:field:result)
	(lcg:op:isinst lcg:type:procedure)
	(lcg:op:dup)
	(lcg:op:brtrue.s success-label)
	(lcg:op:pop)
	(lcg:op:ldc.i4 (operand1 instruction))
	(lcg:op:ldc.i4 (operand2 instruction))
	(lcg:op:call lcg:method:faultApplyNonProc)
	(lcg:op:ret)))
      (ilgen! as `(label ,success-label))
      (for-each
       (lambda (p) (ilgen! as p))
       (list 
	(lcg:op:stloc procedure-local)
	(lcg:op:call lcg:method:get_Register0)
	(lcg:op:stsfld lcg:field:second)
	(lcg:op:ldloc procedure-local)
	(lcg:op:call lcg:method:set_ProcRegister0)
	;; Destroys registers 1 - N
	(lcg:op:ldc.i4 (operand1 instruction))
	(lcg:op:ldc.i4 (operand2 instruction))
	(lcg:op:call lcg:method:applySetup)
	;; records N in RESULT
	(lcg:op:call lcg:method:makeFixnum)
	(lcg:op:stsfld lcg:field:result)))
      (lcg:generate-timer-check as time-okay-label FIRST-JUMP-INDEX)
      (ilgen! as `(label ,time-okay-label))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldloc procedure-local)
	(lcg:op:ldfld lcg:field:entrypoint)
	(lcg:op:ldc.i4 FIRST-JUMP-INDEX)
	(lcg:op:call lcg:method:call)
	(lcg:op:ret)
	)))))

  ;; Stack

(define-instruction $save
  (lambda (instruction as)
    (define (default)
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldc.i4 (operand1 instruction))
	(lcg:op:call lcg:method:save))))
    (list-instruction "save" instruction)
    (lcg:cov as 17)
    (let ((n (operand1 instruction)))
      (cond ((and (codegen-option 'special-save-instructions)
		  (< n SPECIAL-INSTRUCTION-LIMIT))
	     (lcg:cov as 17.1)
	     (ilgen! as (lcg:op:call (lcg:method:offset->save n))))
	    (else
	     (lcg:cov as 17.2)
	     (default))))))

(define-instruction $save/storem-uniform
  (lambda (instruction as)
    (list-instruction "save/storem-uniform" instruction)
    (lcg:cov as 18)
    (for-each
     (lambda (p) (ilgen! as p))
     (list
      (lcg:op:ldc.i4 (operand1 instruction))
      (lcg:op:call lcg:method:save_storem_uniform)))))

(define-instruction $loadm-uniform
  (lambda (instruction as)
    (list-instruction "loadm-uniform" instruction)
    (lcg:cov as 19)
    (for-each
     (lambda (p) (ilgen! as p))
     (list
      (lcg:op:ldc.i4 (operand1 instruction))
      (lcg:op:call lcg:method:loadm_uniform)))))

;; Not used

(define-instruction $restore
  (lambda (instruction as)
    (list-instruction "restore" instruction)
    (lcg:reach? 20)
    (for-each
     (lambda (p) (ilgen! as p))
     (list
      (lcg:op:ldc.i4 (operand1 instruction))
      (lcg:op:call lcg:method:restore)
      ))))

(define-instruction $pop
  (lambda (instruction as)
    (list-instruction "pop" instruction)
    (lcg:cov as 21)
    (let ((n (operand1 instruction)))
      (cond 
       ((and (codegen-option 'special-pop-instructions)
	     (< n SPECIAL-INSTRUCTION-LIMIT))
	(lcg:cov as 21.1)
	(ilgen! as (lcg:op:call (lcg:method:offset->pop n))))
       (else
	(lcg:cov as 21.2)
	(for-each
	 (lambda (p) (ilgen! as p))
	 (list (lcg:op:ldc.i4 n)
	       (lcg:op:call lcg:method:pop))))))))

(define-instruction $popstk
  (lambda (instruction as)
    (error "POPSTK is not implemented by this assembler.")))

(define-instruction $stack
  (lambda (instruction as)
    (list-instruction "stack" instruction)
    (lcg:cov as 23)
    (ilgen! as (lcg:op:ldsfld lcg:field:cont))
    (for-each 
     (lambda (p) (ilgen! as p))
     (let ((slot (operand1 instruction)))
       (cond 
	((< slot CONTINUATION-FRAME-SLOTS)
	 (lcg:cov as 23.1)
	 (list
	  (lcg:op:ldfld (lcg:field:offset->slot slot))))
	(else
	 (lcg:cov as 23.2)
	 (list
	  (lcg:op:ldfld lcg:field:overflowSlots)
	  (lcg:op:ldc.i4 (- slot CONTINUATION-FRAME-SLOTS))
	  (lcg:op:ldelem.ref))))))
    (ilgen! as 
	    (lcg:op:stsfld lcg:field:result))))

(define-instruction $setstk
  (lambda (instruction as)
    (list-instruction "setstk" instruction)
    (lcg:cov as 24)
    (for-each
     (lambda (p) (ilgen! as p))
     (list 
      (lcg:op:ldc.i4 (operand1 instruction))
      (lcg:op:call lcg:method:setstk)))))

(define-instruction $load
  (lambda (instruction as)
    (list-instruction "load" instruction)
    (let ((reg  (operand1 instruction))
	  (slot (operand2 instruction)))
      (lcg:cov as 25)
      (ilgen! as (lcg:op:ldsfld lcg:field:cont))
      (for-each
       (lambda (p) (ilgen! as p))
       (cond 
	((< slot CONTINUATION-FRAME-SLOTS)
	 (lcg:cov as 25.1)
	 (list
	  (lcg:op:ldfld (lcg:field:offset->slot slot))))
	(else
	 (lcg:cov as 25.2)
	 (list
	  (lcg:op:ldfld lcg:field:overflowSlots)
	  (lcg:op:ldc.i4 (- slot CONTINUATION-FRAME-SLOTS))
	  (lcg:op:ldelem.ref)))))
;      (cond ((and (= reg 0) (not (= slot 0)))
;	     (lcg:cov as 25.3)
;	     (ilgen! as (lcg:op:castclass lcg:type:procedure))))
      (ilgen! as (lcg:op:call (lcg:method:offset->set_register reg)))
      )))

(define-instruction $store
  (lambda (instruction as)
    (list-instruction "store" instruction)
    (let ((reg (operand1 instruction))
	  (slot (operand2 instruction)))
      (lcg:cov as 26)
      (for-each
       (lambda (p) (ilgen! as p))
       (cond 
	((and (= reg 0) (= slot 0))
	 (lcg:cov as 26.0)
	 (list
	  (lcg:op:ldsfld lcg:field:cont)
	  (lcg:op:call lcg:method:get_ProcRegister0)
	  (lcg:op:stfld (lcg:field:offset->slot slot))))
	((and (not (= reg 0)) (= slot 0))
	 (lcg:cov as 26.1)
	 (list
	  (lcg:op:ldsfld lcg:field:cont)
	  (lcg:op:call (lcg:method:offset->get_register reg))
	  (lcg:op:castclass lcg:type:procedure)
	  (lcg:op:stfld (lcg:field:offset->slot slot))))
	((< slot CONTINUATION-FRAME-SLOTS)
	 (lcg:cov as 26.2)
	 (list
	  (lcg:op:ldsfld lcg:field:cont)
	  (lcg:op:call (lcg:method:offset->get_register reg))
	  (lcg:op:stfld (lcg:field:offset->slot slot))))
	(else
	 (lcg:cov as 26.3)
	 (list
	  (lcg:op:ldsfld lcg:field:cont)
	  (lcg:op:ldfld lcg:field:overflowSlots)
	  (lcg:op:ldc.i4 (- slot CONTINUATION-FRAME-SLOTS))
	  (lcg:op:call (lcg:method:offset->get_register reg))
	  (lcg:op:stelem.ref))
	 ))))))

(define-instruction $return
  (lambda (instruction as)
    (list-instruction "return" instruction)
    (lcg:cov as 27)
    (for-each 
     (lambda (p) (ilgen! as p))
     (list (lcg:op:call lcg:method:rtn)
	   (lcg:op:ret)))))

'(define-instruction $return
  (lambda (instruction as)
    (list-instruction "return" instruction)
    (lcg:reach? 28)
    (let ((contframe (ilgen-msg! as 'declare-local 
				 (clr/%get-type 
				  "Scheme.RT.ContinuationFrame"))))
       (for-each
	(lambda (p) (ilgen! as p))
	(list
	 (lcg:op:ldsfld lcg:field:cont)
	 (lcg:op:stloc contframe)
	 (lcg:op:ldloc contframe)
	 (lcg:op:ldfld (lcg:field:offset->slot 0))
	 (lcg:op:castclass lcg:type:procedure)
	 (lcg:op:dup)
	 (lcg:op:call lcg:method:set_ProcRegister0)
	 (lcg:op:ldfld lcg:field:entrypoint)
	 (lcg:op:ldloc contframe)
	 (lcg:op:ldfld lcg:field:returnIndex)
	 (lcg:op:call lcg:method:call)
	 (lcg:op:ret)
	 )))))

(define-instruction $setrtn
  (lambda (instruction as)
    (list-instruction "setrtn" instruction)
    (lcg:cov as 29)
    (let* ((label-num (operand1 instruction))
	   (label (intern-label as label-num))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      (for-each
       (lambda (p) (ilgen! as p))
       (list (lcg:op:call lcg:method:get_ProcRegister0)
	     (lcg:op:ldfld lcg:field:entrypoint)
	     (lcg:op:ldc.i4 jump-idx)
	     (lcg:op:call lcg:method:setrtn))))))

'(define-instruction $setrtn
  (lambda (instruction as)
    (list-instruction "setrtn" instruction)
    (lcg:reach? 30)
    (let* ((label-num (operand1 instruction))
	   (label (intern-label as label-num))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      (for-each 
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldsfld lcg:field:cont)
	(lcg:op:ldc.i4 jump-idx)
	(lcg:op:stfld lcg:field:returnIndex))))))

;; Lexical

(define-instruction $lexical
  (lambda (instruction as)
    (list-instruction "lexical" instruction)
    (lcg:cov as 31)
    (let ((up (operand1 instruction))
	  (idx (operand2 instruction)))
      (for-each 
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:call lcg:method:get_ProcRegister0)))
      (for-each
       (lambda (p) (lcg:cov as 31.1) (ilgen! as p))
       (vector->list (make-vector up (lcg:op:ldfld lcg:field:parent))))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldfld lcg:field:rib)
	(lcg:op:ldc.i4 idx)
	(lcg:op:ldelem.ref)
	(lcg:op:stsfld lcg:field:result)
	)))))

(define-instruction $setlex
  (lambda (instruction as)
    (list-instruction "setlex" instruction)
    (lcg:reach? 32)
    (let ((up (operand1 instruction))
	  (idx (operand2 instruction)))
      (ilgen! as (lcg:op:call lcg:method:get_Register0))
      (for-each
       (lambda (p) (lcg:reach? 32.1) (ilgen! as p))
       (vector->list (make-vector up (lcg:op:ldfld lcg:field:parent))))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldfld lcg:field:rib)
	(lcg:op:ldc.i4 idx)
	(lcg:op:ldsfld lcg:field:result)
	(lcg:op:stelem.ref)
	)))))

;; Registers

(define-instruction $reg
  (lambda (instruction as)
    (list-instruction "reg" instruction)
    (lcg:cov as 33)
    (for-each
     (lambda (p) (ilgen! as p))
     (list
      (lcg:op:call (lcg:method:offset->get_register (operand1 instruction)))
      (lcg:op:stsfld lcg:field:result)))))

(define-instruction $setreg
  (lambda (instruction as)
    (list-instruction "setreg" instruction)
    (lcg:cov as 34)
    (let ((reg (operand1 instruction)))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldsfld lcg:field:result)
	(lcg:op:call (lcg:method:offset->set_register reg)))))))
  
(define-instruction $movereg
  (lambda (instruction as)
    (list-instruction "movereg" instruction)
    (lcg:cov as 35)
    (for-each
     (lambda (p) (ilgen! as p))
     (list
      (lcg:op:call (lcg:method:offset->get_register (operand1 instruction)))
      (lcg:op:call (lcg:method:offset->set_register (operand2 instruction)))
      ))))

(define-instruction $nop
  (lambda (instruction as)
    (list-instruction "nop" instruction)
    (lcg:reach? 36)
    ))

;; Control Flow

(define-instruction $jump
  (lambda (instruction as)
    (list-instruction "jump" instruction)
    (lcg:cov as 37)
    (let* ((time-okay-label (fresh-lcg-label as 'jump:timer-success))
	   (up (operand1 instruction))
	   (label (operand2 instruction))
	   (offset (let loop ((as* as))
		     (cond ((not as*) 
			    ;; Didn't find our label by following chain
			    ;; of structures; must be in current one
			    #f)
			   ((find-label as* label) => cdr)
			   (else (loop (as-parent as*)))))))
      ;; move reg0 up by <up> levels.
      (for-each 
       (lambda (p) (ilgen! as p))
       (list 
	(lcg:op:call lcg:method:get_ProcRegister0)))
      (for-each
       (lambda (p) (lcg:cov as 37.1) (ilgen! as p))
       (vector->list (make-vector up (lcg:op:ldfld lcg:field:parent))))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:castclass lcg:type:procedure)
	(lcg:op:call lcg:method:set_ProcRegister0)))

      ;; And call.
      ;; XXX FIXME: no fuel used on jump in either case!
      (cond
       (offset 
	(lcg:cov as 37.2)
	(lcg:generate-timer-check as time-okay-label offset)
	(for-each
	 (lambda (p) (ilgen! as p))
	 (list
	  `(label ,time-okay-label)
	  ;; might use dup above to remove load here
	  (lcg:op:call lcg:method:get_ProcRegister0)
	  (lcg:op:ldfld lcg:field:entrypoint)
	  (lcg:op:ldc.i4 offset)
	  (lcg:op:call lcg:method:call)
	  (lcg:op:ret))))
	(else
	 (lcg:cov as 37.3)
	 (let* ((label (intern-label as label))
		(jump-idx (car label))
		(lcg-label (cdr label)))
	   (lcg:generate-timer-check as lcg-label jump-idx)))
	))))
  
(define-instruction $skip
  (lambda (instruction as)
    (list-instruction "skip" instruction)
    (lcg:cov as 38)
    (let* ((label (intern-label as (operand1 instruction)))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      (ilgen! as (lcg:op:br lcg-label)))))

(define-instruction $branch
  (lambda (instruction as)
    (list-instruction "branch" instruction)
    (lcg:cov as 39)
    (let* ((mal-label-num (operand1 instruction))
	   (label (intern-label as mal-label-num))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      (cond ((assq mal-label-num (as-labels as))
	     (lcg:cov as 39.1)
	     (lcg:generate-timer-check as lcg-label jump-idx))
	    (else
	     (lcg:cov as 39.2)
	     (ilgen! as (lcg:op:br lcg-label)))))))

(define-instruction $branchf
  (lambda (instruction as)
    (list-instruction "branchf" instruction)
    (lcg:cov as 40)
    (let* ((no-branch-label (fresh-lcg-label as 'branchf:no-branch))
	   (mal-label-num (operand1 instruction))
	   (label (intern-label as mal-label-num))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      (for-each
       (lambda (p) (ilgen! as p))
       (list (lcg:op:ldsfld lcg:field:result)
	     (lcg:op:ldsfld lcg:field:false)
	     (lcg:op:bne.un.s no-branch-label)))
      (cond 
       ((assq mal-label-num (as-labels as))
	(lcg:reach? 40.1)
	(lcg:generate-timer-check as lcg-label jump-idx))
       (else
	(lcg:cov as 40.2)
	(for-each
	 (lambda (p) (ilgen! as p))
	 (list (lcg:op:br lcg-label)))))
      (ilgen! as `(label ,no-branch-label))
      )))

(define-instruction $check
  (lambda (instruction as)
    (list-instruction "check" instruction)
    (lcg:cov as 41)
    (let* ((label (intern-label as (operand4 instruction)))
	  (lcg-label (cdr label)))
      (for-each 
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldsfld lcg:field:result)
	(lcg:op:ldsfld lcg:field:false)
	(lcg:op:beq lcg-label))))))

(define-instruction $trap
  (lambda (instruction as)
    (list-instruction "trap" instruction)
    (lcg:cov as 42)
    (let ((w (operand1 instruction))
	  (x (operand2 instruction))
	  (y (operand3 instruction))
	  (excode (operand4 instruction)))
      (cond ((not (zero? w))
	     (lcg:cov as 42.1)
	     (for-each
	      (lambda (p) (ilgen! as p))
	      (list
	       (lcg:op:call (lcg:method:offset->get_register w))
	       (lcg:op:stsfld lcg:field:result)
	       ))))
      (cond ((not (zero? x))
	     (lcg:cov as 42.2)
	     (for-each
	      (lambda (p) (ilgen! as p))
	      (list
	       (lcg:op:call (lcg:method:offset->get_register x))
	       (lcg:op:stsfld lcg:field:second)
	       ))))
      (cond ((not (zero? y))
	     (lcg:trace as 42.3)
	     (for-each
	      (lambda (p) (ilgen! as p))
	      (list
	       (lcg:op:call (lcg:method:offset->get_register y))
	       (lcg:op:stsfld lcg:field:third)
	       ))))
      (for-each
       (lambda (p) (ilgen! as p))
       (list
	(lcg:op:ldc.i4 excode)
	(lcg:op:call lcg:method:fault)
	(lcg:op:ret)
	)))))

(define-instruction $const/setreg
  (lambda (instruction as)
    (list-instruction "const/setreg" instruction)
    (lcg:cov as 43)
    (let ((const (operand1 instruction))
	  (reg (operand2 instruction)))
      (lcg:load-constant const as)
      (ilgen! as (lcg:op:call (lcg:method:offset->set_register reg)))
      )))

(define-instruction $op1 ; (opX 1 #f #f)
  (lambda (instruction as)
    (list-instruction "op1" instruction)
    (lcg:cov as 44)
    (let* ((opcode (operand1 instruction)))
      (cond 
       ((op1-implicit-continuation? opcode)
	(lcg:cov as 44.1)
	(let* ((numeric (operand2 instruction))
	       (label   (intern-label as numeric))
	       (jump-idx (car label))
	       (lcg-label (cdr label)))
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:ldc.i4 jump-idx)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 (lcg:op:ldsfld lcg:field:result)
		 (lcg:op:callvirt
		  (lcg:op-instance-method lcg:type:void 
					  opcode
					  '()))
		 (lcg:op:ldc.i4 -1)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 `(label ,lcg-label)))))
       (else
	(lcg:cov as 44.2)
	(let ()
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:ldsfld lcg:field:result)
		 (lcg:op:callvirt
		  (lcg:op-instance-method lcg:type:schemeobject 
					  opcode
					  '()))
		 (lcg:op:stsfld lcg:field:result)))))))))
  
(define-instruction $op2 ; (opX 2 #f #f)
  (lambda (instruction as)
    (list-instruction "op2" instruction)
    (lcg:cov as 45)
    (let* ((opcode (operand1 instruction)))
      (cond 
       ((op2-implicit-continuation? opcode)
	(lcg:cov as 45.1)
	(let* ((numeric (operand3 instruction))
	       (label   (intern-label as numeric))
	       (jump-idx (car label))
	       (lcg-label (cdr label)))
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:ldc.i4 jump-idx)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 (lcg:op:ldsfld lcg:field:result)
		 (lcg:op:call (lcg:method:offset->get_register (operand2 instruction)))
		 (lcg:op:callvirt 
		  (lcg:op-instance-method lcg:type:void 
					  opcode
					  (list lcg:type:schemeobject)))
		 (lcg:op:ldc.i4 -1)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 `(label ,lcg-label)))))
       (else
	(lcg:cov as 45.2)
	(let ()
	  (for-each 
	   (lambda (p) (ilgen! as p)) 
	   (list (lcg:op:ldsfld lcg:field:result)
		 (lcg:op:call (lcg:method:offset->get_register (operand2 instruction)))
		 (lcg:op:callvirt 
		  (lcg:op-instance-method lcg:type:schemeobject
					  opcode
					  (list lcg:type:schemeobject)))
		 (lcg:op:stsfld lcg:field:result)))))))))

(define-instruction $op2imm ; (opX 2 #t #f)
  (lambda (instruction as)
    (list-instruction "op2imm" instruction)
    (lcg:cov as 46)
    (let* ((opcode (operand1 instruction)))
      (cond 
       ((op2-implicit-continuation? opcode)
	(lcg:cov as 46.1)
	(let* ((numeric (operand3 instruction))
	       (label   (intern-label as numeric))
	       (jump-idx (car label))
	       (lcg-label (cdr label))
	       (datum (operand2 instruction)))
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:ldc.i4 jump-idx)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 (lcg:op:ldsfld lcg:field:result)))
	  (lcg:load-constant datum as)
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:callvirt 
		  (lcg:op-instance-method lcg:type:void
					  opcode
					  (list lcg:type:schemeobject)))
		 (lcg:op:ldc.i4 -1)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 `(label ,lcg-label)))))
       (else
	(lcg:cov as 46.2)
	(let ((datum (operand2 instruction)))
	  (ilgen! as (lcg:op:ldsfld lcg:field:result))
	  (lcg:load-constant datum as)
	  (for-each 
	   (lambda (p) (ilgen! as p))
	   (list
	    (lcg:op:callvirt 
	     (lcg:op-instance-method lcg:type:schemeobject
				     opcode
				     (list lcg:type:schemeobject)))
	    (lcg:op:stsfld lcg:field:result)))))))))
  
(define-instruction $op3 ; (opX 3 #f #f)
  (lambda (instruction as)
    (list-instruction "op3" instruction)
    (lcg:cov as 47)
    (let* ((opcode (operand1 instruction)))
      (cond 
       ((op3-implicit-continuation? opcode)
	(lcg:reach? 47.1)
	(let* ((numeric (operand4 instruction))
	       (label (intern-label as numeric))
	       (jump-idx (car label))
	       (lcg-label (cdr label)))
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:ldc.i4 jump-idx)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 (lcg:op:ldsfld lcg:field:result)
		 (lcg:op:call (lcg:method:offset->get_register (operand2 instruction)))
		 (lcg:op:call (lcg:method:offset->get_register (operand3 instruction)))
		 (lcg:op:callvirt 
		  (lcg:op-instance-method lcg:type:void
					  opcode
					  (list lcg:type:schemeobject
						lcg:type:schemeobject)))
		 (lcg:op:ldc.i4 -1)
		 (lcg:op:stsfld lcg:field:implicit-continuation)
		 `(label ,lcg-label)))))
       (else
	(lcg:cov as 47.2)
	(let ()
	  (for-each
	   (lambda (p) (ilgen! as p))
	   (list (lcg:op:ldsfld lcg:field:result)
		 (lcg:op:call (lcg:method:offset->get_register (operand2 instruction)))
		 (lcg:op:call (lcg:method:offset->get_register (operand3 instruction)))
		 (lcg:op:callvirt
		  (lcg:op-instance-method lcg:type:void
					  opcode
					  (list lcg:type:schemeobject
						lcg:type:schemeobject)))
		 (lcg:op:stsfld lcg:field:result)))))))))

(define-instruction $reg/op1/setreg ; (opX 1 #f #t)
  (lambda (instruction as)
    (list-instruction "reg/op1/setreg" instruction)
    (lcg:cov as 48)
    (let ((primop (operand1 instruction))
	  (rs (caddr instruction))    ;; XXX use appropos observers
	  (rd (cadddr instruction)))  ;; XXX

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:reach? 48.11)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:cov as 48.12)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op1/setreg ": unknown register" rs))))

      (define (setreg rd)
	(cond ((eq? rd 'result)
	       (lcg:cov as 48.21)
	       (lcg:op:stsfld lcg:field:result))
	      ((number? rd)
	       (lcg:cov as 48.22)
	       (lcg:op:call (lcg:method:offset->set_register rd)))
	      (else (error 'reg/op1/setreg ": unknown register" rd))))

      (define (match-constant rs const-field rd)
	(list (getreg rs)
	      (lcg:op:ldsfld const-field)
	      (lcg:op:ceq)
	      (lcg:op:call lcg:method:makeBoolean)
	      (setreg rd)))

      (define (gen-constant const-field rd)
	(list (lcg:op:ldsfld const-field)
	      (setreg rd)))

      (define (op1-method rs method rd)
	(list (getreg rs)
	      (lcg:op:callvirt method)
	      (setreg rd)))
      
      (for-each 
       (lambda (p) (ilgen! as p))
       (case primop
	 ((creg) (lcg:reach? 48.91)
	  (list (lcg:op:call lcg:method:getCC)
		(setreg rd)))
	 ((creg-set!) (lcg:reach? 48.92)
	  (list (getreg rs)
		(lcg:op:call lcg:method:setCC)
		(setreg rd)))
	 ((break)  (lcg:reach? 48.93)
	  (list (lcg:op:ldc.i4 $ex.breakpoint)
		(lcg:op:call lcg:method:fault)
		(lcg:op:ret)))
	 ((gc-counter)  (lcg:reach? 48.94)
	  (list (lcg:op:ldsfld lcg:field:zero)
		(setreg rd)))

	 ((not) (lcg:reach? 48.951)
          (match-constant rs lcg:field:false rd))
	 ((null?)  (lcg:reach? 48.952)
	  (match-constant rs lcg:field:null rd))
	 ((unspecified?) (lcg:reach? 48.953)
	  (match-constant rs lcg:field:unspecified rd))
	 ((eof-object?) (lcg:reach? 48.954)
	  (match-constant rs lcg:field:eof rd))
	 ((undefined?)   (lcg:reach? 48.955)
	  (match-constant rs lcg:field:undefined rd))
	 ((fxzero?) (lcg:reach? 48.956)
	  (match-constant rs lcg:field:zero rd))

	 ((unspecified) (lcg:reach? 48.961)
	  (gen-constant lcg:field:unspecified rd))
	 ((undefined)    (lcg:reach? 48.962)
	  (gen-constant lcg:field:undefined rd))
	 ((eof-object)   (lcg:reach? 48.963)
	  (gen-constant lcg:field:eof rd))

	 ((make-cell) (lcg:reach? 48.97)
	  (list (getreg rs)
		(lcg:op:ldsfld lcg:field:false)
		(lcg:op:call lcg:method:makePair)
		(setreg rd)))
	 ((car:pair) (lcg:cov as 48.981)
	  (list (getreg rs)
		(lcg:op:castclass lcg:type:schemepair)
		(lcg:op:ldfld lcg:field:first)
		(setreg rd)))
	 ((cdr:pair) (lcg:cov as 48.982)
	  (list (getreg rs)
		(lcg:op:castclass lcg:type:schemepair)
		(lcg:op:ldfld lcg:field:rest)
		(setreg rd)))

	 ((char->integer)     (lcg:cov as 48.991)
	  (op1-method rs lcg:method:op_char2integer rd))
	 ((vector-length:vec)  (lcg:cov as 48.992)
	  (op1-method rs lcg:method:op_vector_length_vec rd))
	 ((char?)              (lcg:cov as 48.993)
	  (op1-method rs lcg:method:op_charp rd))
	 ((cell-ref)           (lcg:cov as 48.994)
	  (op1-method rs lcg:method:op_cell_ref rd))

	 (else (error '$reg/op1/setreg ": unknown primop" primop)))))))

(define-instruction $reg/op2/setreg ; (opX 2 #f #t)
  (lambda (instruction as)
    (list-instruction "reg/op2/setreg" instruction)
    (lcg:cov as 49)
    (let ((primop (operand1 instruction))
	  (rs1 (caddr instruction))       ;; XXX use apropos observers
	  (rd  (cadddr instruction))
	  (rs2  (caddr (cddr instruction))))

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:reach? 49.11)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:cov as 49.12)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op2/setreg ": unknown register" rs))))

      (define (setreg rd)
	(cond ((eq? rd 'result)
	       (lcg:cov as 49.21)
	       (lcg:op:stsfld lcg:field:result))
	      ((number? rd)
	       (lcg:cov as 49.22)
	       (lcg:op:call (lcg:method:offset->set_register rd)))
	      (else (error 'reg/op2/setreg ": unknown register" rd))))

      (case primop
	((eq?)
	 (ilgen! as (getreg rs1))
	 (ilgen! as (getreg rs2))
	 (ilgen! as (lcg:op:ceq))
	 (ilgen! as (lcg:op:call lcg:method:makeBoolean))
	 (ilgen! as (setreg rd)))
	((cons) 
	 (ilgen! as (getreg rs1))
	 (ilgen! as (getreg rs2))
	 (ilgen! as (lcg:op:call lcg:method:makePair))
	 (ilgen! as (setreg rd)))
	(else (error '$reg/op2/setreg ": unknown primop" primop))))))
  
(define-instruction $reg/op2imm/setreg ; (opX 2 #t #t)
  (lambda (instruction as)
    (list-instruction "reg/op2imm/setreg" instruction)
    (lcg:cov as 50)
    (let ((primop (operand1 instruction))
	  (rs     (operand2 instruction))
	  (rd     (operand3 instruction))
	  (imm    (operand4 instruction)))

      (define (generic-arith-op2-imm method)
	'(begin (display `(reg/op2imm/setreg ,instruction 
			   in (generic-arith-op2-imm ,method)))
		(newline))
	(let* ((numeric (operand5 instruction))
	       (label   (intern-label as numeric))
	       (jump-idx (car label))
	       (lcg-label (cdr label)))
	  (lcg:cov as 50.3)
	  (cond ((not (eqv? rs 'result))
		 (lcg:cov as 50.31)
		 ;; generic ops work via result reg, so uncond move rs to result
		 (ilgen! as (lcg:op:call (lcg:method:offset->reg_to_result rs)))))
	  (ilgen! as (lcg:op:ldc.i4 jump-idx))
	  (ilgen! as (lcg:op:stsfld lcg:field:implicit-continuation))
	  (ilgen! as (lcg:op:ldsfld lcg:field:result))
	  (ilgen! as (lcg:op:ldc.i4 imm))
	  (ilgen! as (lcg:op:callvirt method))
	  (ilgen! as (lcg:op:ldc.i4 -1))
	  (ilgen! as (lcg:op:stsfld lcg:field:implicit-continuation))
	  (ilgen! as `(label ,lcg-label))
	  (cond ((not (eqv? rd 'result))
		 (lcg:cov as 50.32)
		 (ilgen! as (lcg:op:call (lcg:method:offset->result_to_reg rd)))))))

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:cov as 50.11)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:cov as 50.12)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op2imm/setreg ": unknown register" rs))))

      (define (setreg rd)
	(cond ((eq? rd 'result)
	       (lcg:cov as 50.21)
	       (lcg:op:stsfld lcg:field:result))
	      ((number? rd)
	       (lcg:cov as 50.22)
	       (lcg:op:call (lcg:method:offset->set_register rd)))
	      (else (error 'reg/op2imm/setreg ": unknown register" rd))))

      (define (fixed-arith-op2-imm method int32-imm)
	;; [no implicit continuation]
	(ilgen! as (getreg rs))
	(ilgen! as (lcg:op:ldc.i4 int32-imm))
	(ilgen! as (lcg:op:callvirt method))
	(ilgen! as (setreg rd)))

      (case primop
	((eq?:int32)       (lcg:cov as 50.411)
	 (fixed-arith-op2-imm lcg:method:op_eqp_int32 imm))
	((+:idx:idx:int32) (lcg:cov as 50.412)
	 (fixed-arith-op2-imm lcg:method:op_plus_idx_idx_int32 imm))
	((-:idx:idx:int32) (lcg:reach? 50.413)
	 (fixed-arith-op2-imm lcg:method:op_minus_idx_idx_int32 imm))
	((=:int32)  (lcg:cov as 50.421)
	 (generic-arith-op2-imm lcg:method:op_numeric_equals_int32))
	((+:int32)  (lcg:cov as 50.422)
	 (generic-arith-op2-imm lcg:method:op_plus_int32))
	((-:int32)  (lcg:cov as 50.423)
	 (generic-arith-op2-imm lcg:method:op_minus_int32))
	((fx<:int32) (lcg:reach? 50.431)
	 (fixed-arith-op2-imm lcg:method:op_fxless_int32 imm))
	((>=:fix:fix:int32) (lcg:cov as 50.432)
	 (fixed-arith-op2-imm lcg:method:op_greaterequal_fix_fix_int32 imm))
	((<:fix:fix:int32) (lcg:cov as 50.433)
	 (fixed-arith-op2-imm lcg:method:op_less_fix_fix_int32 imm))
	((vector-ref:trusted:int32) (lcg:cov as 50.434)
	 (fixed-arith-op2-imm lcg:method:op_vector_ref_trusted_int32 imm))
	((char=?:char) (lcg:cov as 50.435)
	 (fixed-arith-op2-imm lcg:method:op_charequals_int32 (char->integer imm)))
	(else (error '$reg/op2imm/setreg ": unknown primop" primop))))))

(define-instruction $reg/op1/branchf
  (lambda (instruction as)
    (list-instruction "reg/op1/branchf" instruction)
    (lcg:cov as 51)
    (let* ((primop (operand1 instruction))
	   (rs (operand2 instruction))        ;; XXX use apropos observers
	   (target-label (operand3 instruction))
	   (no-branch-label (fresh-lcg-label as 'reg/op1/branchf:no-branch))
	   (label (intern-label as target-label))
	   (jump-idx (car label))
	   (lcg-label (cdr label)))
      
      (define (branch-code)
	(cond ((assq target-label (as-labels as))
	       (lcg:generate-timer-check as lcg-label jump-idx))
	      (else
	       (ilgen! as (lcg:op:br lcg-label)))))

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:cov as 51.21)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:reach? 51.22)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op1/branchf ": unknown register" rs))))

      (define (match-const const-field)
	(ilgen! as (getreg rs))
	(ilgen! as (lcg:op:ldsfld const-field))
	(ilgen! as (lcg:op:beq.s no-branch-label))
	(branch-code)
	(ilgen! as `(label ,no-branch-label)))
      
      (define (match-pred pred-method)
	(ilgen! as (getreg rs))
	(ilgen! as (lcg:op:callvirt pred-method))
	(ilgen! as (lcg:op:brtrue.s no-branch-label))
	(branch-code)	
	(ilgen! as `(label ,no-branch-label)))
      
      (case primop
	((internal:branchf-null?)       (match-const lcg:field:null))
	((internal:branchf-eof-object?) (match-const lcg:field:eof))
	((internal:branchf-fxzero?)     (match-const lcg:field:zero))

	((internal:branchf-pair?)   (match-pred lcg:method:isPair))
	((internal:branchf-fixnum?) (match-pred lcg:method:isFixnum))
	((internal:branchf-char?)   (match-pred lcg:method:isChar))
	
	(else 
	 (error 'assemble "$reg/op1/branchf unknown primop" primop))))))

(define-instruction $reg/op2/branchf
  (lambda (instruction as)
    (list-instruction "reg/op2/branchf" instruction)
    (lcg:cov as 52)

    '(begin (display instruction) (newline))

    (let* ((primop          (operand1 instruction))
	   (rs1             (operand2 instruction))
	   (rs2             (operand3 instruction))
	   (target-label    (operand4 instruction))
	   (no-branch-label (fresh-lcg-label as 'reg/op1/branchf:no-branch))
	   (label           (intern-label as target-label))
	   (jump-idx        (car label))
	   (lcg-label       (cdr label)))

      (define (branch-code)
	(cond ((assq target-label (as-labels as))
	       (lcg:generate-timer-check as lcg-label jump-idx))
	      (else
	       (ilgen! as (lcg:op:br lcg-label)))))

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:cov as 52.21)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:cov as 52.22)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op2/branchf ": unknown register" rs))))

      (case primop
	((internal:branchf-eq?) 
	 (ilgen! as (getreg rs1))
	 (ilgen! as (getreg rs2))
	 (ilgen! as (lcg:op:beq.s no-branch-label))
	 (branch-code)
	 (ilgen! as `(label ,no-branch-label)))
	(else
	 (error 'assemble "$reg/op2/branchf unknown primop" primop))))))
  
(define-instruction $reg/op2imm/branchf
  (lambda (instruction as)
    (list-instruction "reg/op2imm/branchf" instruction)
    (lcg:cov as 53)
    (let* ((primop          (operand1 instruction))
	   (rs              (operand2 instruction))
	   (imm             (operand3 instruction))
	   (target-label    (operand4 instruction))
	   (no-branch-label (fresh-lcg-label as 'reg/op1/branchf:no-branch))
	   (label           (intern-label as target-label))
	   (jump-idx        (car label))
	   (lcg-label       (cdr label)))

      (define (branch-code)
	(cond ((assq target-label (as-labels as))
	       (lcg:generate-timer-check as lcg-label jump-idx))
	      (else
	       (ilgen! as (lcg:op:br lcg-label)))))

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:cov as 53.21)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:cov as 53.22)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op2imm/branchf ": unknown register" rs))))

      (define (match-pred pred-method int-imm)
	(ilgen! as (getreg rs))
	(ilgen! as (lcg:op:ldc.i4 int-imm))
	(ilgen! as (lcg:op:callvirt pred-method))
	(ilgen! as (lcg:op:brtrue.s no-branch-label))
	(branch-code)
	(ilgen! as `(label ,no-branch-label)))

      (case primop
	((internal:branchf-eq?/imm-int32)       
	 (match-pred lcg:method:isEqpInt32 imm))
	((internal:branchf-fx</imm-int32)
	 (match-pred lcg:method:isFxLessInt32 imm))
	((internal:branchf-=:fix:fix/imm-int32)
	 (match-pred lcg:method:isNumericEqualFixFixInt32 imm))
	((internal:branchf-<:fix:fix/imm-int32) 
	 (match-pred lcg:method:isLessFixFixInt32 imm))
	((internal:branchf-char=?/imm-char) 
	 (match-pred lcg:method:isCharEqualsInt32 (char->integer imm)))
	(else
	 (error 'assemble "$reg/op2imm/branchf unknown primop" primop))))))

(define-instruction $reg/op1/check
  (lambda (instruction as)
    (list-instruction "reg/op1/check" instruction)
    (lcg:cov as 54)
    (let* ((primop       (operand1 instruction))
	   (rs           (operand2 instruction))
	   (target-label (operand3 instruction))
	   (label        (intern-label as target-label))
	   (jump-idx     (car label))
	   (lcg-label    (cdr label)))

      (define (getreg rs)
	(cond ((eq? rs 'result)
	       (lcg:cov as 54.11)
	       (lcg:op:ldsfld lcg:field:result))
	      ((number? rs)
	       (lcg:cov as 54.12)
	       (lcg:op:call (lcg:method:offset->get_register rs)))
	      (else (error 'reg/op1/check ": unknown register" rs))))

      (define (check-pred pred-method)
	(ilgen! as (getreg rs))
	(ilgen! as (lcg:op:callvirt pred-method))
	(ilgen! as (lcg:op:brfalse lcg-label)))

      (case primop
	((internal:check-fixnum?) (check-pred lcg:method:isFixnum))
	((internal:check-pair?)   (check-pred lcg:method:isPair))
	((internal:check-vector?) (check-pred lcg:method:isVector))
	((internal:check-string?) (check-pred lcg:method:isString))
	(else
	 (error 'assemble "$reg/op1/check unknown primop" primop))))))

(define-instruction $reg/op2/check
  (lambda (instruction as)
    (list-instruction "reg/op2/check" instruction)
    (lcg:reach? 55)
    (let ((primop (operand1 instruction))
	  (rs1    (operand2 instruction))
	  (rd     (operand3 instruction))
	  (rs2    (operand4 instruction)))
      (case primop
	(else
	 (error 'assemble "$reg/op2/check unknown primop" primop))))))
  
(define-instruction $reg/op2imm/check
  (lambda (instruction as)
    (list-instruction "reg/op2imm/check" instruction)
    (lcg:reach? 56)
    (let ((primop       (operand1 instruction))
	  (rs1          (operand2 instruction))
	  (imm          (operand3 instruction))
	  (target-label (operand4 instruction)))
      (case primop
	(else
	 (error 'assemble "$reg/op2imm/check unknown primop" primop))))))

