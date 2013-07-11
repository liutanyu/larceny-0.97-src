; Copyright 1998 Lars T Hansen.
;
; $Id: dump.sch 5873 2008-12-21 21:44:05Z will $
;
; Larceny library -- heap dumping

($$trace "dump")

(define (dump-heap filename proc)
  (cond ((not (string? filename))
	 (error "dump-heap: invalid file name: " filename)
	 #t)
	((not (procedure? proc))
	 (error "dump-heap: invalid procedure: " proc)
	 #t)
	(else
	 (display "; Dumping heap...") (newline)
         (reset-all-hashtables!)
	 (sys$dump-heap filename 
			(lambda (argv)
			  (command-line-arguments argv)
			  (run-init-procedures)
			  (proc argv)))
	 (display "; Done.")
	 (newline))))

; eof
