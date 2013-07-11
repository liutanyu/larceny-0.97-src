; Copyright 1998 Lars T Hansen.
;
; $Id: peepopt.sch 5497 2008-05-31 15:05:54Z pnkfelix $
;
; 14 March 2002.
;
; Asm/Standard-C/peepopt.sch -- MAL peephole optimizer, for the Standard-C assembler.
;
; The procedure `peep' is called on the as structure before every
; instruction is assembled.  It may replace the prefix of the instruction
; stream by some other instruction sequence.
;
; Invariant: if the peephole optimizer doesn't change anything, then 
;
;  (let ((x (as-source as)))
;    (peep as)
;    (eq? x (as-source as)))     => #t
;
; Note this still isn't right -- it should be integrated with pass5p2 --
; but it's a step in the right direction.

(define *peephole-table* (make-vector *number-of-mnemonics* #f))

(define (define-peephole n p)
  (vector-set! *peephole-table* n p)
  (unspecified))

(define (peep as)
  (let ((t0 (as-source as)))
    (if (not (null? t0))
        (let ((i1 (car t0)))
          (let ((p (vector-ref *peephole-table* (car i1))))
            (if p
                (let* ((t1 (if (null? t0) t0 (cdr t0)))
                       (i2 (if (null? t1) '(-1 0 0 0) (car t1)))
                       (t2 (if (null? t1) t1 (cdr t1)))
                       (i3 (if (null? t2) '(-1 0 0 0) (car t2)))
                       (t3 (if (null? t2) t2 (cdr t2))))
                  (p as i1 i2 i3 t1 t2 t3))))))))

(define-peephole $reg
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $op1)
           (let ((src1 (as-source as)))
             ;; Attempt instruction merge
             (cond ((= (car i3) $check)
                    (reg-op1-check as i1 i2 i3 t3))
                   ((= (car i3) $setreg)
                    (reg-op1-setreg as i1 i2 i3 t3)))
             ;; Check if merge failed
             (let ((src2 (as-source as)))
               (cond ((eq? src1 src2)
                      (reg-op1 as i1 i2 t2))))))
          ((= (car i2) $op2)
           (let ((src1 (as-source as)))
             ;; Attempt instruction merge
             (cond ((= (car i3) $check)
                    (reg-op2-check as i1 i2 i3 t3))
                   ((= (car i3) $setreg)
                    (reg-op2-setreg as i1 i2 i3 t3))
                   ((= (car i3) $branchf)
                    (reg-op2-branchf as i1 i2 i3 t3)))
             ;; Check if merge failed
             (let ((src2 (as-source as)))
               (cond ((eq? src1 src2)
                      (reg-op2 as i1 i2 t2))))))
          ((= (car i2) $op2imm)
           (let ((src1 (as-source as)))
             ;; Attempt instruction merge
             (cond ((= (car i3) $check)
                    (reg-op2imm-check as i1 i2 i3 t3))
                   ((= (car i3) $branchf)
                    (reg-op2imm-branchf as i1 i2 i3 t3))
                   ((= (car i3) $setreg)
                    (reg-op2imm-setreg as i1 i2 i3 t3)))
             ;; Check if merge failed
             (let ((src2 (as-source as)))
               (cond ((eq? src1 src2)
                      (reg-op2imm as i1 i2 t2))))))
          ((= (car i2) $setreg)
           (reg-setreg as i1 i2 t2)))))

(define-peephole $op1
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $branchf)
           (op1-branchf as i1 i2 t2))
          ((= (car i2) $check)
           (op1-check as i1 i2 t2)))))

(define-peephole $op2
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $branchf)
           (op2-branchf as i1 i2 t2))
          ((= (car i2) $check)
           (op2-check as i1 i2 t2)))))

(define-peephole $op2imm
  (lambda (as i1 i2 i3 t1 t2 t3)
    (let ((src1 (as-source as)))
      ;; Attempt instruction merge
      (cond ((= (car i2) $branchf)
             (op2imm-branchf as i1 i2 t2))
            ((= (car i2) $check)
             (op2imm-check as i1 i2 t2))
            ((= (car i2) $setreg)
             (op2imm-setreg as i1 i2 t2)))
      ;; Check if merge failed
      (let ((src2 (as-source as)))
        (cond ((eq? src1 src2)
               (op2imm-int32 as i1 t1)))))))

(define-peephole $const
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $op2)
           (const-op2 as i1 i2 t2))
          ((= (car i2) $setreg)
           (const-setreg as i1 i2 t2)))))

(define-peephole $branch
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $.align)
           (cond ((= (car i3) $.label)
                  (branch-and-label as i1 i2 i3 t3)))))))

(define-peephole $reg/op1/check
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $reg)
           (cond ((= (car i3) $op1)
                  (if (not (null? t3))
                      (let ((i4 (car t3))
                            (t4 (cdr t3)))
                        (cond ((= (car i4) $setreg)
                               (reg/op1/check-reg-op1-setreg
                                as i1 i2 i3 i4 t4)))))))))))

(define-peephole $reg/op2/check
  (lambda (as i1 i2 i3 t1 t2 t3)
    (cond ((= (car i2) $reg)
           (cond ((= (car i3) $op2imm)
                  (if (not (null? t3))
                      (let ((i4 (car t3))
                            (t4 (cdr t3)))
                        (cond ((= (car i4) $check)
                               (reg/op2/check-reg-op2imm-check
                                as i1 i2 i3 i4 t4)))))))))))

(define-peephole $save
  (lambda (as i1 i2 i3 t1 t2 t3)
    (let loop ((instrs t1)
               (rev-stores '()))
      (cond
       ((and (not (null? rev-stores))
             (= (operand1 (car rev-stores))
                (operand1 i1)))
        (save-storem-uniform as (operand1 i1) instrs))
       ((and (eqv? $store (operand0 (car instrs)))
             (= (operand1 (car instrs)) (operand2 (car instrs))))
        (loop (cdr instrs) (cons (car instrs) rev-stores)))
       ))))

(define-peephole $load
  (lambda (as i1 i2 i3 t1 t2 t3)
    (if (= 1 (operand1 i1) (operand2 i1))
        (let loop ((instrs t1)
                   (k 1)
                   (replaced (list i1)))
          (cond ((and (eqv? $load (operand0 (car instrs)))
                      (= (+ k 1) (operand1 (car instrs)) (operand2 (car instrs))))
                 (loop (cdr instrs) (+ k 1) (cons (car instrs) replaced)))
                ((> k 1) ; don't do the xform on just (load 1 1)
                 (loadm-uniform as k instrs)))))))

; Worker procedures.

(define (op1-impcont i) ; instruction -> [Maybe fixnum]
  (if (op1-implicit-continuation? (operand1 i)) (operand2 i) #f))
(define (op2-impcont i) ; instruction -> [Maybe fixnum]
  (if (op2-implicit-continuation? (operand1 i)) (operand3 i) #f))
(define (op3-impcont i) ; instruction -> [Maybe fixnum]
  (if (op3-implicit-continuation? (operand1 i)) (operand4 i) #f))

(define (op1-branchf as i:op1 i:branchf tail)
  (let* ((op (operand1 i:op1))
	 (l  (operand1 i:branchf)))
    (peep-reg/op1/branchf as op 'result l (op1-impcont i:op1) tail)))

(define (reg-op1-branchf as i:reg i:op1 i:branchf tail)
  (let* ((rs (operand1 i:reg))
         (op (operand1 i:op1))
	 (l  (operand1 i:branchf)))
    (peep-reg/op1/branchf as op rs l (op1-impcont i:op1) tail)))

(define (peep-reg/op1/branchf as op rs l impcont tail)
  (let  ((op (case op
	       ((null?)       'internal:branchf-null?)
	       ((pair?)       'internal:branchf-pair?)
;	       ((zero?)       'internal:branchf-zero?)
	       ((eof-object?) 'internal:branchf-eof-object?)
	       ((fixnum?)     'internal:branchf-fixnum?)
	       ((char?)       'internal:branchf-char?)
	       ((fxzero?)     'internal:branchf-fxzero?)
;	       ((fxnegative?) 'internal:branchf-fxnegative?)
;	       ((fxpositive?) 'internal:branchf-fxpositive?)
	       (else #f))))
    (if op
        (as-source! as (cons (list $reg/op1/branchf op rs l impcont) tail)))))

(define (reg-op2-branchf as i:reg i:op2 i:branchf tail)
  (let* ((rs1 (operand1 i:reg))
         (op  (operand1 i:op2))
	 (rs2 (operand2 i:op2))
	 (l   (operand1 i:branchf)))
    (peep-reg/op2/branchf as op rs1 rs2 l tail)))

(define (op2-branchf as i:op2 i:branchf tail)
  (let* ((op  (operand1 i:op2))
	 (rs2 (operand2 i:op2))
	 (l   (operand1 i:branchf)))
    (peep-reg/op2/branchf as op 'result rs2 l tail)))

(define (reg-op2imm-branchf as i:reg i:op2imm i:branchf tail)
  (let* ((rs  (operand1 i:reg))
         (op  (operand1 i:op2imm))
         (imm (operand2 i:op2imm))
         (l   (operand1 i:branchf)))
    (peep-reg/op2imm/branchf as op rs imm l tail)))

(define (op2imm-branchf as i:op2imm i:branchf tail)
  (let* ((op  (operand1 i:op2imm))
	 (imm (operand2 i:op2imm))
	 (l   (operand1 i:branchf)))
    (peep-reg/op2imm/branchf as op 'result imm l tail)))

(define (peep-reg/op2imm/branchf as op rs imm l1 tail)
  (let ((op   (case op
                ((eq?)     (if (fixnum? imm)
                                'internal:branchf-eq?/imm-int32
                                #f))
		((char=?)  (if (char? imm)
                               'internal:branchf-char=?/imm-char
                               #f))
;		((char>=?) 'internal:branchf-char>=?/imm)
;		((char>?)  'internal:branchf-char>?/imm)
;		((char<=?) 'internal:branchf-char<=?/imm)
;		((char<?)  'internal:branchf-char<?/imm)
;		((fx=)     'internal:branchf-fx=/imm)
;		((fx>)     'internal:branchf-fx>/imm)
;		((fx>=)    'internal:branchf-fx>=/imm)
		((fx<)     (if (fixnum? imm)
                               'internal:branchf-fx</imm-int32
                               #f))
;		((fx<=)    'internal:branchf-fx<=/imm)
		((=:fix:fix) (if (fixnum? imm)
                                 'internal:branchf-=:fix:fix/imm-int32
                                 #f))
		((<:fix:fix) (if (fixnum? imm)
                                 'internal:branchf-<:fix:fix/imm-int32
                                 #f))
		(else #f))))
    (if op
        (as-source! as
                    (cons (list $reg/op2imm/branchf op rs imm l1)
                          tail)))))

(define (op2imm-int32 as i:op2imm tail)
  (let* ((op (operand1 i:op2imm))
         (imm (operand2 i:op2imm)))
    (peep-reg/op2imm/setreg as op 'result imm 'result (op2-impcont i:op2imm) tail)))

(define (reg-op2imm as i:reg i:op2imm tail)
  (let* ((rs (operand1 i:reg))
         (op (operand1 i:op2imm))
         (imm (operand2 i:op2imm)))
    (peep-reg/op2imm/setreg as op rs imm 'result (op2-impcont i:op2imm) tail)))

(define (op2imm-setreg as i:op2imm i:setreg tail)
  (let* ((op (operand1 i:op2imm))
         (imm (operand2 i:op2imm))
         (rd (operand1 i:setreg)))
    (peep-reg/op2imm/setreg as op 'result imm rd (op2-impcont i:op2imm) tail)))

(define (reg-op2imm-setreg as i:reg i:op2imm i:setreg tail)
  (let* ((rs (operand1 i:reg))
         (op (operand1 i:op2imm))
         (imm (operand2 i:op2imm))
         (rd (operand1 i:setreg)))
    (peep-reg/op2imm/setreg as op rs imm rd (op2-impcont i:op2imm) tail)))

(define (peep-reg/op2imm/setreg as op rs imm rd impcont tail)

  ;; XXX the logic here could be changed so that even non-int32
  ;; optimized variants get move-coalesced; but Felix does not know
  ;; how much of a win that is at that point...

  (let* ((op (cond ((fixnum? imm) 
                    (case op
                      ((eq?)       'eq?:int32)
                      ((+:idx:idx) '+:idx:idx:int32)
                      ((-:idx:idx) '-:idx:idx:int32)
                      ((fx<)       'fx<:int32)
                      ((>=:fix:fix) '>=:fix:fix:int32)
                      ((<:fix:fix)  '<:fix:fix:int32)
                      ((vector-ref:trusted) 'vector-ref:trusted:int32)
                      ((=)          '=:int32)
                      ((+)          '+:int32)
                      ((-)          '-:int32)
                      (else #f)))
                   ((char? imm)
                    (case op
                      ((char=?)    'char=?:char)
                      (else #f)))
                   (else #f))))
    (cond (op 
           (as-source! as (cons (list $reg/op2imm/setreg op rs rd imm impcont)
                                tail))))))

; Check optimization.

(define (reg-op1-check as i:reg i:op1 i:check tail)
  (let ((rs (operand1 i:reg))
        (op (operand1 i:op1)))
    (peep-reg/op1/check as
			op
			rs
			(operand4 i:check)
			(list (operand1 i:check)
			      (operand2 i:check)
			      (operand3 i:check))
			(op1-impcont i:op1)
			tail)))

(define (op1-check as i:op1 i:check tail)
  (let ((op (operand1 i:op1)))
    (peep-reg/op1/check as
                        op
                        'result
                        (operand4 i:check)
                        (list (operand1 i:check)
                              (operand2 i:check)
                              (operand3 i:check))
			(op1-impcont i:op1)
                        tail)))

(define (peep-reg/op1/check as op rs l1 liveregs impcont tail)
  (let ((op (case op
              ((fixnum?)      'internal:check-fixnum?)
              ((pair?)        'internal:check-pair?)
              ((vector?)      'internal:check-vector?)
              ((string?)      'internal:check-string?)
              (else #f))))
    (if op
        (as-source! as
                    (cons (list $reg/op1/check op rs l1 liveregs impcont)
                          tail)))))

(define (reg-op2-check as i:reg i:op2 i:check tail)
  (let ((rs1 (operand1 i:reg))
        (rs2 (operand2 i:op2))
        (op (operand1 i:op2)))
    (peep-reg/op2/check as
			op
			rs1
			rs2
			(operand4 i:check)
			(list (operand1 i:check)
			      (operand2 i:check)
			      (operand3 i:check))
			(op2-impcont i:op2)
			tail)))

(define (op2-check as i:op2 i:check tail)
  (let ((rs2 (operand2 i:op2))
        (op (operand1 i:op2)))
    (peep-reg/op2/check as
                        op
                        'result
                        rs2
                        (operand4 i:check)
                        (list (operand1 i:check)
                              (operand2 i:check)
                              (operand3 i:check))
			(op2-impcont i:op2)
                        tail)))

(define (peep-reg/op2/check as op rs1 rs2 l1 liveregs impcont tail)
  (let ((op (case op
;              ((<:fix:fix)   'internal:check-<:fix:fix)
;              ((<=:fix:fix)  'internal:check-<=:fix:fix)
;              ((>=:fix:fix)  'internal:check->=:fix:fix)
              (else #f))))
    (if op
        (as-source! as
                    (cons (list $reg/op2/check op rs1 rs2 l1 liveregs impcont)
                          tail)))))

(define (peep-reg/op2/branchf as op rs1 rs2 l1 tail)
  (let ((op (case op
              ((eq?)          'internal:branchf-eq?)
              (else #f))))
    (if op
        (as-source! as
                    (cons (list $reg/op2/branchf op rs1 rs2 l1)
                          tail)))))

(define (reg-op2imm-check as i:reg i:op2imm i:check tail)
  (let ((rs1 (operand1 i:reg))
        (op (operand1 i:op2imm))
        (imm (operand2 i:op2imm)))
    (peep-reg/op2imm/check as
			   op
			   rs1
			   imm
			   (operand4 i:check)
			   (list (operand1 i:check)
				 (operand2 i:check)
				 (operand3 i:check))
			   (op2-impcont i:op2imm)
			   tail)))

(define (op2imm-check as i:op2imm i:check tail)
  (let ((op (operand1 i:op2imm))
        (imm (operand2 i:op2imm)))
    (peep-reg/op2imm/check as
                           op
                           'result
                           imm
                           (operand4 i:check)
                           (list (operand1 i:check)
                                 (operand2 i:check)
                                 (operand3 i:check))
			   (op2-impcont i:op2imm)
                           tail)))

(define (peep-reg/op2imm/check as op rs1 imm l1 liveregs impcont tail)
  (let ((op (case op
;              ((<:fix:fix)   'internal:check-<:fix:fix/imm)
;              ((<=:fix:fix)  'internal:check-<=:fix:fix/imm)
;              ((>=:fix:fix)  'internal:check->=:fix:fix/imm)
              (else #f))))
    (if op
        (as-source! as
                    (cons (list $reg/op2imm/check op rs1 imm l1 liveregs impcont)
                          tail)))))

(define (reg/op1/check-reg-op1-setreg as i:ro1check i:reg i:op1 i:setreg tail)
  (let ((o1 (operand1 i:ro1check))
        (r1 (operand2 i:ro1check))
        (r2 (operand1 i:reg))
        (o2 (operand1 i:op1))
        (r3 (operand1 i:setreg)))
;    (if (and (eq? o1 'internal:check-vector?)
;             (eq? r1 r2)
;             (eq? o2 'vector-length:vec))
;        (as-source! as
;                    (cons (list $reg/op2/check
;                                'internal:check-vector?/vector-length:vec
;                                r1
;                                r3
;                                (operand3 i:ro1check)
;                                (operand4 i:ro1check))
;                          tail)))
;    (if (and (eq? o1 'internal:check-string?)
;             (eq? r1 r2)
;             (eq? o2 'string-length:str))
;        (as-source! as
;                    (cons (list $reg/op2/check
;                                'internal:check-string?/string-length:str
;                                r1
;                                r3
;                                (operand3 i:ro1check)
;                                (operand4 i:ro1check))
;                          tail)))
    (unspecified) ))

; Range checks of the form 0 <= i < n can be performed by a single check.
; This peephole optimization recognizes
;         reg     rs1
;         op2     <:fix:fix,rs2
;         check   r1,r2,r3,L
;         reg     rs1                     ; must match earlier reg
;         op2imm  >=:fix:fix,0
;         check   r1,r2,r3,L              ; label must match earlier check

(define (reg/op2/check-reg-op2imm-check
         as i:ro2check i:reg i:op2imm i:check tail)
  (let ((o1   (operand1 i:ro2check))
        (rs1  (operand2 i:ro2check))
        (rs2  (operand3 i:ro2check))
        (l1   (operand4 i:ro2check))
        (live (operand5 i:ro2check))
        (rs3  (operand1 i:reg))
        (o2   (operand1 i:op2imm))
        (x    (operand2 i:op2imm))
        (l2   (operand4 i:check)))
;    (if (and (eq? o1 'internal:check-<:fix:fix)
;             (eq? o2 '>=:fix:fix)
;             (eq? rs1 rs3)
;             (eq? x 0)
;             (eq? l1 l2))
;        (as-source! as
;                    (cons (list $reg/op2/check 'internal:check-range
;                                                rs1 rs2 l1 live)
;                          tail)))
    (unspecified)))

; End of check optimization.

; Reg-setreg is not restricted to hardware registers, as $movereg is 
; a standard instruction.

(define (reg-setreg as i:reg i:setreg tail)
  (let ((rs (operand1 i:reg))
        (rd (operand1 i:setreg)))
    (if (= rs rd)
        (as-source! as tail)
        (as-source! as (cons (list $movereg rs rd) tail)))))

(define (const-setreg as i:const i:setreg tail)
  (let ((cs (operand1 i:const))
        (rd (operand1 i:setreg)))
    (as-source! as (cons (list $const/setreg cs rd) tail))))

(define (reg-op1 as i:reg i:op tail)
  (let* ((rs (operand1 i:reg))
         (op (operand1 i:op))
         (rd 'result))
    (peep-reg/op1/setreg as op rs rd (op1-impcont i:op) tail)))

(define (reg-op1-setreg as i:reg i:op i:setreg tail)
  (let* ((rs (operand1 i:reg))
         (op (operand1 i:op))
         (rd (operand1 i:setreg)))
    (peep-reg/op1/setreg as op rs rd (op1-impcont i:op) tail)))

(define (peep-reg/op1/setreg as op rs rd impcont tail)
  (let ((op (case op
              ((car:pair)      'car:pair)
              ((cdr:pair)      'cdr:pair)
              ((char->integer) 'char->integer)
              ((vector-length:vec) 'vector-length:vec)
              ((char?)         'char?)
              ((cell-ref)      'cell-ref)
              (else #f))))
    (if op
        (as-source! as
                    (cons (list $reg/op1/setreg op rs rd impcont)
                          tail)))))

(define (reg-op2 as i:reg i:op2 tail)
  (let* ((rs1 (operand1 i:reg))
         (rs2 (operand2 i:op2))
         (op (operand1 i:op2))
         (rd 'result))
    (peep-reg/op2/setreg as op rs1 rs2 rd (op2-impcont i:op2) tail)))

(define (reg-op2-setreg as i:reg i:op2 i:setreg tail)
  (let* ((rs1 (operand1 i:reg))
         (rs2 (operand2 i:op2))
         (op (operand1 i:op2))
         (rd (operand1 i:setreg)))
    (peep-reg/op2/setreg as op rs1 rs2 rd (op2-impcont i:op2) tail)))

(define (peep-reg/op2/setreg as op rs1 rs2 rd impcont tail)
  (let ((op (case op
              ((cons) 'cons)
              ((eq?) 'eq?)
              (else #f))))
    (if op
        (as-source! as (cons (list $reg/op2/setreg op rs1 rd rs2 impcont) tail)))))

; Make-vector on vectors of known short length.

(define (const-op2 as i:const i:op2 tail)
  (let ((vn '#(make-vector:0 make-vector:1 make-vector:2 make-vector:3
               make-vector:4 make-vector:5 make-vector:6 make-vector:7
               make-vector:8 make-vector:9))
        (c  (operand1 i:const))
        (op (operand1 i:op2))
        (r  (operand2 i:op2)))
;    (if (and (eq? op 'make-vector)
;             (fixnum? c)
;             (<= 0 c 9))
;        (as-source! as (cons (list $op2 (vector-ref vn c) r) tail)))
    (unspecified) ))

; Gets rid of spurious branch-to-next-instruction
;    (branch Lx k)
;    (.align y)
;    (.label Lx)
; => (.align y)
;    (.label Lx)

(define (branch-and-label as i:branch i:align i:label tail)
  (let ((branch-label (operand1 i:branch))
        (label        (operand1 i:label)))
    (if (= branch-label label)
        (as-source! as (cons i:align (cons i:label tail))))))

; Compresses a common save+store sequence into single runtime call
;    (save k)
;    (store 0 0)
;    (store 1 1)  ;; n.b. all indices must match 
;    ...
;    (store k k)
; => (save/storem-uniform k)

(define (save-storem-uniform as save-n tail)
  (as-source! as (cons (list $save/storem-uniform save-n) tail)))

; Compresses a common load sequence into a single runtime call
;    (load 1 1)
;    (load 2 2)
;    ...
;    (load k k)
; => (loadm-uniform k)

(define (loadm-uniform as k tail)
  (as-source! as (cons (list $loadm-uniform k) tail)))

; Test code

(define (peeptest istream)
  (let ((as (make-assembly-structure istream)))
    (let loop ((l '()))
      (if (null? (as-source as))
          (reverse l)
          (begin (peep as)
                 (let ((a (car (as-source as))))
                   (as-source! as (cdr (as-source as)))
                   (loop (cons a l))))))))


; eof
