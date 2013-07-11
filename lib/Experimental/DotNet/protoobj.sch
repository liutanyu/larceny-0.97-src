;; Prototype based object system, with "features" like operation
;; reflection, inline documentation and delegation support.

;; This is only for the use within object extension for effecting
;; dispatch.
(define delegate-token (cons 0 0))

;; *Not* named-lambda; in particular, NAME is *not* bound in BODY ...
(define-syntax lambda-with-name
  (syntax-rules ()
    ((_ NAME (ARGS ...) BODY ...)
     (let ((proc (lambda (ARGS ...) BODY ...))) 
       (define (NAME ARGS ...) (proc ARGS ...)) NAME))
    ((_ NAME ARGL       BODY ...)
     (let ((proc (lambda ARGL BODY ...))) 
       (define (NAME . rest) (apply proc rest)) NAME))
    ))

;; delegate : Obj Sym Obj -> Method
;; (delegate obj-1 op obj-2) extracts the method M named op from
;; obj-1, and then fixes the self parameter of M with obj-2.
;; 
;; Usual dispatch of tgt.op can be thought of as doing 
;; (delegate tgt op tgt)
;; Passing the buck (via inheritance) can be thought of as doing
;; (delegate (parentof tgt) op tgt)
(define (delegate method-source op receiver)
  ((method-source delegate-token) op receiver))

(define-syntax make-documented-root-object
  (syntax-rules ()
    ((root-object self ((OP-NAME . ARGS) DOC-STRING BODY ...) ...)
     (letrec ((document (lambda (op-sym arglst docstr) 
                          (format #t "~a: ~a ~a" op-sym arglst docstr)
                          (newline)))
              (core-object
               ;; This use of the id 'self' is important (it is
               ;; semantically significant so that we actually
               ;; have true dynamic dispatch when one uses methods
               ;; on self within BODY)
               (lambda (op self)
                 (case op
                   ((OP-NAME) 
                    ;; no need to include DOC-STRING; when originally
                    ;; present, add-default-doc copies into BODY ...
                    (lambda-with-name OP-NAME ARGS BODY ...))
                   ...
                   ((documentation)
                    (lambda-with-name documentation (op)
                      (case op 
                        ((OP-NAME) 
                         (let ((docstr (or DOC-STRING "undocumented")))
                           (document 'OP-NAME 'ARGS docstr)))
                        ... 
                        ((documentation) 
                         (let ((doc-string-for-doc
                                "prints documentation of operation symbol op"))
                           (document 'documentation '(op) doc-string-for-doc)))
                        ((operations)
                         (document 'operations '() 
                                   "=> list of operation symbols"))
                        (else (error 'documentation 
                                     ": no method " op " in " self)))))
                   ((operations) 
                    (lambda-with-name 
                     operations () '(OP-NAME ... documentation operations)))
                   ;; This 'self' is only for error msg documentation
                   (else (error 'self
                                ": unhandled object message " op)))))
              (self 
               ;; This 'self' is only for proc documentation; (it is
               ;; sound to alpha rename w/ sole occurrence below)
               (lambda (op)
                 ;; (display `(handling msg ,op)) (newline)
                 (if (eq? op delegate-token)
                     core-object
                     ;; Here we tie knot marrying dispatch function w/ self.
                     (core-object op self)))))
       self))))

(define (add-default-doc method-definition)
  (let ((op-signature (car method-definition))
        (op-body (cdr method-definition)))
    (cons op-signature 
          (cons (if (string? (car op-body))
                    (car op-body) ; already documented
                    #f) ; marks method as undocumented
                op-body))))

(define-syntax make-root-object
  (transformer 
   (lambda (exp ren cmp)
     `(,(ren 'make-documented-root-object)
       ,(cadr exp)
       ,@(map add-default-doc (cddr exp))))))

(define-syntax msg-handler
  (syntax-rules ()
    ((msg-handler ((OP-NAME . ARGS) BODY ...) ...)
     (make-root-object self-name ((OP-NAME . ARGS) BODY ...) ...))))

(define-syntax extend-object-documented
  (syntax-rules ()
    ((_ super-expr self ((OP-NAME . ARGS) DOC-STRING BODY ...) ...)
     (letrec ((super-obj super-expr)
              (core-object 
               (lambda (op self)
                 (case op 
                   ;; See above re: this use of id 'self'
                   ((OP-NAME) 
                    (lambda-with-name OP-NAME ARGS DOC-STRING BODY ...))
                   ...
                   ((documentation op)
                    (lambda-with-name documentation (op)
                      (case op
                        ((OP-NAME) 
                         (let ((doc->annotated
                                (lambda (str)
                                  (format #t "~a: ~a ~a" 'OP-NAME 'ARGS str)
                                  (newline))))
                           (cond 
                            (DOC-STRING => doc->annotated)
                            ((memq op ((super-obj 'operations)))
                             ((super-obj 'documentation) op))
                            (else
                             (doc->annotated "undocumented")))))
                        ...
                        (else 
                         ((super-obj 'documentation) op)))))
                   ((operations) 
                    (lambda () (append '(OP-NAME ... documentation operations)
                                       ((super-obj 'operations)))))
                   (else (delegate super-obj op self)))))
              (self ;; See above re: this use of id 'self'
               (lambda (op)
                 (if (eq? op delegate-token)
                     core-object
                     ;; Here we tie knot marrying dispatch function w/ self.
                     (core-object op self)))))
       self))))

(define-syntax extend-object 
  (transformer 
   (lambda (exp ren cmp)
     `(,(ren 'extend-object-documented)
       ,(cadr exp)  ; super expr
       ,(caddr exp) ; self identifer
       ,@(map add-default-doc (cdddr exp))))))

;; SAMPLE USAGE OF ABOVE OBJECT SYSTEM
(begin 
  (define (make-point x y) 
    (make-root-object 
     point-self
     ((x) "selector" x)
     ((y) "selector" y)
     ((move dx dy) 
      "=> new point shifted by vector (dx,dy)" 
      (make-point (+ x dx) (+ y dy)))))
  (define some-tests
    (let () 
      (make-point 1 2)                ; => #<procedure point-self>
      ((make-point 1 2) 'x)           ; => #<procedure x>
      (((make-point 1 2) 'x))         ; => 1
      (((make-point 1 2) 'y))         ; => 2
      (((make-point 1 2) 'move) 3 4)  ; => #<procedure point-self>
      (let* ((p1 (make-point 1 2))
             (p2 ((p1 'move) 5 8)))
        ((p2 'x)))                    ; => 6
      ))
  (define (make-colored-point x y col)
    (define (add-color-to-point p)
      (extend-object p 
       colored-self 
       ((color) "selector" col)
       ((move x y) 
        (add-color-to-point ((delegate p 'move colored-self) x y)))
       ))
    (add-color-to-point (make-point x y)))
  (define some-more-tests
    (let ()
      (make-colored-point 10 20 'black) 
      ;; => #<interpreted-procedure colored-self>
      (let ((cp (make-colored-point 10 20 'black)))
        ((cp 'x)))                      ; => 10
      (let* ((cp1 (make-colored-point 10 20 'black))
             (cp2 ((cp1 'move) 4 7)))
        ((cp2 'color)))                 ; => black
      ))
  )
