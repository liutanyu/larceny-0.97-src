; Copyright 1998 Lars T Hansen.
;
; $Id: logops.ss 2926 2006-05-01 23:14:51Z pnkfelix $
;
; Chez Scheme compatibility code -- logical operations.
;
; The following work because Chez Scheme fixnums are the same as Larceny 
; fixnums.

(define fxlogior fxlogor)
(define fxlogand fxlogand)
(define fxlogxor fxlogxor)
(define fxlognot fxlognot)
(define fxlsh fxsll)
(define fxrshl fxsrl)
(define fxrsha fxsra)

; eof

