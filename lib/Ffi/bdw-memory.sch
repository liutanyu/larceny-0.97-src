; Copyright 1998 Lars T Hansen.
;
; $Id: bdw-memory.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Larceny FFI -- memory management details, for the Boehm-Demers-Weiser 
;   conservative collector.

(define make-nonrelocatable-bytevector make-bytevector)
(define cons-nonrelocatable cons)
(define make-nonrelocatable-vector make-vector)

(define (ffi/gcprotect obj)
  (cons obj 0))

(define (ffi/gcprotect-increment handle)
  #t)

(define (ffi/gcunprotect handle)
  #t)

; eof
