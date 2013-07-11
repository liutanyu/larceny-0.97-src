; Copyright 1998 Lars T Hansen.
;
; $Id: format.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Larceny-compatible 'format' procedure.

(define (format port format-string . args)
  (let ((port (cond ((output-port? port) port)
		    ((eq? port #t) (current-output-port))
		    (else (error "format: not a port: " port)
			  #t)))
	(n    (string-length format-string)))

    (define (format-loop i args)
      (cond ((= i n))
	    ((char=? (string-ref format-string i) #\~)
	     (let ((c (string-ref format-string (+ i 1))))
	       (cond ((char=? c #\~)
		      (write-char #\~ port)
		      (format-loop (+ i 2) args))
		     ((char=? c #\%)
		      (newline port)
		      (format-loop (+ i 2) args))
		     ((char=? c #\a)
		      (display (car args) port)
		      (format-loop (+ i 2) (cdr args)))
		     ((char=? c #\s)
		      (write (car args) port)
		      (format-loop (+ i 2) (cdr args)))
		     ((char=? c #\c)
		      (write-char (car args) port)
		      (format-loop (+ i 2) (cdr args)))
		     ((or (char=? c #\b)
			  (char=? c #\B))
		      (error "format: can't do bytevectors yet."))
;		     ((or (char=? c #\b)
;			  (char=? c #\B))
;		      (let ((bv    (car args))
;			    (radix (if (char=? c #\b) 10 16)))
;			(if (not (bytevector? bv))
;			    (error "format: not a bytevector: " bv))
;			(do ((k 0 (+ k 1)))
;			    ((= k (bytevector-length bv)))
;			(display (number->string (bytevector-ref bv k) radix))
;			(write-char #\space)))
;		      (format-loop (+ i 2) (cdr args)))
		     (else
		      (format-loop (+ i 1) args)))))
	    (else
	     (write-char (string-ref format-string i) port)
	     (format-loop (+ i 1) args))))

    (format-loop 0 args)
    #t))

