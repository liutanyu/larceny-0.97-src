; Copyright 1998 Lars T Hansen.
;
; $Id: go.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; The `go' procedure -- where uninitialized heaps start.
;
; Initializes the system and calls "main". This procedure is only called
; when we are loading an unitialized heap; initialized heaps will have "main"
; (or something else) as their entry point.
;
; When the system tables have been initialized, this procedure attempts to
; exterminate itself by clobbering 'scheme-entry' and calling 'main' in a
; tail-recursive fashion, thereby making itself and the caller eligible for
; garbage collection if they have not been referenced from anywhere else (and
; they should not have been).

($$trace "go")

(define (go symlist argv)
  ($$trace "In `go'")
  ($$trace "  millicode support")
  (install-millicode-support)
  ($$trace "  oblist")
  (oblist-set! symlist)
  ($$trace "  reader")
  (install-reader)
  (set! scheme-entry #f)
  ($$trace "  jumping to `main'")
  (main argv))

(define (iosys-test)
  ($$trace "Testing I/O system")
  (write-char #\c)
  (write-char #\newline)
  (display "Test string: ") (write "test") (newline)
  (display "Test symbol: ") (write 'foo) (newline)
  (display "Test list: ") (write '(a b c)) (newline)
  (display "Test vector: ") (write '#(a b c)) (newline)
  (display "Test fixnum: ") (write 37) (newline)
  (display "Test bignum: ") (write (expt 2 32)) (newline)
  (display "Test flonum: ") (write 3.14159) (newline)
  ($$trace "I/O test done"))

; eof
