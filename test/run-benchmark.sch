; Copyright 1998 Lars T Hansen
;
; $Id: run-benchmark.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Unclear if this is still used.

(define (run-benchmark name thunk . rest)
  (let ((n (if (null? rest) 1 (car rest))))
    
    (define (loop n)
      (if (zero? n)
	  #t
	  (begin (thunk)
		 (loop (- n 1)))))

    (newline)
    (write `(RUNNING ,name))
    (newline)
    (new-run-with-stats (lambda () (loop n)))))

(define (new-run-with-stats thunk)
  
  (define (print-stats s1 s2)
    (display
     `((allocated ,(- (vector-ref s2 0) (vector-ref s1 0)))
       (reclaimed ,(- (vector-ref s2 1) (vector-ref s1 1)))
       (elapsed   ,(- (vector-ref s2 21) (vector-ref s1 21)))
       (user      ,(- (vector-ref s2 23) (vector-ref s1 23)))
       (system    ,(- (vector-ref s2 22) (vector-ref s1 22)))
       (gctime    ,(let ((gcs0 0)
			 (gcs1 0))
		     (do ((i 0 (+ i 1)))
			 ((= i (vector-length (vector-ref s1 7))) 
			  (- gcs1 gcs0))
		       (let ((x0 (vector-ref (vector-ref s1 7) i))
			     (x1 (vector-ref (vector-ref s2 7) i)))
			 (set! gcs0 (+ gcs0 (vector-ref x0 0)
				       (vector-ref x0 1)))
			 (set! gcs1 (+ gcs1 (vector-ref x1 0)
				       (vector-ref x1 1))))))
		  (- (vector-ref s2 3) (vector-ref s1 3)))
       (currentheap ,(vector-ref s2 13))
       (maxheap   ,(vector-ref s2 27))
       ))
    (newline))

  (let* ((s1 (memstats))
	 (r  (thunk))
	 (s2 (memstats)))
    (print-stats s1 s2)
    r))
