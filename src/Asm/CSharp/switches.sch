; Copyright 1998 Lars T Hansen.
;
; $Id: switches.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Standard-C machine assembler flags.

(define unsafe-code
  (make-twobit-flag 'unsafe-code))

(define catch-undefined-globals
  (make-twobit-flag 'catch-undefined-globals))

(define inline-allocation
  (make-twobit-flag 'inline-allocation))
  
(define inline-assignment
  (make-twobit-flag 'inline-assignment))

(define (peephole-optimization . rest) #f)

(define (single-stepping . rest) #f)

(define (display-assembler-flags)
  (display "Standard-C Assembler flags") (newline)
  (display-twobit-flag unsafe-code)
  (display-twobit-flag catch-undefined-globals)
  (display-twobit-flag inline-allocation)
  (display-twobit-flag inline-assignment)
  (display-twobit-flag peephole-optimization))

(define (set-assembler-flags! mode)
  (case mode
    ((no-optimization default fast-safe)
     (inline-allocation #f)
     (inline-assignment #f)
     (catch-undefined-globals #t)
     (peephole-optimization #f)
     (unsafe-code #f))
    ((fast-unsafe)
     (set-assembler-flags! 'default)
     (unsafe-code #t)
     (catch-undefined-globals #f))
    (else ???)))

(set-assembler-flags! 'default)

; eof
