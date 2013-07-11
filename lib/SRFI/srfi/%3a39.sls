;;; SRFI-39: parameter objects
;;;
;;; $Id: %3a39.sls 6145 2009-03-18 15:34:18Z will $
;;;
;;; More or less compatible with Larceny's built-in parameter objects,
;;; in the absence of threads anyway: a parameter object is a
;;; procedure with local state.  PARAMETERIZE just manipulates the
;;; local state and uses DYNAMIC-WIND to ensure that it is restored on
;;; exit from the body.
;;;
;;; In Larceny, MAKE-PARAMETER takes a name, a value, and a validity
;;; checker procedure.  The SRFI-39 signature is completely different.

(library (srfi :39 parameters)

  (export make-parameter parameterize)

  (import (rnrs base)
          (primitives errmsg))

  (define (make-parameter value . rest)
    (let ((converter (if (null? rest) (lambda (x) x) (car rest))))
      (set! value (converter value))
      (lambda args
        (cond ((null? args) 
               value)
              ((null? (cdr args))
               (set! value (converter (car args))))
              (else
               (error 'make-parameter 
                      (errmsg 'msg:toomanyargs)))))))

  ; (parameterize ((p1 e1) ...) b1 b2 ...)
  ; where each p1 is the name of a parameter (a procedure of 0 or 1 args).
  ;
  ; SRFI 39 says this should affect only the local dynamic environment.

  (define-syntax parameterize
    (syntax-rules ()
      ((parameterize ((p1 e1) ...) b1 b2 ...)
       (letrec-syntax 
           ((parameterize-aux
             (... (syntax-rules ()
                    ((parameterize-aux (t ...) ((p0 e0) x ...) body1 body2 ...)
                     (let ((tempE e0)
                           (tempP p0))
                       (parameterize-aux ((tempE tempP) t ...) 
                                         (x ...) 
                                         body1 body2 ...)))
                    ((parameterize-aux ((tE tP) ...) () body1 body2 ...)
                     (let-syntax ((swap!
                                   (syntax-rules ()
                                     ((swap! var param)
                                      (let ((tmp var))
                                        (set! var (param))
                                        (param tmp))))))
                       (dynamic-wind
                        (lambda ()
                          (swap! tE tP) ...)
                        (lambda ()
                          body1 body2 ...)
                        (lambda ()
                          (swap! tE tP) ...))))))))
         (parameterize-aux () ((p1 e1) ...) b1 b2 ...)))))

  )

(library (srfi :39)
  (export make-parameter parameterize)
  (import (srfi :39 parameters)))

; eof
