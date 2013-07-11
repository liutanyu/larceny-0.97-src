; Copyright 1999 Lars T Hansen
;
; $Id: undefined.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; List all variables that have #!undefined value in the environment.

(define (undefined-vars env)
  (filter (lambda (v)
            (not (environment-variable? env v)))
          (environment-variables env)))

; eof
