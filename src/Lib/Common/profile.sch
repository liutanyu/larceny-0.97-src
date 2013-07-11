; Copyright 1998 Lars T Hansen.
;
; $Id: profile.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Larceny library -- profiling support.

($$trace "profile")

; Simple, slow trace facility for primitive profiling.
; You can control the state of tracing with sys$tracectl.
; To trace a procedure, call sys$trace with a symbol; the entry for
; the proocedure will have its count upped by one.

(define sys$enabled #f)
(define sys$traces '())

(define (sys$tracectl type)
  (cond ((eq? type 'get)
	 sys$traces)
	((eq? type 'start)
	 (set! sys$enabled #t))
	((eq? type 'stop)
	 (set! sys$enabled #f))
	((eq? type 'clear)
	 (set! sys$traces '()))
	(else
	 (error "sys$tracectl: unknown: " type)
	 #t)))

(define (sys$trace item)
  (if sys$enabled
      (let* ((probe (assq item sys$traces))
	     (i     (if probe
			probe
			(let ((p (cons item 0)))
			  (set! sys$traces (cons p sys$traces))
			  p))))
	(set-cdr! i (+ (cdr i) 1)))))

; eof
