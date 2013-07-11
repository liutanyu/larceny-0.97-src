; Copyright 1998 William Clinger.
;
; $Id: printlap.sch 2824 2006-04-12 03:59:44Z tov $
;
; Procedures that make .LAP structures human-readable

(define (readify-lap code)
  (map (lambda (x)
	 (let ((iname (cdr (assv (car x) *mnemonic-names*))))
	   (if (not (= (car x) $lambda))
	       (cons iname (cdr x))
	       (list iname (readify-lap (cadr x)) (caddr x)))))
       code))

(define (readify-file f . o)

  (define (doit)
    (let ((i (open-input-file f)))
      (let loop ((x (read i)))
	(if (not (eof-object? x))
	    (begin (pretty-print (readify-lap x))
		   (loop (read i)))))))

  (if (null? o)
      (doit)
      (begin (delete-file (car o))
	     (with-output-to-file (car o) doit))))

; eof
