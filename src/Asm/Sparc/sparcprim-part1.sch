; Copyright 1998 Lars T Hansen.
; 
; $Id: sparcprim-part1.sch 6133 2009-03-14 14:52:24Z will $
;
; 22 April 1999 / wdc
;
; SPARC code generation macros for primitives, part 1:
;   primitives defined in Compiler/sparc.imp.sch.

; These extend Asm/Common/pass5p1.sch.

(define (operand5 instruction)
  (car (cddddr (cdr instruction))))

(define (operand6 instruction)
  (cadr (cddddr (cdr instruction))))

(define (operand7 instruction)
  (caddr (cddddr (cdr instruction))))


; Primop emitters.

(define (emit-primop.1arg! as op)
  ((find-primop op) as))

(define (emit-primop.2arg! as op r)
  ((find-primop op) as r))

(define (emit-primop.3arg! as a1 a2 a3)
  ((find-primop a1) as a2 a3))

(define (emit-primop.4arg! as a1 a2 a3 a4)
  ((find-primop a1) as a2 a3 a4))

(define (emit-primop.5arg! as a1 a2 a3 a4 a5)
  ((find-primop a1) as a2 a3 a4 a5))

(define (emit-primop.6arg! as a1 a2 a3 a4 a5 a6)
  ((find-primop a1) as a2 a3 a4 a5 a6))

(define (emit-primop.7arg! as a1 a2 a3 a4 a5 a6 a7)
  ((find-primop a1) as a2 a3 a4 a5 a6 a7))


; Hash table of primops

