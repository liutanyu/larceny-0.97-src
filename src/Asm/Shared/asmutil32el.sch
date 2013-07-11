; Copyright 1998 Lars T Hansen.
;
; $Id: asmutil32el.sch 2926 2006-05-01 23:14:51Z pnkfelix $
;
; Larceny assembler -- 32-bit little-endian utility procedures.
;
; 32-bit numbers are represented as 4-byte bytevectors where byte 0
; is the least significant and byte 3 is the most significant.
;
; Logically, the 'big' end is on the left and the 'little' end
; is on the right, so a left shift shifts towards the 'big' end.
;
; Performance: poor, for good reasons.  See asmutil32.sch.

; Identifies the code loaded.

(define asm:endianness 'little)


; Given four bytes, return a length-4 bytevector. 
; N1 is the most significant byte, n4 the least significant.

(define (asm:bv n1 n2 n3 n4)
  (let ((bv (make-bytevector 4)))
    (bytevector-set! bv 0 n4)
    (bytevector-set! bv 1 n3)
    (bytevector-set! bv 2 n2)
    (bytevector-set! bv 3 n1)
    bv))


; Convert a length-4 bytevector to an integer.

(define (asm:bv->int bv)
  (let ((i (+ (* (+ (* (+ (* (bytevector-ref bv 3) 256)
			  (bytevector-ref bv 2))
		       256)
		    (bytevector-ref bv 1))
		 256)
	      (bytevector-ref bv 0))))
    (if (> (bytevector-ref bv 3) 127)
	(- i)
	i)))


; Shift the bits of m left by n bits, shifting in zeroes at the low end.
; Returns a length-4 bytevector.
;
; M may be an exact integer or a length-4 bytevector.
; N must be an exact nonnegative integer; it's interpreted modulo 33.

(define (asm:lsh m n)
  (if (not (bytevector? m))
      (asm:lsh (asm:int->bv m) n)
      (let ((m (bytevector-copy m))
	    (n (remainder n 33)))
	(if (>= n 8)
	    (let ((k (quotient n 8)))
	      (do ((i 3 (- i 1)))
		  ((< i k))
		(bytevector-set! m i (bytevector-ref m (- i k))))
	      (do ((i 0 (+ i 1)))
		  ((= i k))
		(bytevector-set! m i 0))))
	(let* ((d0 (bytevector-ref m 0))
	       (d1 (bytevector-ref m 1))
	       (d2 (bytevector-ref m 2))
	       (d3 (bytevector-ref m 3))
	       (n  (remainder n 8))
	       (n- (- 8 n)))
	  (asm:bv (fxlogand (fxlogior (fxlsh d3 n) (fxrshl d2 n-)) 255)
		  (fxlogand (fxlogior (fxlsh d2 n) (fxrshl d1 n-)) 255)
		  (fxlogand (fxlogior (fxlsh d1 n) (fxrshl d0 n-)) 255)
		  (fxlogand (fxlsh d0 n) 255))))))


; Shift the bits of m right by n bits, shifting in zeroes at the high end.
; Returns a length-4 bytevector.
;
; M may be an exact integer or a length-4 bytevector.
; N must be an exact nonnegative integer; it's interpreted modulo 33.

(define (asm:rshl m n)
  (if (not (bytevector? m))
      (asm:rshl (asm:int->bv m) n)
      (let ((m (bytevector-copy m))
	    (n (remainder n 33)))
	(if (>= n 8)
	    (let ((k (quotient n 8)))
	      (do ((i k (+ i 1)))
		  ((= i 4))
		(bytevector-set! m (- i k) (bytevector-ref m i)))
	      (do ((i 3 (- i 1)))
		  ((= i (- 3 k)))
		(bytevector-set! m i 0))))
	(let* ((d0 (bytevector-ref m 0))
	       (d1 (bytevector-ref m 1))
	       (d2 (bytevector-ref m 2))
	       (d3 (bytevector-ref m 3))
	       (n  (remainder n 8))
	       (n- (- 8 n)))
	  (asm:bv (fxlogand (fxrshl d3 n) 255)
		  (fxlogand (fxlogior (fxrshl d2 n) (fxlsh d3 n-)) 255)
		  (fxlogand (fxlogior (fxrshl d1 n) (fxlsh d2 n-)) 255)
		  (fxlogand (fxlogior (fxrshl d0 n) (fxlsh d1 n-)) 255))))))


; Shift the bits of m right by n bits, shifting in the sign bit at the
; high end.  Returns a length-4 bytevector.
;
; M may be an exact integer or a length-4 bytevector.
; N must be an exact nonnegative integer; it's interpreted modulo 33.

(define asm:rsha
  (let ((ones (asm:bv #xff #xff #xff #xff)))
    (lambda (m n)
      (let* ((m (if (bytevector? m) m (asm:int->bv m)))
	     (n (remainder n 33))
	     (h (fxrshl (bytevector-ref m 3) 7))
	     (k (asm:rshl m n)))
	(if (zero? h)
	    k
	    (asm:logior k (asm:lsh ones (- 32 n))))))))

; eof
