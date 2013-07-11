; Copyright 1998 Lars T Hansen.
;
; $Id: vector.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Useful vector functions.

(define (vector-copy v)
  (let ((v2 (make-vector (vector-length v) #f)))
    (do ((i (- (vector-length v) 1) (- i 1)))
        ((< i 0) v2)
      (vector-set! v2 i (vector-ref v i)))))

; eof
