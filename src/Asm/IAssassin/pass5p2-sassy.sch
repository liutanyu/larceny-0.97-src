; Copyright 1991 Lightship Software, Incorporated.
;
; $Id: pass5p2-sassy.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Intel x86 machine assembler, building on Sassy.
; Felix S Klock.
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

(define (assembly-table) $x86-sassy-assembly-table$)

(define (assembly-start as)
  (let ((u (as-user as)))
    (user-data.proc-counter! u 0)
    (user-data.toplevel-counter! u (+ 1 (user-data.toplevel-counter u)))
    (user-data.local-counter! u 0))
  (reset-symbolic-label-cache!)
  (let ((e (new-proc-id as)))
    (as-source! as (cons (list $.entry e #t) (as-source as))))
  (current-sassy-assembly-structure as))

; Checks for free identifiers in the given Sassy input,
; which is a common error when writing new sequences of
; assembly code.  The association lists make this check
; too expensive for large inputs, however, so sassy-assemble
; calls it only for small inputs.

(define (check-for-free-ids code)

  (define (keyword? x)
    (case x
      ((eax ebx ecx edx edi esi esp ebp
         al  bl  cl  dl
         & align reloc abs
         short try-short
         dword byte) #t)
      (else #f)))
         
  (let ((need-labels  '())
        (found-labels '()))

    (define (sym x)
      (cond ((and (not (keyword? x))
                  (not (memq x found-labels))
                  (not (memq x need-labels)))
             (set! need-labels (cons x need-labels)))))

    (define (found-label! l)
      (if (memq l found-labels)
          (error 'check-for-free-labels " duplicate label " l))
      (set! found-labels 
            (cons l found-labels))
      (set! need-labels 
            (filter (lambda (x) (not (eq? x l))) need-labels)))

    (define (arg! x)
      (cond
       ((number? x) 'ignore)
       ((null? x) 'ignore)
       ((pair? x) 
          (arg! (car x)) 
          (arg! (cdr x)))
       ((symbol? x)
        (sym x))
       (else (error 'check-for-free-ids " what is: " x))))

    (define (instr! i)
      (case (car i)
        ((label) 
         (found-label! (cadr i))
         (for-each instr! (cddr i)))
        ((rep) 
         (for-each instr! (cdr i)))
        (else 
         ;; skip opcode
         (for-each arg! (cdr i)))))

    (for-each instr! code)
  
    (cond ((not (null? need-labels))
           (pretty-print code)
           (error 'check-for-free-ids " unbound: " need-labels)))))
       

    
;; match instances of (X try-short . Y) in code tree and rewrite them
;; according to policy encoded in make-replacement function.

(define (replace-try-short-with code make-replacement)
  (let rec ((x code))
    (cond ((and (pair? x) (pair? (cdr x)) (eq? 'try-short (cadr x)))
           (make-replacement (rec (car x)) (rec (cddr x))))
          ((pair? x) (cons (rec (car x)) (rec (cdr x))))
          (else x))))

;; match instances of (X try-short L); replace with (X short L)

(define (shorten-try-short code)
  (replace-try-short-with code (lambda (x y) (cons x (cons 'short y)))))

;; match instances of (X try-short L); drop try-short unconditionally

(define (kill-try-short code)
  (replace-try-short-with code cons))

;; match instances of (X try-short L); if L in labels, drop try-short

(define (kill-try-short-for-labels code labels)
  ;; FIXME: should use hashset to represent large labels list,
  ;; avoiding O(n^2) blowup
  (replace-try-short-with code (lambda (x y)
                                 (if (memq (car y) labels)
                                     (cons x y)
                                     (cons x (cons 'try-short y))))))

(define (sassy/trying-short code)
  (sassy (shorten-try-short code) 'dont-expand 'recover-from-fixup-errors))

(define (sassy/not-trying-short code)
  (sassy (kill-try-short code) 'dont-expand))

(define (sassy/try-short-iteratively code)
  (twobit-iterative-try/fallback 
   code 
   sassy/trying-short
   (lambda (x) (relocs-out-of-range-condition? x))
   (lambda (x c) (kill-try-short-for-labels x (relocs-out-of-range-labels c)))
   sassy/not-trying-short))

(define (sassy-assemble as code)
  (define satry sassy/try-short-iteratively)
  ;(begin (display code) (newline))
  (if (< (length code) 100)                 ; FIXME
      (check-for-free-ids code))
  (satry `(,@(map (lambda (entry) `(export ,(compiled-procedure as (car entry))))
                  (as-labels as))
           (org  ,$bytevector.header-bytes)
           (text ,@code))))

(define (assembly-end as segment)
  segment)

(define (assembly-user-data)
  (make-user-data))

(define (assembly-user-local)
  (make-user-local))

;; make-sassy-postpass : (AsmStruct AsmSegment SassyOutput -> X) -> AsmStruct AsmSegment -> X
(define (make-sassy-postpass k)
  (lambda (as seg)
    (let ((code (sassy-assemble as (car seg))))
      (for-each (lambda (entry) 
                  (let* ((sym-table (sassy-symbol-table code))
                         (sassy-sym (hash-table-ref 
                                     sym-table 
                                     (compiled-procedure as (car entry))))
                         (offset (sassy-symbol-offset sassy-sym)))
                    (set-cdr! entry offset)))
                (as-labels as))
      (k as seg code))))

(set! assembly-postpass-segment
      (make-sassy-postpass 
       (lambda (as seg sassy-output)
         (cons (sassy-text-bytevector sassy-output)
               (cdr seg)))))

(define (assemble-read source . rest)
  (let* ((old-postpass assembly-postpass-segment)
         (new-postpass (make-sassy-postpass 
                        (lambda (as seg sassy-output)
                          ;; still need old-postpass, to store the
                          ;; generated sassy-output for offsets of
                          ;; labels for inner lambdas.  Discard
                          ;; result; output is a human readable Sexp.
                          (old-postpass as seg)
                          (cons (car seg) (cdr seg))))))
    (dynamic-wind 
        (lambda () (set! assembly-postpass-segment new-postpass))
        (lambda () (apply assemble source rest))
        (lambda () (set! assembly-postpass-segment old-postpass)))))
      
; User-data structure has three fields:
;  toplevel-counter     Different for each compiled segment
;  proc-counter         A serial number for labels
;  [slot no longer used]
;  local-counter        A serial number for (local) labels

(define (make-user-data) (list 0 0 '() 0 #f #f #f))

(define (user-data.toplevel-counter u) (car u))
(define (user-data.proc-counter u) (cadr u))
(define (user-data.local-counter u) (cadddr u))

(define (user-data.toplevel-counter! u x) (set-car! u x))
(define (user-data.proc-counter! u x) (set-car! (cdr u) x))
(define (user-data.local-counter! u x) (set-car! (cdddr u) x))

(define (make-user-local) (list))

(define (fresh-label)
  (let* ((as (current-sassy-assembly-structure))
         (local (user-data.local-counter (as-user as)))
         (new-local (- local 1)))
    (user-data.local-counter! (as-user as) new-local)
    (string->symbol
     (string-append ".L" (number->string new-local)))))

; Assembly listing.

(define listify? #f)

(define $x86-sassy-assembly-table$
  (make-vector
   *number-of-mnemonics*
   (lambda (instruction as)
     (asm-error "Unrecognized mnemonic " instruction))))

(define (define-instruction i proc)
  (vector-set! $x86-sassy-assembly-table$ i 
               (lambda (i as)
                 (parameterize ((current-sassy-assembly-structure as))
                   (proc i as))))
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

(define emit-sassy 
  (lambda (as . x)
    (define (handle-added-code! as added-code)
      (cond ((null? added-code)
             (unspecified))
            ((null? (as-code as))
             (as-code! as (cons added-code (last-pair added-code))))
            (else
             (let* ((beg*end (as-code as))
                    (beg (car beg*end))
                    (end (cdr beg*end))
                    (new-end (last-pair added-code)))
               (set-cdr! end added-code)
               (as-code! as (cons beg new-end))))))
    (cond 
     ((procedure? (car x))
      (parameterize ((current-sassy-assembly-structure as))
        (let* ((added-code (apply do-sassy-instr (car x) (cdr x))))
          (handle-added-code! as added-code))))
     (else
      (handle-added-code! as (list x))))
    (as-lc! as (+ (as-lc as) 1)))) ; FSK: perhaps incrementing by 1 won't work, but what the hell.

(define emit-text-noindent
  (let ((linebreak (string #\newline)))
    (lambda (as fmt . operands)
      (error 'emit-text-noindent "calls to emit-text should be replaced in Sassy")
      (emit-string! as (apply twobit-format #f fmt operands))
      (emit-string! as linebreak))))

(define emit-text
  (let ((linebreak (string #\newline)))
    (lambda (as fmt . operands)
      (error 'emit-text "calls to emit-text should be replaced in Sassy")
      (emit-string! as code-indentation)
      (emit-string! as (apply twobit-format #f fmt operands))
      (emit-string! as linebreak))))

(define (begin-compiled-scheme-function as label entrypoint? start?)
  (let ((name (compiled-procedure as label)))
    ;(emit-text as "begin_codevector ~a" name)
    (emit-sassy as 'align $bytewidth.code-align)
    (set! code-indentation (string #\tab))
    (set! code-name name)))

(define (end-compiled-scheme-function as)
  (set! code-indentation "")
  ;(emit-text as "end_codevector ~a" code-name)
  ;(emit-text as "")
  )

(define code-indentation "")
(define code-name "")

; Pseudo-instructions.

(define-instruction $.align
  (lambda (instruction as)
    (list-instruction ".align" instruction)
    (emit-sassy as ia86.t_align
                (operand1 instruction))
    ))

(define-instruction $.cont
  (lambda (instruction as)
    (list-instruction ".cont" instruction)
    (emit-sassy as ia86.t_cont)
    ))

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
    (make-asm-label as (operand1 instruction))
    (emit-sassy as ia86.t_label
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
    (emit-sassy as ia86.t_op1
	       (operand1 instruction))))

(define-instruction $op2
  (lambda (instruction as)
    (list-instruction "op2" instruction)
    (emit-sassy as ia86.t_op2
                (operand1 instruction)
                (operand2 instruction))))

(define-instruction $op2imm
  (lambda (instruction as)
    (list-instruction "op2imm" instruction)
    (emit-sassy as ia86.t_op2imm 
                (operand1 instruction) 
                (constant-value (operand2 instruction)))))

(define-instruction $op3
  (lambda (instruction as)
    (list-instruction "op3" instruction)
    (emit-sassy as ia86.t_op3
                (operand1 instruction)
                (operand2 instruction)
                (operand3 instruction))))


(define-instruction $const
  (lambda (instruction as)
    (list-instruction "const" instruction)
    (if (immediate-constant? (operand1 instruction))
	(emit-sassy as ia86.t_const_imm
                    (constant-value (operand1 instruction)))
	(emit-sassy as ia86.t_const_constvector
                    (emit-datum as (operand1 instruction))))))


(define-instruction $global
  (lambda (instruction as)
    (list-instruction "global" instruction)
    (emit-sassy as ia86.t_global
                (emit-global as (operand1 instruction)))))

(define-instruction $setglbl
  (lambda (instruction as)
    (list-instruction "setglbl" instruction)
    (emit-sassy as ia86.t_setglbl
	       (emit-global as (operand1 instruction)))))

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
	 (set-constant! as code-offset (car segment))
	 (set-constant! as const-offset (cdr segment)))
       (as-user as))
      (list-lambda-end)
      (set! code-offset (emit-codevector as 0))
      (set! const-offset (emit-constantvector as 0))
      (emit-sassy as ia86.t_lambda
                 code-offset 
		 const-offset
		 (operand2 instruction)))))

(define-instruction $lexes
  (lambda (instruction as)
    (list-instruction "lexes" instruction)
    (emit-sassy as ia86.t_lexes (operand1 instruction))))

(define-instruction $args=
  (lambda (instruction as)
    (list-instruction "args=" instruction)
    (emit-sassy as ia86.t_argseq (operand1 instruction))))

(define-instruction $args>=
  (lambda (instruction as)
    (list-instruction "args>=" instruction)
    (emit-sassy as ia86.t_argsge (operand1 instruction))))

(define-instruction $invoke
  (lambda (instruction as)
    (list-instruction "invoke" instruction)
    (emit-sassy as ia86.t_invoke (operand1 instruction))))

(define-instruction $restore
  (lambda (instruction as)
    (if (not (negative? (operand1 instruction)))
	(begin
	  (list-instruction "restore" instruction)
	  (emit-sassy as ia86.t_restore
		     (min (operand1 instruction) (- *nregs* 1)))))))

(define-instruction $pop
  (lambda (instruction as)
    (if (not (negative? (operand1 instruction)))
	(begin
	  (list-instruction "pop" instruction)
	  (emit-sassy as ia86.t_pop (operand1 instruction))))))

(define-instruction $popstk
  (lambda (instruction as)
    (error "POPSTK is not yet implemented by the x86-NASM assembler.")))

(define-instruction $stack
  (lambda (instruction as)
    (list-instruction "stack" instruction)
    (emit-sassy as ia86.t_stack (operand1 instruction))))

(define-instruction $setstk
  (lambda (instruction as)
    (list-instruction "setstk" instruction)
    (emit-sassy as ia86.t_setstk (operand1 instruction))))

(define-instruction $load
  (lambda (instruction as)
    (list-instruction "load" instruction)
    (emit-sassy as ia86.t_load
	       (operand1 instruction) (operand2 instruction))))

(define-instruction $store
  (lambda (instruction as)
    (list-instruction "store" instruction)
    (emit-sassy as ia86.t_store
	       (operand1 instruction) (operand2 instruction))))

(define-instruction $lexical
  (lambda (instruction as)
    (list-instruction "lexical" instruction)
    (emit-sassy as ia86.t_lexical
	       (operand1 instruction)
	       (operand2 instruction))))

(define-instruction $setlex
  (lambda (instruction as)
    (list-instruction "setlex" instruction)
    (emit-sassy as ia86.t_setlex
	       (operand1 instruction)
	       (operand2 instruction))))

(define-instruction $reg
  (lambda (instruction as)
    (list-instruction "reg" instruction)
    (emit-sassy as ia86.t_reg (operand1 instruction))))

(define-instruction $setreg
  (lambda (instruction as)
    (list-instruction "setreg" instruction)
    (emit-sassy as ia86.t_setreg (operand1 instruction))))

(define-instruction $movereg
  (lambda (instruction as)
    (list-instruction "movereg" instruction)
    (emit-sassy as ia86.t_movereg
	       (operand1 instruction) (operand2 instruction))))

(define-instruction $return
  (lambda (instruction as)
    (list-instruction "return" instruction)
    (emit-sassy as ia86.t_return)))

(define-instruction $nop
  (lambda (instruction as)
    (list-instruction "nop" instruction)
    (emit-sassy as ia86.t_nop)))

; (define-instruction $save
;   (lambda (instruction as)
;     (if (not (negative? (operand1 instruction)))
;         (begin
;          (list-instruction "save" instruction)
; 	 (emit-sassy as 't_save (operand1 instruction))))))

(define-instruction $save
  (lambda (instruction as)
    (if (not (negative? (operand1 instruction)))
        (begin
	  (list-instruction "save" instruction)
	  (let* ((n (operand1 instruction)))
	    (emit-sassy as ia86.t_save0 n)
	    (do ((i 0 (+ i 1)))
		((= i (+ n 1)))
              (emit-sassy as ia86.t_save1 i)))))))

(define-instruction $save/stores
  (lambda (instruction as)
    (list-instruction "save/stores" instruction)
    (let* ((n (operand1 instruction))
           (ks (operand2 instruction))
           (ns (operand3 instruction))
           (v (make-vector (+ n 1) 
                           (lambda ()
                             (emit-sassy as ia86.t_push_temp)))))
      (emit-sassy as ia86.t_check_save n)
      ;; setup zeroed register; push PADWORD (sometimes)
      (emit-sassy as ia86.t_setup_save_stores n)
      ;; push REGs
      (for-each (lambda (k n) 
                  (vector-set! v n (lambda ()
                                     (emit-sassy as ia86.t_push_store k))))
                ks ns)
      (do ((i (- (vector-length v) 1) (- i 1)))
          ((= i -1))
        ((vector-ref v i)))
      ;; push CONTSIZE, RETADDR, DYNLINK
      (emit-sassy as ia86.t_finis_save_stores n)
      )))

(define-instruction $setrtn
  (lambda (instruction as)
    (list-instruction "setrtn" instruction)
    (emit-sassy as ia86.t_setrtn 
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $apply
  (lambda (instruction as)
    (list-instruction "apply" instruction)
    (emit-sassy as ia86.t_apply
	       (operand1 instruction)
	       (operand2 instruction))))

(define-instruction $jump
  (lambda (instruction as)
    (list-instruction "jump" instruction)
    (emit-sassy as ia86.t_jump
               (operand1 instruction)
               (operand2 instruction)
	       (compiled-procedure as (operand2 instruction)))))

(define-instruction $skip
  (lambda (instruction as)
    (list-instruction "skip" instruction)
    (emit-sassy as
                ia86.t_skip
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $branch
  (lambda (instruction as)
    (list-instruction "branch" instruction)
    (emit-sassy as
	       (if (find-label-locally as (operand1 instruction))
		   ia86.t_branch
		   ia86.t_skip)
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $branchf
  (lambda (instruction as)
    (list-instruction "branchf" instruction)
    (emit-sassy as 
	       (if (find-label-locally as (operand1 instruction))
		   ia86.t_branchf 
		   ia86.t_skipf)
	       (compiled-procedure as (operand1 instruction)))))

(define-instruction $check
  (lambda (instruction as)
    (list-instruction "check" instruction)
    (emit-sassy as ia86.t_check
               (operand1 instruction)
               (operand2 instruction)
               (operand3 instruction)
               (compiled-procedure as (operand4 instruction)))))

(define-instruction $trap
  (lambda (instruction as)
    (list-instruction "trap" instruction)
    (emit-sassy as ia86.t_trap
               (operand1 instruction)
               (operand2 instruction)
               (operand3 instruction)
               (operand4 instruction))))

(define-instruction $const/setreg
  (lambda (instruction as)
    (list-instruction "const/setreg" instruction)
    (if (immediate-constant? (operand1 instruction))
	(emit-sassy as ia86.t_const_setreg_imm 
		   (constant-value (operand1 instruction))
		   (operand2 instruction))
	(emit-sassy as ia86.t_const_setreg_constvector
		   (emit-datum as (operand1 instruction))
                   (operand2 instruction)))))

(define-instruction $const/setglbl
  (lambda (instruction as)
    (list-instruction "const/setglbl" instruction)
    (if (immediate-constant? (operand1 instruction))
	(emit-sassy as ia86.t_const_setglbl_imm 
		   (constant-value (operand1 instruction))
		   (emit-global as (operand2 instruction)))
	(emit-sassy as ia86.t_const_setglbl_constvector
		   (emit-datum as (operand1 instruction))
                   (emit-global as (operand2 instruction))))))

(define-instruction $global/invoke
  (lambda (instruction as)
    (list-instruction "global/invoke" instruction)
    (emit-sassy as ia86.t_global_invoke
                (emit-global as (operand1 instruction))
                (operand2 instruction))))

(define-instruction $global/setreg
  (lambda (instruction as)
    (list-instruction "global/setreg" instruction)
    (emit-sassy as ia86.t_global_setreg
                (emit-global as (operand1 instruction))
                (operand2 instruction))))

(define-instruction $setrtn/invoke
  (lambda (instruction as)
    (list-instruction "setrtn/invoke" instruction)
    (emit-sassy as ia86.t_setrtn_invoke (operand1 instruction))))

(define-instruction $setrtn/jump
  (lambda (instruction as)
    (list-instruction "setrtn/jump" instruction)
    (emit-sassy as ia86.t_setrtn_jump 
                (operand1 instruction) 
                (operand2 instruction))))

(define-instruction $setrtn/branch
  (lambda (instruction as)
    (list-instruction "setrtn/branch" instruction)
    (emit-sassy as 	      
                (if (find-label-locally as (operand1 instruction))
                    ia86.t_setrtn_branch
                    ia86.t_setrtn_skip)
                (compiled-procedure as (operand1 instruction)))))

(define-instruction $reg/setglbl
  (lambda (instruction as)
    (list-instruction "reg/setglbl" instruction)
    (emit-sassy as ia86.t_reg_setglbl 
                (operand1 instruction) 
                (emit-global as (operand2 instruction)))))

(define-instruction $reg/branchf
  (lambda (instruction as)
    (list-instruction "reg/branchf" instruction)
    (emit-sassy as ia86.t_reg_branchf
                (operand1 instruction) 
                (compiled-procedure as (operand2 instruction))
                (not (find-label-locally as (operand2 instruction))))))

(define-instruction $reg/check
  (lambda (instruction as)
    (list-instruction "reg/check" instruction)
    (emit-sassy as ia86.t_reg_check
                (operand1 instruction) 
                (compiled-procedure as (operand2 instruction)))))

(define-instruction $reg/op1/branchf
  (lambda (instruction as)
    (list-instruction "reg/op1/branchf" instruction)
    (emit-sassy as ia86.t_reg_op1_branchf
                (operand1 instruction)
                (operand2 instruction)
                (compiled-procedure as (operand3 instruction))
                (not (find-label-locally as (operand3 instruction))))))

(define-instruction $reg/op2/branchf
  (lambda (instruction as)
    (list-instruction "reg/op2/branchf" instruction)
    (emit-sassy as ia86.t_reg_op2_branchf
                (operand1 instruction)
                (operand2 instruction)
                (operand3 instruction)
                (compiled-procedure as (operand4 instruction))
                (not (find-label-locally as (operand4 instruction))))))

(define-instruction $reg/op2imm/branchf
  (lambda (instruction as)
    (list-instruction "reg/op2imm/branchf" instruction)
    (emit-sassy as ia86.t_reg_op2imm_branchf
                (operand1 instruction)
                (operand2 instruction)
                (constant-value (operand3 instruction))
                (compiled-procedure as (operand4 instruction))
                (not (find-label-locally as (operand4 instruction))))))

(define-instruction $reg/op1/setreg
  (lambda (instruction as)
    (list-instruction "reg/op1/setreg" instruction)
    (emit-sassy as ia86.t_op1* 
                (operand1 instruction)
                (operand2 instruction)
                (operand3 instruction))))

(define-instruction $reg/op2/setreg
  (lambda (instruction as)
    (list-instruction "reg/op2/setreg" instruction)
    (emit-sassy as ia86.t_op2* 
                (operand1 instruction)
                (operand2 instruction)
                (operand3 instruction)
                (operand4 instruction))))

(define-instruction $reg/op2imm/setreg
  (lambda (instruction as)
    (list-instruction "reg/op2imm/setreg" instruction)
    (emit-sassy as ia86.t_op2imm* 
                (operand1 instruction)
                (operand2 instruction)
                (constant-value (operand3 instruction))
                (operand4 instruction))))

(define-instruction $reg/op1/check
  (lambda (instruction as)
    (list-instruction "reg/op1/check" instruction)
    (emit-sassy as ia86.t_reg_op1_check
                (operand1 instruction)
                (operand2 instruction)
                (compiled-procedure as (operand3 instruction)))))

(define-instruction $reg/op2/check
  (lambda (instruction as)
    (list-instruction "reg/op2/check" instruction)
    (emit-sassy as ia86.t_reg_op2_check
                (operand1 instruction)
                (operand2 instruction)
                (operand3 instruction)
                (compiled-procedure as (operand4 instruction)))))

(define-instruction $reg/op2imm/check
  (lambda (instruction as)
    (list-instruction "reg/op2imm/check" instruction)
    (emit-sassy as ia86.t_reg_op2imm_check
                (operand1 instruction)
                (operand2 instruction)
                (constant-value (operand3 instruction))
                (compiled-procedure as (operand4 instruction)))))

(define-instruction $reg/op2imm/check
  (lambda (instruction as)
    (list-instruction "reg/op2imm/check" instruction)
    (emit-sassy as ia86.t_reg_op2imm_check
                (operand1 instruction)
                (operand2 instruction)
                (constant-value (operand3 instruction))
                (compiled-procedure as (operand4 instruction)))))

(define-instruction $reg/op3
  (lambda (instruction as)
    (list-instruction "reg/op3" instruction)
    (emit-sassy as ia86.t_reg_op3
                (operand1 instruction)
                (operand2 instruction)
                (operand3 instruction)
                (operand4 instruction))))

(define-instruction $.asm
  (lambda (instruction as)
    (list-instruction "$.asm" instruction)
    (for-each (lambda (asminst)
                (apply emit-sassy as asminst))
              (cdr instruction))))

; Helper procedures.

(define symbolic-label-cache #f)
(define (reset-symbolic-label-cache!)
  (set! symbolic-label-cache 
        (make-vector 2048 #f)))
(define (grow-symbolic-label-cache label)
  (let ((target-length (do ((n (* 2 (vector-length symbolic-label-cache))
                               (* 2 n)))
                           ((> n label) n))))
    (let ((new-cache (make-vector target-length #f)))
      (do ((i 0 (+ i 1)))
          ((>= i (vector-length symbolic-label-cache)))
        (vector-set! new-cache i
                     (vector-ref symbolic-label-cache i)))
      (set! symbolic-label-cache new-cache))))
(define (symbolic-label-cache-get label fail-thunk)
  (cond ((>= label (vector-length symbolic-label-cache))
         (grow-symbolic-label-cache label)))
  (cond ((vector-ref symbolic-label-cache label))
        (else
         (let ((val (fail-thunk)))
           (vector-set! symbolic-label-cache label val)
           val))))

(define (compiled-procedure as label)
  (symbolic-label-cache-get 
   label
   (lambda ()
     '(begin (display `(compiled-procedure as ,label))
             (newline))
     (string->symbol 
      (twobit-format #f "compiled_start_~a_~a" 
                     (user-data.toplevel-counter (as-user as))
                     label)))))

(define (immediate-constant? x)
  (or (fixnum? x)
      (null? x)
      (boolean? x)
      (char? x)
      (eof-object? x)
      (equal? x (unspecified))
      (equal? x (undefined))))

(define (constant-value x)
  (define (char n)
    (fxlogior (fxlsh (char->integer n) $bitwidth.char-shift) $imm.character))

  (define (exact-int->fixnum x)
    (* x 4))

  (define (char->immediate c)
    (+ (* (char->integer c) 65536) $imm.character))

  (cond ((fixnum? x)              (fixnum x))
        ((eq? x #t)               $imm.true)
        ((eq? x #f)               $imm.false)
        ((equal? x (eof-object))  $imm.eof)
        ((equal? x (unspecified)) $imm.unspecified)
        ((equal? x (undefined))   $imm.undefined)
        ((null? x)                $imm.null)
        ((char? x)                (char x))
        ((not (immediate-constant? x)) 
         (error 'constant-value 
                "you can only pass immediate constants!"))	
        (else ???)))

(define (new-proc-id as)
  (let* ((u (as-user as))
	 (x (user-data.proc-counter u)))
    (user-data.proc-counter! u (+ 1 x))
    x))

; eof
