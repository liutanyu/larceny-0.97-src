; $Id: logops.ss 2926 2006-05-01 23:14:51Z pnkfelix $

;; Logical operations

(define fxlogior bitwise-ior)
(define fxlogand bitwise-and)
(define fxlogxor bitwise-xor)
(define fxlognot bitwise-not)

(define fxlsh arithmetic-shift)


;; This is hardcoded for 30 bit words (to ensure that its as much like
;; the Larceny implementation we're emulating as possible.  Its only
;; used in asmutil32*.sch, so that seem safe.  It would be a good idea
;; to go over the references to rshl and ensure that every value
;; produced by a call to rsh eventually flows into a logand that cuts
;; off the upper most bits; then we would know that we could replace
;; this implementation with one that did not need to emulate 30 bit
;; twos-complement.
(define (fxrshl n m)
  (if (< n 0)
      (arithmetic-shift (bitwise-and n (- (expt 2 30) 1)) (- 0 m))
      (arithmetic-shift n (- 0 m))))
(define (fxrsha n m) (arithmetic-shift n (- 0 m)))
