; Copyright 1998 Lars T Hansen.
;
; $Id: error0.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Larceny library -- Boot-time error procedure.

($$trace "error0")

(define (error . rest)
  ($$trace "ERROR")
  (do ((rest rest (cdr rest)))
      ((null? rest) (sys$exit 1))
    (if (string? (car rest))
	($$trace (car rest)))))

; eof
