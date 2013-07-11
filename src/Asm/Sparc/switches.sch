; Copyright 1998 Lars T Hansen.
;
; $Id: switches.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; SPARC machine assembler flags.
;
; 12 April 1999


; INTERNAL!
(define short-effective-addresses
  (make-twobit-flag 'short-effective-addresses))

(define runtime-safety-checking
  (make-twobit-flag 'runtime-safety-checking))

(define catch-undefined-globals
  (make-twobit-flag 'catch-undefined-globals))

(define inline-allocation
  (make-twobit-flag 'inline-allocation))
  
;(define inline-assignment
;  (make-twobit-flag 'inline-assignment))

(define write-barrier
  (make-twobit-flag 'write-barrier))  

(define peephole-optimization
  (make-twobit-flag 'peephole-optimization))

(define single-stepping
  (make-twobit-flag 'single-stepping))

(define fill-delay-slots
  (make-twobit-flag 'fill-delay-slots))

; For backward compatibility.

;(define unsafe-code
;  (make-twobit-flag 'unsafe-code))

(define (unsafe-code . args)
  (if (null? args)
      (not (runtime-safety-checking))
      (runtime-safety-checking (not (car args)))))

(define (assembler-global-optimization-flags)
  (lambda ()
    #t))

(define (assembler-runtime-safety-flags)
  (let ((r.s.c (runtime-safety-checking))
        (c.u.g (catch-undefined-globals)))
    (lambda ()
      (runtime-safety-checking r.s.c)
      (catch-undefined-globals c.u.g))))

(define (assembler-all-flags)
  (let ((r.s.c (runtime-safety-checking))
        (c.u.g (catch-undefined-globals))
        (i.a   (inline-allocation))
        (w.b   (write-barrier))
        (p.o   (peephole-optimization))
        (s.s   (single-stepping))
        (f.d.s (fill-delay-slots)))
    (lambda ()
      (runtime-safety-checking r.s.c)
      (catch-undefined-globals c.u.g)
      (inline-allocation i.a)
      (write-barrier w.b)
      (peephole-optimization p.o)
      (single-stepping s.s)
      (fill-delay-slots f.d.s))))

(define (display-assembler-flags which)
  (case which
    ((debugging)
     (display-twobit-flag single-stepping))
    ((safety)
     (display-twobit-flag write-barrier)
     ;(display-twobit-flag unsafe-code)
     (display-twobit-flag runtime-safety-checking)
     (if (runtime-safety-checking)
         (begin (display "  ")
                (display-twobit-flag catch-undefined-globals))))
    ((optimization)
     (display-twobit-flag peephole-optimization)
     (display-twobit-flag inline-allocation)
     ;  (display-twobit-flag inline-assignment)
     (display-twobit-flag fill-delay-slots))
    (else #t)))

(define (set-assembler-flags! mode)
  (case mode
    ((no-optimization)
     (set-assembler-flags! 'standard)
     (peephole-optimization #f)
     (fill-delay-slots #f))
    ((standard)
     (short-effective-addresses #t)
     (catch-undefined-globals #t)
     (inline-allocation #f)
     ; (inline-assignment #f)
     (peephole-optimization #t)
     (runtime-safety-checking #t)
     (write-barrier #t)
     (single-stepping #f)
     (fill-delay-slots #t))
    ((fast-safe default)
     (set-assembler-flags! 'standard)
     ; (inline-assignment #t)
     (inline-allocation #t))
    ((fast-unsafe)
     (set-assembler-flags! 'fast-safe)
     (catch-undefined-globals #f)
     (runtime-safety-checking #f))
    (else
     (error "set-assembler-flags!: unknown mode " mode))))

(set-assembler-flags! 'default)

; eof