(define primop-vector (make-vector 256 '()))

(define (define-primop name proc)
  (let ((h (fxlogand (symbol-hash name) 255)))
    (vector-set! primop-vector h (cons (cons name proc)
				       (vector-ref primop-vector h)))
    name))

(define (find-primop name)
  (let ((h (fxlogand (symbol-hash name) 255)))
    (cdr (assq name (vector-ref primop-vector h)))))

(define (for-each-primop proc)
  (do ((i 0 (+ i 1)))
      ((= i (vector-length primop-vector)))
    (for-each (lambda (p)
                (proc (cdr p)))
              (vector-ref primop-vector i))))

; Primops

(define-primop 'unspecified
  (lambda (as)
    (emit-immediate->register! as $imm.unspecified $r.result)))

(define-primop 'undefined
  (lambda (as)
    (emit-immediate->register! as $imm.undefined $r.result)))

(define-primop 'eof-object
  (lambda (as)
    (emit-immediate->register! as $imm.eof $r.result)))

(define-primop 'enable-interrupts
  (lambda (as)
    (millicode-call/0arg as $m.enable-interrupts)))

(define-primop 'disable-interrupts
  (lambda (as)
    (millicode-call/0arg as $m.disable-interrupts)))

(define-primop 'gc-counter
  (lambda (as)
    (sparc.ldi as $r.globals $g.gccnt $r.result)))

(define-primop 'major-gc-counter
  (lambda (as)
    (sparc.ldi as $r.globals $g.majorgccnt $r.result)))

; Works on all objects, not just tagged pointers.

(define-primop 'machine-address
  (lambda (as)
    (sparc.andi as $r.result -16 $r.result)
    (sparc.srli as $r.result 2 $r.result)))

(define-primop 'zero?
  (lambda (as)
    (emit-cmp-primop! as sparc.be.a $m.zerop $r.g0)))

(define-primop '=
  (lambda (as r)
    (emit-cmp-primop! as sparc.be.a $m.numeq r)))

(define-primop '<
  (lambda (as r)
    (emit-cmp-primop! as sparc.bl.a $m.numlt r)))

(define-primop '<=
  (lambda (as r)
    (emit-cmp-primop! as sparc.ble.a $m.numle r)))

(define-primop '>
  (lambda (as r)
    (emit-cmp-primop! as sparc.bg.a $m.numgt r)))

(define-primop '>=
  (lambda (as r)
    (emit-cmp-primop! as sparc.bge.a $m.numge r)))

(define-primop 'complex?
  (lambda (as)
    (millicode-call/0arg as $m.complexp)))

(define-primop 'real?
  (lambda (as)
    (millicode-call/0arg as $m.realp)))

(define-primop 'rational?
  (lambda (as)
    (millicode-call/0arg as $m.rationalp)))

(define-primop 'integer?
  (lambda (as)
    (millicode-call/0arg as $m.integerp)))

(define-primop 'exact?
  (lambda (as)
    (millicode-call/0arg as $m.exactp)))

(define-primop 'inexact?
  (lambda (as)
    (millicode-call/0arg as $m.inexactp)))

(define-primop 'fixnum?
  (lambda (as)
    (sparc.btsti as $r.result 3)
    (emit-set-boolean! as)))

(define-primop '+
  (lambda (as r)
    (emit-primop.4arg! as 'internal:+ $r.result r $r.result)))

(define-primop '-
  (lambda (as r)
    (emit-primop.4arg! as 'internal:- $r.result r $r.result)))

(define-primop '*
  (lambda (as rs2)
    (emit-multiply-code as rs2 #f)))

(define (emit-multiply-code as rs2 fixnum-arithmetic?)
  (if (and (unsafe-code) fixnum-arithmetic?)
      (begin
	(sparc.srai    as $r.result 2 $r.tmp0)
	(sparc.smulr   as $r.tmp0 rs2 $r.result))
      (let ((rs2    (force-hwreg! as rs2 $r.argreg2))
	    (Lstart (new-label))
	    (Ltagok (new-label))
	    (Loflo  (new-label))
	    (Ldone  (new-label)))
	(sparc.label   as Lstart)
	(sparc.orr     as $r.result rs2 $r.tmp0)
	(sparc.btsti   as $r.tmp0 3)
	(sparc.be.a    as Ltagok)
	(sparc.srai    as $r.result 2 $r.tmp0)
	(sparc.label   as Loflo)
	(if (not (= rs2 $r.argreg2)) (sparc.move as rs2 $r.argreg2))
	(if (not fixnum-arithmetic?)
	    (begin
	      (millicode-call/ret as $m.multiply Ldone))
	    (begin
	      (sparc.set as (thefixnum $ex.fx*) $r.tmp0)
	      (millicode-call/ret as $m.exception Lstart)))
	(sparc.label   as Ltagok)
	(sparc.smulr   as $r.tmp0 rs2 $r.tmp0)
	(sparc.rdy     as $r.tmp1)
	(sparc.srai    as $r.tmp0 31 $r.tmp2)
	(sparc.cmpr    as $r.tmp1 $r.tmp2)
	(sparc.bne.a   as Loflo)
	(sparc.slot    as)
	(sparc.move    as $r.tmp0 $r.result)
	(sparc.label   as Ldone))))

(define-primop '/
  (lambda (as r)
    (millicode-call/1arg as $m.divide r)))

(define-primop 'quotient
  (lambda (as r)
    (millicode-call/1arg as $m.quotient r)))

(define-primop 'remainder
  (lambda (as r)
    (millicode-call/1arg as $m.remainder r)))

(define-primop '--
  (lambda (as)
    (emit-negate as $r.result $r.result)))

(define-primop 'round
  (lambda (as)
    (millicode-call/0arg as $m.round)))

(define-primop 'truncate
  (lambda (as)
    (millicode-call/0arg as $m.truncate)))

(define-primop 'fxlognot
  (lambda (as)
    (if (not (unsafe-code))
	(emit-assert-fixnum! as $r.result $ex.lognot))
    (sparc.ornr as $r.g0 $r.result $r.result)  ; argument order matters
    (sparc.xori as $r.result 3 $r.result)))

(define-primop 'fxlogand
  (lambda (as x)
    (logical-op as $r.result x $r.result sparc.andr $ex.logand)))

(define-primop 'fxlogior
  (lambda (as x)
    (logical-op as $r.result x $r.result sparc.orr $ex.logior)))

(define-primop 'fxlogxor
  (lambda (as x)
    (logical-op as $r.result x $r.result sparc.xorr $ex.logxor)))

; Fixnum shifts.
;
; Only positive shifts are meaningful.
; FIXME: These are incompatible with MacScheme and MIT Scheme.
; FIXME: need to return to start of sequence after fault.

(define-primop 'fxlsh
  (lambda (as x)
    (emit-shift-operation as $ex.lsh $r.result x $r.result)))

(define-primop 'fxrshl
  (lambda (as x)
    (emit-shift-operation as $ex.rshl $r.result x $r.result)))

(define-primop 'fxrsha
  (lambda (as x)
    (emit-shift-operation as $ex.rsha $r.result x $r.result)))


; fixnums only.
; FIXME: for symmetry with shifts there should be rotl and rotr (?)
;        or perhaps rot should only ever rotate one way.
; FIXME: implement.

(define-primop 'rot
  (lambda (as x)
    (asm-error "Sparcasm: ROT primop is not implemented.")))

(define-primop 'null?
  (lambda (as)
    (sparc.cmpi as $r.result $imm.null)
    (emit-set-boolean! as)))

(define-primop 'pair?
  (lambda (as)
    (emit-single-tagcheck->bool! as $tag.pair-tag)))

(define-primop 'eof-object?
  (lambda (as)
    (sparc.cmpi as $r.result $imm.eof)
    (emit-set-boolean! as)))

; Tests the specific representation, not 'flonum or compnum with 0i'.

(define-primop 'flonum?
  (lambda (as)
    (emit-double-tagcheck->bool! as $tag.bytevector-tag
				 (+ $imm.bytevector-header
				    $tag.flonum-typetag))))

(define-primop 'compnum?
  (lambda (as)
    (emit-double-tagcheck->bool! as $tag.bytevector-tag
				 (+ $imm.bytevector-header
				    $tag.compnum-typetag))))

(define-primop 'symbol?
  (lambda (as)
    (emit-double-tagcheck->bool! as $tag.vector-tag
				 (+ $imm.vector-header
				    $tag.symbol-typetag))))

(define-primop 'port?
  (lambda (as)
    (emit-double-tagcheck->bool! as $tag.vector-tag
				 (+ $imm.vector-header
				    $tag.port-typetag))))

(define-primop 'structure?
  (lambda (as)
    (emit-double-tagcheck->bool! as $tag.vector-tag
				 (+ $imm.vector-header
				    $tag.structure-typetag))))

(define-primop 'char?
  (lambda (as)
    (sparc.andi as $r.result #xFF $r.tmp0)
    (sparc.cmpi as $r.tmp0 $imm.character)
    (emit-set-boolean! as)))

(define flat1:string?
  (lambda (as)
    (emit-double-tagcheck->bool! as
				 $tag.bytevector-tag
				 (+ $imm.bytevector-header
				    $tag.string-typetag))))

(define flat4:string?
  (lambda (as)
    (emit-double-tagcheck->bool! as
				 $tag.bytevector-tag
				 (+ $imm.bytevector-header
				    $tag.ustring-typetag))))

(define-primop 'bytevector?
  (lambda (as)
    (emit-double-tagcheck->bool! as
				 $tag.bytevector-tag
				 (+ $imm.bytevector-header
				    $tag.bytevector-typetag))))

(define-primop 'bytevector-like?
  (lambda (as)
    (emit-single-tagcheck->bool! as $tag.bytevector-tag)))

(define-primop 'vector?
  (lambda (as)
    (emit-double-tagcheck->bool! as
				 $tag.vector-tag
				 (+ $imm.vector-header
				    $tag.vector-typetag))))

(define-primop 'vector-like?
  (lambda (as)
    (emit-single-tagcheck->bool! as $tag.vector-tag)))

(define-primop 'procedure?
  (lambda (as)
    (emit-single-tagcheck->bool! as $tag.procedure-tag)))

(define-primop 'cons
  (lambda (as r)
    (emit-primop.4arg! as 'internal:cons $r.result r $r.result)))

(define-primop 'car
  (lambda (as)
    (emit-primop.3arg! as 'internal:car $r.result $r.result)))

(define-primop 'cdr
  (lambda (as)
    (emit-primop.3arg! as 'internal:cdr $r.result $r.result)))

(define-primop 'car:pair
  (lambda (as)
    (sparc.ldi as $r.result (- $tag.pair-tag) $r.result)))

(define-primop 'cdr:pair
  (lambda (as)
    (sparc.ldi as $r.result (- 4 $tag.pair-tag) $r.result)))

(define-primop 'set-car!
  (lambda (as x)
    (if (not (unsafe-code))
	(emit-single-tagcheck-assert! as $tag.pair-tag $ex.car #f))
    (emit-setcar/setcdr! as $r.result x 0)))

(define-primop 'set-cdr!
  (lambda (as x)
    (if (not (unsafe-code))
	(emit-single-tagcheck-assert! as $tag.pair-tag $ex.cdr #f))
    (emit-setcar/setcdr! as $r.result x 4)))

; Cells are internal data structures, represented using pairs.
; No error checking is done on cell references.

(define-primop 'make-cell
  (lambda (as)
    (emit-primop.4arg! as 'internal:cons $r.result $r.g0 $r.result)))

(define-primop 'cell-ref
  (lambda (as)
    (emit-primop.3arg! as 'internal:cell-ref $r.result $r.result)))

(define-primop 'cell-set!
  (lambda (as r)
    (emit-setcar/setcdr! as $r.result r 0)))

(define-primop 'cell-set!:nwb
  (lambda (as r)
    (emit-setcar/setcdr-no-barrier! as $r.result r 0)))

(define-primop 'syscall
  (lambda (as)
    (millicode-call/0arg as $m.syscall)))

(define-primop 'break
  (lambda (as)
    (millicode-call/0arg as $m.break)))

(define-primop 'creg
  (lambda (as)
    (millicode-call/0arg as $m.creg)))

(define-primop 'creg-set!
  (lambda (as)
    (millicode-call/0arg as $m.creg-set!)))

(define-primop 'typetag
  (lambda (as)
    (millicode-call/0arg as $m.typetag)))

(define-primop 'typetag-set!
  (lambda (as r)
    (millicode-call/1arg as $m.typetag-set r)))

(define-primop 'exact->inexact
  (lambda (as)
    (millicode-call/0arg as $m.exact->inexact)))

(define-primop 'inexact->exact
  (lambda (as)
    (millicode-call/0arg as $m.inexact->exact)))

(define-primop 'real-part
  (lambda (as)
    (millicode-call/0arg as $m.real-part)))

(define-primop 'imag-part
  (lambda (as)
    (millicode-call/0arg as $m.imag-part)))

(define-primop 'char->integer
  (lambda (as)
    (if (not (unsafe-code))
	(emit-assert-char! as $ex.char2int #f))
    (sparc.srli as $r.result 6 $r.result)))

(define-primop 'integer->char
  (lambda (as)
    (if (not (unsafe-code))
        (let ((L0 (new-label))
              (L1 (new-label))
              (FAULT (new-label)))
          (sparc.label   as L0)
          ; Argument must be fixnum.
          (sparc.btsti   as $r.result 3)
          (sparc.bne     as FAULT)
          ; Argument cannot be a surrogate (#x0000d800 - #x0000dfff).
          (sparc.srai    as $r.result 13 $r.tmp0)
          (sparc.cmpi    as $r.tmp0 #b11011)
          (sparc.be      as FAULT)
          ; Argument must be non-negative and less than #x00110000.
          (sparc.cmpi    as $r.tmp0 544)
          (sparc.blu.a   as L1)
          (sparc.slli    as $r.result 6 $r.result)
          (sparc.label   as FAULT)
          (sparc.set     as (thefixnum $ex.int2char) $r.tmp0)
          (millicode-call/ret as $m.exception L0)
          (sparc.label   as L1)
          (sparc.ori     as $r.result $imm.character $r.result))
        (begin
          (sparc.slli as $r.result 6 $r.result)
          (sparc.ori  as $r.result $imm.character $r.result)))))

(define-primop 'integer->char:trusted
  (lambda (as)
    (sparc.slli as $r.result 6 $r.result)
    (sparc.ori  as $r.result $imm.character $r.result)))

(define-primop 'not
  (lambda (as)
    (sparc.cmpi as $r.result $imm.false)
    (emit-set-boolean! as)))

(define-primop 'eq?
  (lambda (as x)
    (emit-primop.4arg! as 'internal:eq? $r.result x $r.result)))

(define-primop 'eqv?
  (lambda (as x)
    (let ((tmp (force-hwreg! as x $r.tmp0))
	  (L1  (new-label)))
      (sparc.cmpr as $r.result tmp)
      (sparc.be.a as L1)
      (sparc.set  as $imm.true $r.result)
      (millicode-call/1arg as $m.eqv tmp)
      (sparc.label as L1))))

(define-primop 'make-bytevector
  (lambda (as)
    (if (not (unsafe-code))
	(emit-assert-positive-fixnum! as $r.result $ex.mkbvl))
    (emit-allocate-bytevector as
			      (+ $imm.bytevector-header
				 $tag.bytevector-typetag)
			      #f)
    (sparc.addi as $r.result $tag.bytevector-tag $r.result)))

(define-primop 'bytevector-fill!
  (lambda (as rs2)
    (let* ((fault (emit-double-tagcheck-assert! as
						$tag.bytevector-tag
						(+ $imm.bytevector-header
						   $tag.bytevector-typetag)
						$ex.bvfill
						rs2))
	   (rs2 (force-hwreg! as rs2 $r.argreg2)))
      (sparc.btsti  as rs2 3)
      (sparc.bne    as fault)
      (sparc.srai   as rs2 2 $r.tmp2)
      (sparc.ldi    as $r.result (- $tag.bytevector-tag) $r.tmp0)
      (sparc.addi   as $r.result (- 4 $tag.bytevector-tag) $r.tmp1)
      (sparc.srai   as $r.tmp0 8 $r.tmp0)
      (emit-bytevector-fill as $r.tmp0 $r.tmp1 $r.tmp2))))

(define-primop 'bytevector-length
  (lambda (as)
    (emit-get-length! as 
		      $tag.bytevector-tag
		      (+ $imm.bytevector-header $tag.bytevector-typetag)
		      $ex.bvlen
		      $r.result
		      $r.result)))

(define-primop 'bytevector-like-length
  (lambda (as)
    (emit-get-length! as
		      $tag.bytevector-tag
		      #f
		      $ex.bvllen
		      $r.result
		      $r.result)))

(define-primop 'bytevector-ref
  (lambda (as r)
    (let ((fault (if (not (unsafe-code))
		     (emit-double-tagcheck-assert!
		      as
		      $tag.bytevector-tag
		      (+ $imm.bytevector-header $tag.bytevector-typetag)
		      $ex.bvref
		      r)
		     #f)))
      (emit-bytevector-like-ref! as $r.result r $r.result fault #f #t))))

(define-primop 'bytevector-like-ref
  (lambda (as r)
    (let ((fault (if (not (unsafe-code))
		     (emit-single-tagcheck-assert! as
						   $tag.bytevector-tag
						   $ex.bvlref
						   r)
		     #f)))
      (emit-bytevector-like-ref! as $r.result r $r.result fault #f #f))))

(define-primop 'bytevector-set!
  (lambda (as r1 r2)
    (let ((fault (if (not (unsafe-code))
		     (emit-double-tagcheck-assert!
		      as
		      $tag.bytevector-tag
		      (+ $imm.bytevector-header $tag.bytevector-typetag)
		      $ex.bvset
		      r1)
		     #f)))
      (emit-bytevector-like-set! as r1 r2 fault #t))))

(define-primop 'bytevector-like-set!
  (lambda (as r1 r2)
    (let ((fault (if (not (unsafe-code))
		     (emit-single-tagcheck-assert! as
						   $tag.bytevector-tag
						   $ex.bvlset
						   r1)
		     #f)))
      (emit-bytevector-like-set! as r1 r2 fault #f))))

(define-primop 'sys$bvlcmp
  (lambda (as x)
    (millicode-call/1arg as $m.bvlcmp x)))

; FIXME: these trusted operations should replace
; the untrusted operations above.

(define-primop 'bytevector-like-length:bvl
  (lambda (as)
    (emit-get-length-trusted! as 
                              $tag.bytevector-tag
                              $r.result
                              $r.result)))

(define-primop 'bytevector-like-ref:trusted
  (lambda (as r)
    (emit-bytevector-like-ref-trusted! as $r.result r $r.result #f)))

(define-primop 'bytevector-like-set!:trusted
  (lambda (as r1 r2)
    (emit-bytevector-like-set-trusted! as r1 r2)))

; Strings

; RESULT must have nonnegative fixnum.
; RS2 must have character.

(define flat1:make-string
  (lambda (as rs2)
    (let ((FAULT (new-label))
	  (START (new-label)))
      (sparc.label as START)
      (let ((rs2 (force-hwreg! as rs2 $r.argreg2)))
	(if (not (unsafe-code))
	    (let ((L1 (new-label))
		  (L2 (new-label)))
	      (sparc.tsubrcc as $r.result $r.g0 $r.g0)
	      (sparc.bvc.a   as L1)
	      (sparc.andi    as rs2 255 $r.tmp0)
	      (sparc.label   as FAULT)
	      (if (not (= rs2 $r.argreg2))
		  (sparc.move as rs2 $r.argreg2))
	      (sparc.set     as (thefixnum $ex.mkbvl) $r.tmp0) ; Wrong code.
	      (millicode-call/ret as $m.exception START)
	      (sparc.label   as L1)
	      (sparc.bl      as FAULT)
	      (sparc.cmpi    as $r.tmp0 $imm.character)
	      (sparc.bne     as FAULT)
	      (sparc.move as $r.result $r.argreg3))
	    (begin
	      (sparc.move as $r.result $r.argreg3)))
	(emit-allocate-bytevector as
				  (+ $imm.bytevector-header
				     $tag.string-typetag)
				  $r.argreg3)
	(sparc.srai   as rs2 8 $r.tmp1)
	(sparc.addi   as $r.result 4 $r.result)
	(sparc.srai   as $r.argreg3 2 $r.tmp0)
	(emit-bytevector-fill as $r.tmp0 $r.result $r.tmp1)
	(sparc.addi as $r.result (- $tag.bytevector-tag 4) $r.result)))))

(define flat1:string-length
  (lambda (as)
    (emit-primop.3arg! as 'internal:string-length $r.result $r.result)))

(define flat1:string-length:str
  (lambda (as)
    (emit-get-length-trusted! as $tag.bytevector-tag $r.result $r.result)))

(define flat1:string-ref
  (lambda (as r)
    (emit-primop.4arg! as 'internal:string-ref $r.result r $r.result)))

(define flat1:string-ref:trusted
  (lambda (as rs2)
    (emit-bytevector-like-ref-trusted! as $r.result rs2 $r.result #t)))

(define flat1:string-set!
  (lambda (as r1 r2)
    (emit-string-set! as $r.result r1 r2)))

(define flat1:string-set!:trusted
  (lambda (as rs2 rs3)
    (emit-string-set-trusted! as $r.result rs2 rs3)))

; Ustrings (temporary; will replace strings)

; RESULT must have nonnegative fixnum.
; RS2 must have character.

(define flat4:make-string
  (lambda (as rs2)
    (let ((FAULT (new-label))
	  (START (new-label)))
      (sparc.label as START)
      (let ((rs2 (force-hwreg! as rs2 $r.argreg2)))
	(if (not (unsafe-code))
	    (let ((L1 (new-label))
		  (L2 (new-label)))
	      (sparc.tsubrcc as $r.result $r.g0 $r.g0)
	      (sparc.bvc.a   as L1)
	      (sparc.andi    as rs2 255 $r.tmp0)
	      (sparc.label   as FAULT)
	      (if (not (= rs2 $r.argreg2))
		  (sparc.move as rs2 $r.argreg2))
	      (sparc.set     as (thefixnum $ex.mkstr) $r.tmp0)
	      (millicode-call/ret as $m.exception START)
	      (sparc.label   as L1)
	      (sparc.bl      as FAULT)
	      (sparc.cmpi    as $r.tmp0 $imm.character)
	      (sparc.bne     as FAULT)
	      (sparc.move as $r.result $r.argreg3)
              ; FIXME: should be able to do this faster
              (sparc.taddrcc as $r.result $r.result $r.result)
              (sparc.bvs     as FAULT)
              (sparc.taddrcc as $r.result $r.result $r.result)
              (sparc.bvs     as FAULT)
              (sparc.move    as $r.result $r.argreg3))
            (begin
             ; FIXME: should be able to do this faster
             (sparc.addr     as $r.result $r.result $r.result)
             (sparc.addr     as $r.result $r.result $r.result)
             (sparc.move     as $r.result $r.argreg3)))
	(emit-allocate-bytevector as
				  (+ $imm.bytevector-header
				     $tag.ustring-typetag)
				  $r.argreg3)
	(sparc.addi   as $r.result 4 $r.result)
	(sparc.srai   as $r.argreg3 2 $r.tmp0)
        (emit-bytevector-fill4 as $r.tmp0 $r.result rs2)
	(sparc.addi as $r.result (- $tag.bytevector-tag 4) $r.result)))))

;(define-primop 'ustring-length
;  (lambda (as)
;    (emit-primop.3arg! as 'internal:ustring-length $r.result $r.result)))

(define flat4:string-length:str
  (lambda (as)
    (emit-get-length-trusted! as $tag.bytevector-tag $r.result $r.result)
    (sparc.srai               as $r.result 2 $r.result)))

;(define-primop 'ustring-ref
;  (lambda (as r)
;    (emit-primop.4arg! as 'internal:ustring-ref $r.result r $r.result)))

(define flat4:string-ref:trusted
  (lambda (as rs2)
    (emit-primop.4arg! as 'internal:ustring-ref:trusted
                          $r.result rs2 $r.result)))

;(define-primop 'ustring-set!
;  (lambda (as r1 r2)
;    (emit-ustring-set! as $r.result r1 r2)))

(define flat4:string-set!:trusted
  (lambda (as rs2 rs3)
    (emit-ustring-set-trusted! as $r.result rs2 rs3)))

(let ((rep (nbuild-parameter 'target-string-rep)))
  (case rep
   ((flat1)
    (define-primop 'string?              flat1:string?)
    (define-primop 'make-string          flat1:make-string)
    (define-primop 'string-length:str    flat1:string-length:str)
    (define-primop 'string-ref:trusted   flat1:string-ref:trusted)
    (define-primop 'string-set!:trusted  flat1:string-set!:trusted)
    (define-primop 'ustring?             flat1:string?)
    (define-primop 'make-ustring         flat1:make-string)
    (define-primop 'ustring-length:str   flat1:string-length:str)
    (define-primop 'ustring-ref:trusted  flat1:string-ref:trusted)
    (define-primop 'ustring-set!:trusted flat1:string-set!:trusted))
   ((flat4)
    (define-primop 'string?              flat4:string?)
    (define-primop 'make-string          flat4:make-string)
    (define-primop 'string-length:str    flat4:string-length:str)
    (define-primop 'string-ref:trusted   flat4:string-ref:trusted)
    (define-primop 'string-set!:trusted  flat4:string-set!:trusted)
    (define-primop 'ustring?             flat4:string?)
    (define-primop 'make-ustring         flat4:make-string)
    (define-primop 'ustring-length:str   flat4:string-length:str)
    (define-primop 'ustring-ref:trusted  flat4:string-ref:trusted)
    (define-primop 'ustring-set!:trusted flat4:string-set!:trusted))
   (else
    (error "Unrecognized string representation: " rep))))

;

(define-primop 'sys$partial-list->vector
  (lambda (as r)
    (millicode-call/1arg as $m.partial-list->vector r)))

(define-primop 'make-procedure
  (lambda (as)
    (emit-make-vector-like! as
			    '()
			    $imm.procedure-header
			    $tag.procedure-tag)))

(define-primop 'make-vector
  (lambda (as r)
    (emit-make-vector-like! as
			    r
			    (+ $imm.vector-header $tag.vector-typetag)
			    $tag.vector-tag)))

(define-primop 'make-vector:0
  (lambda (as r) (make-vector-n as 0 r)))

(define-primop 'make-vector:1
  (lambda (as r) (make-vector-n as 1 r)))

(define-primop 'make-vector:2
  (lambda (as r) (make-vector-n as 2 r)))

(define-primop 'make-vector:3
  (lambda (as r) (make-vector-n as 3 r)))

(define-primop 'make-vector:4
  (lambda (as r) (make-vector-n as 4 r)))

(define-primop 'make-vector:5
  (lambda (as r) (make-vector-n as 5 r)))

(define-primop 'make-vector:6
  (lambda (as r) (make-vector-n as 6 r)))

(define-primop 'make-vector:7
  (lambda (as r) (make-vector-n as 7 r)))

(define-primop 'make-vector:8
  (lambda (as r) (make-vector-n as 8 r)))

(define-primop 'make-vector:9
  (lambda (as r) (make-vector-n as 9 r)))

(define-primop 'vector-length
  (lambda (as)
    (emit-primop.3arg! as 'internal:vector-length $r.result $r.result)))

(define-primop 'vector-like-length
  (lambda (as)
    (emit-get-length! as $tag.vector-tag #f $ex.vllen $r.result $r.result)))

(define-primop 'vector-length:vec
  (lambda (as)
    (emit-get-length-trusted! as $tag.vector-tag $r.result $r.result)))

(define-primop 'procedure-length
  (lambda (as)
    (emit-get-length! as $tag.procedure-tag #f $ex.plen $r.result $r.result)))

(define-primop 'vector-ref
  (lambda (as r)
    (emit-primop.4arg! as 'internal:vector-ref $r.result r $r.result)))

(define-primop 'vector-like-ref
  (lambda (as r)
    (let ((fault (if (not (unsafe-code))
		     (emit-single-tagcheck-assert! as
						   $tag.vector-tag
						   $ex.vlref
						   r)
		     #f)))
      (emit-vector-like-ref!
       as $r.result r $r.result fault $tag.vector-tag #f))))

(define-primop 'vector-ref:trusted
  (lambda (as rs2)
    (emit-vector-like-ref-trusted!
     as $r.result rs2 $r.result $tag.vector-tag)))

(define-primop 'procedure-ref
  (lambda (as r)
    (let ((fault (if (not (unsafe-code))
		     (emit-single-tagcheck-assert! as
						   $tag.procedure-tag
						   $ex.pref
						   r)
		     #f)))
      (emit-vector-like-ref!
       as $r.result r $r.result fault $tag.procedure-tag #f))))

(define-primop 'vector-set!
  (lambda (as r1 r2)
    (emit-primop.4arg! as 'internal:vector-set! $r.result r1 r2)))

(define-primop 'vector-like-set!
  (lambda (as r1 r2)
    (let ((fault (if (not (unsafe-code))
		     (emit-single-tagcheck-assert! as
						   $tag.vector-tag
						   $ex.vlset
						   r1)
		     #f)))
      (emit-vector-like-set! as $r.result r1 r2 fault $tag.vector-tag #f))))

(define-primop 'vector-set!:trusted
  (lambda (as rs2 rs3)
    (emit-vector-like-set-trusted! as $r.result rs2 rs3 $tag.vector-tag)))

(define-primop 'vector-set!:trusted:nwb
  (lambda (as rs2 rs3)
    (emit-vector-like-set-trusted-no-barrier!
         as $r.result rs2 rs3 $tag.vector-tag)))

(define-primop 'procedure-set!
  (lambda (as r1 r2)
    (let ((fault (if (not (unsafe-code))
		     (emit-single-tagcheck-assert! as
						   $tag.procedure-tag
						   $ex.pset
						   r1)
		     #f)))
      (emit-vector-like-set! as $r.result r1 r2 fault $tag.procedure-tag #f))))

(define-primop 'char<?
  (lambda (as x)
    (emit-char-cmp as x sparc.bl.a $ex.char<?)))

(define-primop 'char<=?
  (lambda (as x)
    (emit-char-cmp as x sparc.ble.a $ex.char<=?)))

(define-primop 'char=?
  (lambda (as x)
    (emit-char-cmp as x sparc.be.a $ex.char=?)))

(define-primop 'char>?
  (lambda (as x)
    (emit-char-cmp as x sparc.bg.a $ex.char>?)))

(define-primop 'char>=?
  (lambda (as x)
    (emit-char-cmp as x sparc.bge.a $ex.char>=?)))

; Experimental (for performance).
; This makes massive assumptions about the layout of the port structure:
; A port is a vector-like where
;   #0 = port.input?
;   #4 = port.buffer
;   #7 = port.rd-lim
;   #8 = port.rd-ptr
; See Lib/iosys.sch for more information.

(define-primop 'sys$read-char
  (lambda (as)
    (let ((Lfinish (new-label))
	  (Lend    (new-label)))
      (if (not (unsafe-code))
	  (begin
	    (sparc.andi as $r.result $tag.tagmask $r.tmp0) ; mask argument tag
	    (sparc.cmpi as $r.tmp0 $tag.vector-tag); vector-like? 
	    (sparc.bne as Lfinish)		   ; skip if not vector-like
	    (sparc.nop as)
	    (sparc.ldbi as $r.RESULT 0 $r.tmp1)))   ; header byte
      (sparc.ldi  as $r.RESULT 1 $r.tmp2)	    ; port.input? or garbage
      (if (not (unsafe-code))
	  (begin
	    (sparc.cmpi as $r.tmp1 $hdr.port)       ; port?
	    (sparc.bne as Lfinish)))		    ; skip if not port
      (sparc.cmpi as $r.tmp2 $imm.false)  	    ; [slot] input port?
      (sparc.be as Lfinish)			    ; skip if not active port
      (sparc.ldi as $r.RESULT (+ 1 32) $r.tmp1)	    ; [slot] port.rd-ptr 
      (sparc.ldi as $r.RESULT (+ 1 28) $r.tmp2)	    ; port.rd-lim
      (sparc.ldi as $r.RESULT (+ 1 16) $r.tmp0)	    ; port.buffer
      (sparc.cmpr as $r.tmp1 $r.tmp2)		    ; rd-ptr < rd-lim?
      (sparc.bge as Lfinish)			    ; skip if rd-ptr >= rd-lim
      (sparc.subi as $r.tmp0 1 $r.tmp0)		    ; [slot] addr of string@0
      (sparc.srai as $r.tmp1 2 $r.tmp2)		    ; rd-ptr as native int
      (sparc.ldbr as $r.tmp0 $r.tmp2 $r.tmp2)	    ; get byte from string
      (sparc.addi as $r.tmp1 4 $r.tmp1)		    ; bump rd-ptr
      (sparc.sti as $r.tmp1 (+ 1 32) $r.RESULT)	    ; store rd-ptr in port
      (sparc.slli as $r.tmp2 8 $r.tmp2)             ; convert to char #1
      (sparc.b as Lend)
      (sparc.ori as $r.tmp2 $imm.character $r.RESULT) ; [slot] convert to char
      (sparc.label as Lfinish)
      (sparc.set as $imm.false $r.RESULT)	    ; failed
      (sparc.label as Lend))))


; eof
