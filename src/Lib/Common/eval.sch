; Copyright 1998 Lars T Hansen.
;
; $Id: eval.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; `Eval' procedure.
;
; Eval is a simple procedure: it calls the value of the system parameter
; `evaluator' with two arguments, the expression and the environment.
; The environment is an optional argument to eval, but not to the evaluator
; procedure.

($$trace "eval")

(define evaluator
  (make-parameter "evaluator"
                  (lambda (expr env)
                    (error "No evaluator procedure installed."))
                  procedure?))

(define (eval expr . rest)
  ((evaluator) expr
   (cond ((null? rest)
          (interaction-environment))
         ((and (null? (cdr rest))
               (environment? (car rest)))
          (car rest))
         (else
          (error "Eval: bad arguments: " rest)
          #t))))

; eof
