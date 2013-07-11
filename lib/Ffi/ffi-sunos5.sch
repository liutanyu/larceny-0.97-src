; Copyright 1998 Lars T Hansen.
;
; $Id: ffi-sunos5.sch 5606 2008-06-30 20:49:11Z pnkfelix $
;
; Larceny FFI -- ABI objects for sun4-sunos5

#!no-fold-case

(define ffi/SPARC-sunos5-C-callout-stdabi
  (let ((parent ffi/SPARC-C-callout-stdabi))

    (define (load-library name)
      (ffi/dlopen name))

    (define (link-procedure library name)
      (ffi/dlsym library name))

    (lambda (selector)
      (case selector
	((load-lib) load-library)
	((link-proc) link-procedure)
	(else (parent selector))))))

(define ffi/SPARC-sunos5-C-callback-stdabi
  (let ((parent ffi/SPARC-C-callback-stdabi))

    (define (callback-addr)
      (let ((a (ffi/getaddr 'convert-and-call)))
	(if a
	    a
	    (error "callback-addr (sunos5): failed."))))

    (lambda (selector)
      (case selector
	((callback-addr)  callback-addr)
	(else (parent selector))))))

(define (ffi/sun4-sunos5-libc)
  "/lib/libc.so")

; eof
