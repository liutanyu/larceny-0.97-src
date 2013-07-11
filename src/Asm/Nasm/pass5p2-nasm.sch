; Copyright 1991 Lightship Software, Incorporated.
;
; $Id: pass5p2-nasm.sch 4150 2007-03-17 18:18:33Z pnkfelix $
;
; Intel x86 machine assembler, building on NASM.
; Lars T Hansen.
;
; Code generation strategy:
;   Each MAL basic block is compiled to a separate ASM procedure, with
;   the name compiled_block_x_y where x is a procedure label (unique
;   in a file) and y is the label at the block's entry point.
;
;   Procedure entry points do not have labels, and the entry points
;   are named compiled_start_x_y, where y is some unique identifier.
;
;   A list of procedure names is maintained (with a flag for whether they
;   are conditional or not); they can be used to create forward declarations
;   when assembly is done.
;
; Overrides the procedures of the same name in Asm/Common/pass5p1.sch.

(define (assembly-table) $x86-nasm-assembly-table$)

(define (assembly-start as)
  (let ((u (as-user as)))
    (user-data.proc-counter! u 0)
    (user-data.toplevel-counter! u (+ 1 (user-data.toplevel-counter u))))
  (let ((e (new-proc-id as)))
    (as-source! as (cons (list $.entry e #t) (as-source as)))))

(define (assembly-end as segment)
  (list (car segment) (cdr segment) (lookup-functions as)))

(define (assembly-user-data)
  (make-user-data))

(define (assembly-declarations user-data)
  (append (if (not (runtime-safety-checking))
	      '("%define UNSAFE_CODE")
	      '())
	  (if (not (catch-undefined-globals))
	      '("%define UNSAFE_GLOBALS")
	      '())
	  (if (inline-allocation)
	      '("%define INLINE_ALLOCATION")
	      '())
	  (if (inline-assignment)
	      '("%define INLINE_ASSIGNMENT")
	      '())))

; User-data structure has three fields:
;  toplevel-counter     Different for each compiled segment
;  proc-counter         A serial number for labels
;  seen-labels          A list of labels at lower addresses

(define (make-user-data) (list 0 0 '()))

(define (user-data.toplevel-counter u) (car u))
(define (user-data.proc-counter u) (cadr u))
(define (user-data.labels u) (caddr u))

(define (user-data.toplevel-counter! u x) (set-car! u x))
(define (user-data.proc-counter! u x) (set-car! (cdr u) x))
(define (user-data.labels! u x) (set-car! (cddr u) x))


; Assembly listing.

(define listify? #f)

(define $x86-nasm-assembly-table$
  (make-vector
   *number-of-mnemonics*
   (lambda (instruction as)
     (asm-error "Unrecognized mnemonic " instruction))))

(define (define-instruction i proc)
  (vector-set! $x86-nasm-assembly-table$ i proc)
  #t)

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


; Auxiliary assembler interface.

(define emit-text-noindent
  (let ((linebreak (string #\newline)))
    (lambda (as fmt . operands)
      (emit-string! as (apply twobit-format #f fmt operands))
      (emit-string! as linebreak))))

(define emit-text
  (let ((linebreak (string #\newline)))
    (lambda (as fmt . operands)
      (emit-string! as code-indentation)
      (emit-string! as (apply twobit-format #f fmt operands))
      (emit-string! as linebreak))))

(define (begin-compiled-scheme-function as label entrypoint? start?)
  (let ((name (compiled-procedure as label)))
    (emit-text as "begin_codevector ~a" name)
    (add-function as name #t entrypoint?)
    (set! code-indentation (string #\tab))
    (set! code-name name)))

(define (add-compiled-scheme-function as label entrypoint? start?)
  (let ((name (compiled-procedure as label)))
    (if (not (assoc name (lookup-functions as)))
        (add-function as name #t entrypoint?))))

(define (end-compiled-scheme-function as)
  (set! code-indentation "")
  (emit-text as "end_codevector ~a" code-name)
  (emit-text as ""))

(define code-indentation "")
(define code-name "")

(define (lookup-functions as)
  (or (assembler-value as 'functions) '()))

(define (add-function as name definite? entrypoint?)
  (assembler-value! as 'functions (cons (list name definite? entrypoint?)
					(lookup-functions as)))
  name)
    
; Pseudo-instructions.

(define-instruction $.align
  (lambda (instruction as)
    (list-instruction ".align" instruction)
    (emit-text as "T_ALIGN ~a" (operand1 instruction))))

(define-instruction $.cont
  (lambda (instruction as)
    (list-instruction ".cont" instruction)
    (emit-text as "T_CONT")))

(define-instruction $.end
  (lambda (instruction as)
    (list-instruction ".end" instruction)
    (end-compiled-scheme-function as)))

(define-instruction $.entry
  (lambda (instruction as)
    (list-instruction ".entry" instruction)
    (begin-compiled-scheme-function as (operand1 instruction)
				    (operand2 instruction)
				    #t)))

(define-instruction $.label
  (lambda (instruction as)
    (list-label instruction)
    (add-compiled-scheme-function as (operand1 instruction) #f #f)
    (let ((u (as-user as)))
      (user-data.labels! u (cons (operand1 instruction) (user-data.labels u))))
    (emit-text-noindent as
			"T_LABEL ~a" 
			(compiled-procedure as (operand1 instruction)))))

(define-instruction $.proc
  (lambda (instruction as)
    (list-instruction ".proc" instruction)))

(define-instruction $.proc-doc
  (lambda (instruction as)
    (list-instruction ".proc-doc" instruction)
    (add-documentation as (operand1 instruction))))

(define-instruction $.singlestep
  (lambda (instruction as)
    ; Use GDB.
    #t))
    

; Instructions.

; A hack to deal with the MacScheme macro expander's treatment of 1+ and 1-.

(define-instruction $op1
  (lambda (instruction as)
    (list-instruction "op1" instruction)
    (emit-text as "T_OP1_~a ; ~a"
	       (op1-primcode (operand1 instruction))
	       (operand1 instruction))))

(define-instruction $op2
  (lambda (instruction as)
    (list-instruction "op2" instruction)
    (emit-text as "T_OP2_~a ~a  ; ~a"
	       (op2-primcode (operand1 instruction))
	       (operand2 instruction)
	       (operand1 instruction))))

(define-instruction $op2imm
  (lambda (instruction as)
    (list-instruction "op2imm" instruction)
    (emit-text as "T_OP2IMM_~a ~a  ; ~a"
	       (op2imm-primcode (operand1 instruction))
	       (constant-value (operand2 instruction))
	       (operand1 instruction))))

(define-instruction $op3
  (lambda (instruction as)
    (list-instruction "op3" instruction)
    (emit-text as "T_OP3_~a ~a, ~a  ; ~a"
	       (op3-primcode (operand1 instruction))
	       (operand2 instruction)
	       (operand3 instruction)
	       (operand1 instruction))))

(define-instruction $const
  (lambda (instruction as)
    (list-instruction "const" instruction)
    (if (immediate-constant? (operand1 instruction))
	(emit-text as "T_CONST_IMM ~a"
		   (constant-value (operand1 instruction)))
	(emit-text as "T_CONST_CONSTVECTOR ~a"
		   (emit-datum as (operand1 instruction))))))

(define-instruction $global
  (lambda (instruction as)
    (list-instruction "global" instruction)
    (emit-text as "T_GLOBAL ~a   ; ~a"
	       (emit-global as (operand1 instruction))
	       (operand1 instruction))))

(define-instruction $setglbl
  (lambda (instruction as)
    (list-instruction "setglbl" instruction)
    (emit-text as "T_SETGLBL ~a   ; ~a"
	       (emit-global as (operand1 instruction))
	       (operand1 instruction))))

(define-instruction $lambda
  (lambda (instruction as)
    (let* ((const-offset #f)
	   (code-offset  #f)
	   (entry        (new-proc-id as)))
      (list-lambda-start instruction)
      (assemble-nested-lambda
       as
       (cons (list $.entry entry #f)
	     (operand1 instruction))
       (operand3 instruction)
       (lambda (nested-as segment)
	 (assembler-value! as 'functions
			   (append (lookup-functions as)
				   (lookup-functions nested-as)))
	 (set-constant! as code-offset (car segment))
	 (set-constant! as const-offset (cdr segment)))
       (as-user as))
      (list-lambda-end)
      (set! code-offset (emit-codevector as 0))
      (set! const-offset (emit-constantvector as 0))
      (emit-text as "T_LAMBDA ~a, ~a, ~a"
		 (compiled-procedure as entry)
		 const-offset
		 (operand2 instruction)))))

(define-instruction $lexes
  (lambda (instruction as)
    (list-instruction "lexes" instruction)
    (emit-text as "T_LEXES ~a" (operand1 instruction))))

(define-instruction $args=
  (lambda (instruction as)
    (list-instruction "args=" instruction)
    (emit-text as "T_ARGSEQ ~a" (operand1 instruction))))

(define-instruction $args>=
  (lambda (instruction as)
    (list-instruction "args>=" instruction)
    (emit-text as "T_ARGSGE ~a" (operand1 instruction))))

(define-instruction $invoke
  (lambda (instruction as)
    (list-instruction "invoke" instruction)
    (emit-text as "T_INVOKE ~a" (operand1 instruction))))

(define-instruction $restore
  (lambda (instruction as)
    (if (not (negative? (operand1 instruction)))
	(begin
	  (list-instruction "restore" instruction)
	  (emit-text as "T_RESTORE ~a"
		     (min (operand1 instruction) (- *nregs* 1)))))))

(define-instruction $pop
  (lambda (instruction as)
    (if (not (negative? (operand1 instruction)))
	(begin
	  (list-instruction "pop" instruction)
	  (emit-text as "T_POP ~a" (operand1 instruction))))))

(define-instruction $popstk
  (lambda (instruction as)
    (error "POPSTK is not yet implemented by the x86-NASM assembler.")))

(define-instruction $stack
  (lambda (instruction as)
    (list-instruction "stack" instruction)
    (emit-text as "T_STACK ~a" (operand1 instruction))))

(define-instruction $setstk
  (lambda (instruction as)
    (list-instruction "setstk" instruction)
    (emit-text as "T_SETSTK ~a" (operand1 instruction))))

(define-instruction $load
  (lambda (instruction as)
    (list-instruction "load" instruction)
    (emit-text as "T_LOAD ~a, ~a"
	       (operand1 instruction) (operand2 instruction))))

(define-instruction $store
  (lambda (instruction as)
    (list-instruction "store" instruction)
    (emit-text as "T_STORE ~a, ~a"
	       (operand1 instruction) (operand2 instruction))))

(define-instruction $lexical
  (lambda (instruction as)
    (list-instruction "lexical" instruction)
    (emit-text as "T_LEXICAL ~a, ~a"
	       (operand1 instruction)
	       (operand2 instruction))))

(define-instruction $setlex
  (lambda (instruction as)
    (list-instruction "setlex" instruction)
    (emit-text as "T_SETLEX ~a, ~a"
	       (operand1 instruction)
	       (operand2 instruction))))

(define-instruction $reg
  (lambda (instruction as)
    (list-instruction "reg" instruction)
    (emit-text as "T_REG ~a" (operand1 instruction))))

(define-instruction $setreg
  (lambda (instruction as)
    (list-instruction "setreg" instruction)
    (emit-text as "T_SETREG ~a" (operand1 instruction))))

(define-instruction $movereg
  (lambda (instruction as)
    (list-instruction "movereg" instruction)
    (emit-text as "T_MOVEREG ~a, ~a"
	       (operand1 instruction) (operand2 instruction))))

(define-instruction $return
  (lambda (instruction as)
    (list-instruction "return" instruction)
    (emit-text as "T_RETURN")))

(define-instruction $nop
  (lambda (instruction as)
    (list-instruction "nop" instruction)
    (emit-text as "T_NOP")))

; (define-instruction $save
;   (lambda (instruction as)
;     (if (not (negative? (operand1 instruction)))
;         (begin
;          (list-instruction "save" instruction)
; 	 (emit-text as "T_SAVE ~a" (operand1 instruction))))))

(define-instruction $save
  (lambda (instruction as)
    (if (not (negative? (operand1 instruction)))
        (begin
	  (list-instruction "save" instruction)
	  (let* ((n (operand1 instruction))
		 (v (make-vector (+ n 1) #t)))
	    (emit-text as "T_SAVE0 ~a" n)
	    (if (peephole-optimization)
		(let loop ((instruction (next-instruction as)))
		  (if (eqv? $store (operand0 instruction))
		      (begin (list-instruction "store" instruction)
			     (emit-text as "T_STORE ~a, ~a"
					(operand1 instruction)
					(operand2 instruction))
			     (consume-next-instruction! as)
			     (vector-set! v (operand2 instruction) #f)
			     (loop (next-instruction as))))))
	    (do ((i 0 (+ i 1)))
		((= i (vector-length v)))
	      (if (vector-ref v i)
		  (emit-text as "T_SAVE1 ~a" i))))))))

(define-instruction $setrtn
  (lambda (instruction as)
    (list-instruction "setrtn" instruction)
    (emit-text as "T_SETRTN ~a" 
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $apply
  (lambda (instruction as)
    (list-instruction "apply" instruction)
    (emit-text as "T_APPLY ~a, ~a"
	       (operand1 instruction)
	       (operand2 instruction))))

(define-instruction $jump
  (lambda (instruction as)
    (list-instruction "jump" instruction)
    (emit-text as "T_JUMP ~a, ~a, ~a"
               (operand1 instruction)
               (operand2 instruction)
	       (compiled-procedure as (operand2 instruction)))))

(define-instruction $skip
  (lambda (instruction as)
    (list-instruction "skip" instruction)
    (emit-text as
	       "T_SKIP ~a"
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $branch
  (lambda (instruction as)
    (list-instruction "branch" instruction)
    (emit-text as
	       (if (memq (operand1 instruction) 
			 (user-data.labels (as-user as)))
		   "T_BRANCH ~a"
		   "T_SKIP ~a")
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $branchf
  (lambda (instruction as)
    (list-instruction "branchf" instruction)
    (emit-text as 
	       (if (memq (operand1 instruction)
			 (user-data.labels (as-user as)))
		   "T_BRANCHF ~a" 
		   "T_SKIPF ~a")
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $check
  (lambda (instruction as)
    (list-instruction "check" instruction)
    (emit-text as "T_CHECK ~a, ~a, ~a, ~a"
               (operand1 instruction)
               (operand2 instruction)
               (operand3 instruction)
               (compiled-procedure as (operand4 instruction)))))

(define-instruction $trap
  (lambda (instruction as)
    (list-instruction "trap" instruction)
    (emit-text as "T_TRAP ~a, ~a, ~a, ~a"
               (operand1 instruction)
               (operand2 instruction)
               (operand3 instruction)
               (operand4 instruction))))

(define-instruction $const/setreg
  (lambda (instruction as)
    (list-instruction "const/setreg" instruction)
    (if (immediate-constant? (operand1 instruction))
	(emit-text as "T_CONST_SETREG_IMM  ~a, ~a"
		   (constant-value (operand1 instruction))
		   (operand2 instruction))
	(emit-text as "T_CONST_SETREG_CONSTVECTOR ~a, ~a"
		   (emit-datum as (operand1 instruction))
                   (operand2 instruction)))))

(define-instruction $op1/branchf
  (lambda (instruction as)
    (list-instruction "op1/branchf" instruction)
    (emit-text as "T_OP1_BRANCHF_~a ~a  ; ~a"
	       (op-primcode (operand1 instruction))
	       (compiled-procedure as (operand2 instruction))
	       (operand1 instruction))))

(define-instruction $op2/branchf
  (lambda (instruction as)
    (list-instruction "op2/branchf" instruction)
    (emit-text as "T_OP2_BRANCHF_~a ~a, ~a ; ~a"
	       (op-primcode (operand1 instruction))
	       (operand2 instruction)
	       (compiled-procedure as (operand3 instruction))
	       (operand1 instruction))))

(define-instruction $op2imm/branchf
  (lambda (instruction as)
    (list-instruction "op2imm/branchf" instruction)
    (emit-text as "T_OP2IMM_BRANCHF_~a  ~a, ~a  ; ~a"
	       (op-primcode (operand1 instruction))            ; Note, not op2imm-primcode
	       (constant-value (operand2 instruction))
	       (compiled-procedure as (operand3 instruction))
	       (operand1 instruction))))

(define-instruction $global/invoke
  (lambda (instruction as)
    (list-instruction "global/invoke" instruction)
    (emit-text as "T_GLOBAL_INVOKE  ~a, ~a  ; ~a" 
	       (emit-global as (operand1 instruction))
	       (operand2 instruction)
	       (operand1 instruction))))

;    Note, for the _check_ optimizations there is a hack in place.  Rather
;    than using register numbers in the instructions the assembler emits
;    reg(k) expressions when appropriate.  The reason it does this is so
;    that it can also emit RESULT when it needs to, since RESULT can
;    appear as a register name in these instructions.
;
;    This is a hack, but it beats having two versions of every macro.

; FIXME: not right -- REGn only works for HW registers!

'(define-instruction $reg/op1/check
  (lambda (instruction as)
    (list-instruction "reg/op1/check" instruction)
    (let ((rn (if (eq? (operand2 instruction) 'result)
		  "RESULT"
		  (twobit-format #f "REG~a" (operand2 instruction)))))
      (emit-text as "T_REG_OP1_CHECK_~a ~a,~a   ; ~a with ~a"
		 (op-primcode (operand1 instruction))
		 rn
		 (operand3 instruction)
		 (operand1 instruction)
		 (operand4 instruction)))))

'(define-instruction $reg/op2/check
  (lambda (instruction as)
    (list-instruction "reg/op2/check" instruction)
    (let ((rn (if (eq? (operand2 instruction) 'result)
		  "RESULT"
		  (twobit-format #f "REG~a" (operand2 instruction)))))
      (emit-text as "twobit_reg_op2_check_~a(~a,reg(~a),~a,~a); /* ~a with ~a */"
		 (op2-primcode (operand1 instruction))
		 rn
		 (operand3 instruction)
		 (operand4 instruction)
		 (compiled-procedure as (operand4 instruction))
		 (operand1 instruction)
		 (operand5 instruction)))))

'(define-instruction $reg/op2imm/check
  (lambda (instruction as)
    (list-instruction "reg/op2imm/check" instruction)
    (let ((rn (if (eq? (operand2 instruction) 'result)
		  "RESULT"
		  (twobit-format #f "reg(~a)" (operand2 instruction)))))
      (emit-text as "twobit_reg_op2imm_check_~a(~a,~a,~a,~a); /* ~a with ~a */"
		 (op2-primcode (operand1 instruction)) ; Note, not op2imm-primcode
		 rn
		 (constant-value (operand3 instruction))
		 (operand4 instruction)
		 (compiled-procedure as (operand4 instruction))
		 (operand1 instruction)
		 (operand5 instruction)))))

; Helper procedures.

(define (compiled-procedure as label)
  (twobit-format #f "compiled_start_~a_~a" 
		 (user-data.toplevel-counter (as-user as))
		 label))

(define (immediate-constant? x)
  (or (fixnum? x)
      (null? x)
      (boolean? x)
      (char? x)
      (eof-object? x)
      (equal? x (unspecified))
      (equal? x (undefined))))

(define (constant-value x)

  (define (exact-int->fixnum x)
    (* x 4))

  (define (char->immediate c)
    (+ (* (char->integer c) 65536) $imm.character))

  (cond ((fixnum? x)              (twobit-format #f "fixnum(~a)" x))
        ((eq? x #t)               "TRUE_CONST")
        ((eq? x #f)               "FALSE_CONST")
	((equal? x (eof-object))  "EOF_CONST")
	((equal? x (unspecified)) "UNSPECIFIED_CONST")
	((equal? x (undefined))   "UNDEFINED_CONST")
        ((null? x)                "NIL_CONST")
        ((char? x)                (if (and (char>? x #\space)
					   (char<=? x #\~)
					   (not (char=? x #\\))
					   (not (char=? x #\')))
				      (twobit-format #f "char('~a')" x)
				      (twobit-format #f "char(~a)" 
						 (char->integer x))))
	(else ???)))

(define (new-proc-id as)
  (let* ((u (as-user as))
	 (x (user-data.proc-counter u)))
    (user-data.proc-counter! u (+ 1 x))
    x))

(define (op-primcode name)
  (prim-primcode (prim-entry-by-opcodename name)))

; eof
