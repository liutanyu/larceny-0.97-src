; Copyright 1998 Lars T Hansen.
;
; $Id: toplevel-target.sch 3774 2006-11-10 23:25:59Z tov $
;
; The interpreter's top-level environment -- Standard-C additions

($$trace "toplevel-standard-c")

(define (initialize-null-environment-target-specific null) null)
(define (initialize-r4rs-environment-target-specific r4rs) r4rs)
(define (initialize-r5rs-environment-target-specific r5rs) r5rs)

(define (initialize-larceny-environment-target-specific larc) 

  ;; system performance and interface

  ;; Support for loading compiled files as code-less FASL files with
  ;; the code vectors already linked into the executable or present
  ;; in dynamically loaded object files.

  (environment-set! larc '@common-patch-procedure @common-patch-procedure)

  ;; Load extensions
  (for-each (lambda (p) (p larc))
            *larceny-environment-extensions*)
  ;(set! *larceny-environment-extensions* (undefined))
  
  larc)

; eof
