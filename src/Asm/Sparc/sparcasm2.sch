; Instruction mnemonics

(define sparc.lddi    (sparc-instruction 'i11 #b000011))
(define sparc.lddr    (sparc-instruction 'r11 #b000011))
(define sparc.ldi     (sparc-instruction 'i11 #b000000))
(define sparc.ldr     (sparc-instruction 'r11 #b000000))
(define sparc.ldhi    (sparc-instruction 'i11 #b000010))
(define sparc.ldhr    (sparc-instruction 'r11 #b000010))
(define sparc.ldbi    (sparc-instruction 'i11 #b000001))
(define sparc.ldbr    (sparc-instruction 'r11 #b000001))
(define sparc.lddfi   (sparc-instruction 'i11 #b100011))
(define sparc.lddfr   (sparc-instruction 'r11 #b100011))
(define sparc.stdi    (sparc-instruction 'si11 #b000111))
(define sparc.stdr    (sparc-instruction 'sr11 #b000111))
(define sparc.sti     (sparc-instruction 'si11 #b000100))
(define sparc.str     (sparc-instruction 'sr11 #b000100))
(define sparc.sthi    (sparc-instruction 'si11 #b000110))
(define sparc.sthr    (sparc-instruction 'sr11 #b000110))
(define sparc.stbi    (sparc-instruction 'si11 #b000101))
(define sparc.stbr    (sparc-instruction 'sr11 #b000101))
(define sparc.stdfi   (sparc-instruction 'si11 #b100111))
(define sparc.stdfr   (sparc-instruction 'sr11 #b100111))
(define sparc.sethi   (sparc-instruction 'sethi #b100))
(define sparc.andr    (sparc-instruction 'r10 #b000001))
(define sparc.andrcc  (sparc-instruction 'r10 #b010001))
(define sparc.andi    (sparc-instruction 'i10 #b000001))
(define sparc.andicc  (sparc-instruction 'i10 #b010001))
(define sparc.orr     (sparc-instruction 'r10 #b000010))
(define sparc.orrcc   (sparc-instruction 'r10 #b010010))
(define sparc.ori     (sparc-instruction 'i10 #b000010))
(define sparc.oricc   (sparc-instruction 'i10 #b010010))
(define sparc.xorr    (sparc-instruction 'r10 #b000011))
(define sparc.xorrcc  (sparc-instruction 'r10 #b010011))
(define sparc.xori    (sparc-instruction 'i10 #b000011))
(define sparc.xoricc  (sparc-instruction 'i10 #b010011))
(define sparc.sllr    (sparc-instruction 'r10 #b100101))
(define sparc.slli    (sparc-instruction 'i10 #b100101))
(define sparc.srlr    (sparc-instruction 'r10 #b100110))
(define sparc.srli    (sparc-instruction 'i10 #b100110))
(define sparc.srar    (sparc-instruction 'r10 #b100111))
(define sparc.srai    (sparc-instruction 'i10 #b100111))
(define sparc.addr    (sparc-instruction 'r10 #b000000))
(define sparc.addrcc  (sparc-instruction 'r10 #b010000))
(define sparc.addi    (sparc-instruction 'i10 #b000000))
(define sparc.addicc  (sparc-instruction 'i10 #b010000))
(define sparc.taddrcc (sparc-instruction 'r10 #b100000))
(define sparc.taddicc (sparc-instruction 'i10 #b100000))
(define sparc.subr    (sparc-instruction 'r10 #b000100))
(define sparc.subrcc  (sparc-instruction 'r10 #b010100))
(define sparc.subi    (sparc-instruction 'i10 #b000100))
(define sparc.subicc  (sparc-instruction 'i10 #b010100))
(define sparc.tsubrcc (sparc-instruction 'r10 #b100001))
(define sparc.tsubicc (sparc-instruction 'i10 #b100001))
(define sparc.smulr   (sparc-instruction 'r10 #b001011))
(define sparc.smulrcc (sparc-instruction 'r10 #b011011))
(define sparc.smuli   (sparc-instruction 'i10 #b001011))
(define sparc.smulicc (sparc-instruction 'i10 #b011011))
(define sparc.sdivr   (sparc-instruction 'r10 #b001111))
(define sparc.sdivrcc (sparc-instruction 'r10 #b011111))
(define sparc.sdivi   (sparc-instruction 'i10 #b001111))
(define sparc.sdivicc (sparc-instruction 'i10 #b011111))
(define sparc.b       (sparc-instruction 'b00 #b1000))
(define sparc.b.a     (sparc-instruction 'a00 #b1000))
(define sparc.bne     (sparc-instruction 'b00 #b1001))
(define sparc.bne.a   (sparc-instruction 'a00 #b1001))
(define sparc.be      (sparc-instruction 'b00 #b0001))
(define sparc.be.a    (sparc-instruction 'a00 #b0001))
(define sparc.bg      (sparc-instruction 'b00 #b1010))
(define sparc.bg.a    (sparc-instruction 'a00 #b1010))
(define sparc.ble     (sparc-instruction 'b00 #b0010))
(define sparc.ble.a   (sparc-instruction 'a00 #b0010))
(define sparc.bge     (sparc-instruction 'b00 #b1011))
(define sparc.bge.a   (sparc-instruction 'a00 #b1011))
(define sparc.bl      (sparc-instruction 'b00 #b0011))
(define sparc.bl.a    (sparc-instruction 'a00 #b0011))
(define sparc.bgu     (sparc-instruction 'b00 #b1100))
(define sparc.bgu.a   (sparc-instruction 'a00 #b1100))
(define sparc.bleu    (sparc-instruction 'b00 #b0100))
(define sparc.bleu.a  (sparc-instruction 'a00 #b0100))
(define sparc.bcc     (sparc-instruction 'b00 #b1101))
(define sparc.bcc.a   (sparc-instruction 'a00 #b1101))
(define sparc.bcs     (sparc-instruction 'b00 #b0101))
(define sparc.bcs.a   (sparc-instruction 'a00 #b0101))
(define sparc.bpos    (sparc-instruction 'b00 #b1110))
(define sparc.bpos.a  (sparc-instruction 'a00 #b1110))
(define sparc.bneg    (sparc-instruction 'b00 #b0110))
(define sparc.bneg.a  (sparc-instruction 'a00 #b0110))
(define sparc.bvc     (sparc-instruction 'b00 #b1111))
(define sparc.bvc.a   (sparc-instruction 'a00 #b1111))
(define sparc.bvs     (sparc-instruction 'b00 #b0111))
(define sparc.bvs.a   (sparc-instruction 'a00 #b0111))
(define sparc.call    (sparc-instruction 'call))
(define sparc.jmplr   (sparc-instruction 'r10 #b111000 'jump))
(define sparc.jmpli   (sparc-instruction 'i10 #b111000 'jump))
(define sparc.nop     (sparc-instruction 'nop #b100))
(define sparc.ornr    (sparc-instruction 'r10 #b000110))
(define sparc.orni    (sparc-instruction 'i10 #b000110))
(define sparc.ornrcc  (sparc-instruction 'r10 #b010110))
(define sparc.ornicc  (sparc-instruction 'i10 #b010110))
(define sparc.andni   (sparc-instruction 'i10 #b000101))
(define sparc.andnr   (sparc-instruction 'r10 #b000101))
(define sparc.andnicc (sparc-instruction 'i10 #b010101))
(define sparc.andnrcc (sparc-instruction 'r10 #b010101))
(define sparc.rdy     (sparc-instruction 'r10 #b101000 'rdy))
(define sparc.wryr    (sparc-instruction 'r10 #b110000 'wry))
(define sparc.wryi    (sparc-instruction 'i10 #b110000 'wry))
(define sparc.fb      (sparc-instruction 'fb00 #b1000))
(define sparc.fb.a    (sparc-instruction 'fa00 #b1000))
(define sparc.fbn     (sparc-instruction 'fb00 #b0000))
(define sparc.fbn.a   (sparc-instruction 'fa00 #b0000))
(define sparc.fbu     (sparc-instruction 'fb00 #b0111))
(define sparc.fbu.a   (sparc-instruction 'fa00 #b0111))
(define sparc.fbg     (sparc-instruction 'fb00 #b0110))
(define sparc.fbg.a   (sparc-instruction 'fa00 #b0110))
(define sparc.fbug    (sparc-instruction 'fb00 #b0101))
(define sparc.fbug.a  (sparc-instruction 'fa00 #b0101))
(define sparc.fbl     (sparc-instruction 'fb00 #b0100))
(define sparc.fbl.a   (sparc-instruction 'fa00 #b0100))
(define sparc.fbul    (sparc-instruction 'fb00 #b0011))
(define sparc.fbul.a  (sparc-instruction 'fa00 #b0011))
(define sparc.fblg    (sparc-instruction 'fb00 #b0010))
(define sparc.fblg.a  (sparc-instruction 'fa00 #b0010))
(define sparc.fbne    (sparc-instruction 'fb00 #b0001))
(define sparc.fbne.a  (sparc-instruction 'fa00 #b0001))
(define sparc.fbe     (sparc-instruction 'fb00 #b1001))
(define sparc.fbe.a   (sparc-instruction 'fa00 #b1001))
(define sparc.fbue    (sparc-instruction 'fb00 #b1010))
(define sparc.fbue.a  (sparc-instruction 'fa00 #b1010))
(define sparc.fbge    (sparc-instruction 'fb00 #b1011))
(define sparc.fbge.a  (sparc-instruction 'fa00 #b1011))
(define sparc.fbuge   (sparc-instruction 'fb00 #b1100))
(define sparc.fbuge.a (sparc-instruction 'fa00 #b1100))
(define sparc.fble    (sparc-instruction 'fb00 #b1101))
(define sparc.fble.a  (sparc-instruction 'fa00 #b1101))
(define sparc.fbule   (sparc-instruction 'fb00 #b1110))
(define sparc.fbule.a (sparc-instruction 'fa00 #b1110))
(define sparc.fbo     (sparc-instruction 'fb00 #b1111))
(define sparc.fbo.a   (sparc-instruction 'fa00 #b1111))
(define sparc.faddd   (sparc-instruction 'fp   #b001000010))
(define sparc.fsubd   (sparc-instruction 'fp   #b001000110))
(define sparc.fmuld   (sparc-instruction 'fp   #b001001010))
(define sparc.fdivd   (sparc-instruction 'fp   #b001001110))
(define sparc%fnegs   (sparc-instruction 'fp   #b000000101)) ; See below
(define sparc%fmovs   (sparc-instruction 'fp   #b000000001)) ; See below
(define sparc%fabss   (sparc-instruction 'fp   #b000001001)) ; See below
(define sparc%fcmpdcc (sparc-instruction 'fpcc #b001010010)) ; See below

; Strange instructions.

(define sparc.slot    (sparc-instruction 'slot))
(define sparc.slot2   (sparc-instruction 'slot2))
(define sparc.label   (sparc-instruction 'label))

; Aliases.

(define sparc.bnz     sparc.bne)
(define sparc.bnz.a   sparc.bne.a)
(define sparc.bz      sparc.be)
(define sparc.bz.a    sparc.be.a)
(define sparc.bgeu    sparc.bcc)
(define sparc.bgeu.a  sparc.bcc.a)
(define sparc.blu     sparc.bcs)
(define sparc.blu.a   sparc.bcs.a)

; Abstractions.

(define (sparc.cmpr as r1 r2) (sparc.subrcc as r1 r2 $r.g0))
(define (sparc.cmpi as r imm) (sparc.subicc as r imm $r.g0))
(define (sparc.move as rs rd) (sparc.orr as $r.g0 rs rd))
(define (sparc.set as imm rd) (sparc.ori as $r.g0 imm rd))
(define (sparc.btsti as rs imm) (sparc.andicc as rs imm $r.g0))
(define (sparc.clr as rd) (sparc.move as $r.g0 rd))

(define (sparc.deccc as rs . rest)
  (let ((k (cond ((null? rest) 1)
                 ((null? (cdr rest)) (car rest))
                 (else (asm-error "sparc.deccc: too many operands: " rest)))))
    (sparc.subicc as rs k rs)))

; Floating-point abstractions
;
; For fmovd, fnegd, and fabsd, we must synthesize the instruction from
; fmovs, fnegs, and fabss -- SPARC V8 has only the latter.  (SPARC V9 add
; the former.)

(define (sparc.fmovd as rs rd)
  (sparc%fmovs as rs 0 rd)
  (sparc%fmovs as (+ rs 1) 0 (+ rd 1)))

(define (sparc.fnegd as rs rd)
  (sparc%fnegs as rs 0 rd)
  (if (not (= rs rd))
      (sparc%fmovs as (+ rs 1) 0 (+ rd 1))))

(define (sparc.fabsd as rs rd)
  (sparc%fabss as rs 0 rd)
  (if (not (= rs rd))
      (sparc%fmovs as (+ rs 1) 0 (+ rd 1))))

(define (sparc.fcmpd as rs1 rs2)
  (sparc%fcmpdcc as rs1 rs2 0))

; eof
