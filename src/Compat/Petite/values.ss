; Copyright 1998 Lars T Hansen
;
; $Id: values.ss 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Multiple values for Chez Scheme v4.x.

(define (values . x) x)

(define (call-with-values proc receiver)
  (apply receiver (proc)))

