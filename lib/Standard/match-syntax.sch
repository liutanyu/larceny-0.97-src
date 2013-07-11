; Andrew Wright's "MATCH" macro, for Larceny.  
; 2000-05-21 / lth
;
; Syntax.  Do not compile this file.  See also "match.sch".

(require 'defmacro)

(defmacro
  match
  args
  (cond ((and (list? args)
              (<= 1 (length args))
              (match:andmap
                (lambda (y) (and (list? y) (<= 2 (length y))))
                (cdr args)))
         (let* ((exp (car args))
                (clauses (cdr args))
                (e (if (symbol? exp) exp (gentemp))))
           (if (symbol? exp)
             ((car match:expanders) e clauses `(match ,@args))
             `(let ((,e ,exp))
                ,((car match:expanders) e clauses `(match ,@args))))))
        (else
         (match:syntax-err
           `(match ,@args)
           "syntax error in"))))

(defmacro
  match-lambda
  args
  (if (and (list? args)
           (match:andmap
             (lambda (g126)
               (if (and (pair? g126) (list? (cdr g126)))
                 (pair? (cdr g126))
                 #f))
             args))
    ((lambda ()
       (let ((e (gentemp)))
         `(lambda (,e) (match ,e ,@args)))))
    ((lambda ()
       (match:syntax-err
         `(match-lambda ,@args)
         "syntax error in")))))

(defmacro
  match-lambda*
  args
  (if (and (list? args)
           (match:andmap
             (lambda (g134)
               (if (and (pair? g134) (list? (cdr g134)))
                 (pair? (cdr g134))
                 #f))
             args))
    ((lambda ()
       (let ((e (gentemp)))
         `(lambda ,e (match ,e ,@args)))))
    ((lambda ()
       (match:syntax-err
         `(match-lambda* ,@args)
         "syntax error in")))))

(defmacro
  match-let
  args
  (let ((g158 (lambda (pat exp body)
                `(match ,exp (,pat ,@body))))
        (g154 (lambda (pat exp body)
                (let ((g (map (lambda (x) (gentemp)) pat))
                      (vpattern (list->vector pat)))
                  `(let ,(map list g exp)
                     (match (vector ,@g) (,vpattern ,@body))))))
        (g146 (lambda ()
                (match:syntax-err
                  `(match-let ,@args)
                  "syntax error in")))
        (g145 (lambda (p1 e1 p2 e2 body)
                (let ((g1 (gentemp)) (g2 (gentemp)))
                  `(let ((,g1 ,e1) (,g2 ,e2))
                     (match (cons ,g1 ,g2) ((,p1 unquote p2) ,@body))))))
        (g136 (cadddr match:expanders)))
    (if (pair? args)
      (if (symbol? (car args))
        (if (and (pair? (cdr args)) (list? (cadr args)))
          (let g161 ((g162 (cadr args)) (g160 '()) (g159 '()))
            (if (null? g162)
              (if (and (list? (cddr args)) (pair? (cddr args)))
                ((lambda (name pat exp body)
                   (if (match:andmap (cadddr match:expanders) pat)
                     `(let ,@args)
                     `(letrec ((,name (match-lambda* (,pat ,@body))))
                        (,name ,@exp))))
                 (car args)
                 (reverse g159)
                 (reverse g160)
                 (cddr args))
                (g146))
              (if (and (pair? (car g162))
                       (pair? (cdar g162))
                       (null? (cddar g162)))
                (g161 (cdr g162)
                      (cons (cadar g162) g160)
                      (cons (caar g162) g159))
                (g146))))
          (g146))
        (if (list? (car args))
          (if (match:andmap
                (lambda (g167)
                  (if (and (pair? g167)
                           (g136 (car g167))
                           (pair? (cdr g167)))
                    (null? (cddr g167))
                    #f))
                (car args))
            (if (and (list? (cdr args)) (pair? (cdr args)))
              ((lambda () `(let ,@args)))
              (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                (if (null? g150)
                  (g146)
                  (if (and (pair? (car g150))
                           (pair? (cdar g150))
                           (null? (cddar g150)))
                    (g149 (cdr g150)
                          (cons (cadar g150) g148)
                          (cons (caar g150) g147))
                    (g146)))))
            (if (and (pair? (car args))
                     (pair? (caar args))
                     (pair? (cdaar args))
                     (null? (cddaar args)))
              (if (null? (cdar args))
                (if (and (list? (cdr args)) (pair? (cdr args)))
                  (g158 (caaar args) (cadaar args) (cdr args))
                  (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                    (if (null? g150)
                      (g146)
                      (if (and (pair? (car g150))
                               (pair? (cdar g150))
                               (null? (cddar g150)))
                        (g149 (cdr g150)
                              (cons (cadar g150) g148)
                              (cons (caar g150) g147))
                        (g146)))))
                (if (and (pair? (cdar args))
                         (pair? (cadar args))
                         (pair? (cdadar args))
                         (null? (cdr (cdadar args)))
                         (null? (cddar args)))
                  (if (and (list? (cdr args)) (pair? (cdr args)))
                    (g145 (caaar args)
                          (cadaar args)
                          (caadar args)
                          (car (cdadar args))
                          (cdr args))
                    (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                      (if (null? g150)
                        (g146)
                        (if (and (pair? (car g150))
                                 (pair? (cdar g150))
                                 (null? (cddar g150)))
                          (g149 (cdr g150)
                                (cons (cadar g150) g148)
                                (cons (caar g150) g147))
                          (g146)))))
                  (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                    (if (null? g150)
                      (if (and (list? (cdr args)) (pair? (cdr args)))
                        (g154 (reverse g147) (reverse g148) (cdr args))
                        (g146))
                      (if (and (pair? (car g150))
                               (pair? (cdar g150))
                               (null? (cddar g150)))
                        (g149 (cdr g150)
                              (cons (cadar g150) g148)
                              (cons (caar g150) g147))
                        (g146))))))
              (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                (if (null? g150)
                  (if (and (list? (cdr args)) (pair? (cdr args)))
                    (g154 (reverse g147) (reverse g148) (cdr args))
                    (g146))
                  (if (and (pair? (car g150))
                           (pair? (cdar g150))
                           (null? (cddar g150)))
                    (g149 (cdr g150)
                          (cons (cadar g150) g148)
                          (cons (caar g150) g147))
                    (g146))))))
          (if (pair? (car args))
            (if (and (pair? (caar args))
                     (pair? (cdaar args))
                     (null? (cddaar args)))
              (if (null? (cdar args))
                (if (and (list? (cdr args)) (pair? (cdr args)))
                  (g158 (caaar args) (cadaar args) (cdr args))
                  (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                    (if (null? g150)
                      (g146)
                      (if (and (pair? (car g150))
                               (pair? (cdar g150))
                               (null? (cddar g150)))
                        (g149 (cdr g150)
                              (cons (cadar g150) g148)
                              (cons (caar g150) g147))
                        (g146)))))
                (if (and (pair? (cdar args))
                         (pair? (cadar args))
                         (pair? (cdadar args))
                         (null? (cdr (cdadar args)))
                         (null? (cddar args)))
                  (if (and (list? (cdr args)) (pair? (cdr args)))
                    (g145 (caaar args)
                          (cadaar args)
                          (caadar args)
                          (car (cdadar args))
                          (cdr args))
                    (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                      (if (null? g150)
                        (g146)
                        (if (and (pair? (car g150))
                                 (pair? (cdar g150))
                                 (null? (cddar g150)))
                          (g149 (cdr g150)
                                (cons (cadar g150) g148)
                                (cons (caar g150) g147))
                          (g146)))))
                  (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                    (if (null? g150)
                      (if (and (list? (cdr args)) (pair? (cdr args)))
                        (g154 (reverse g147) (reverse g148) (cdr args))
                        (g146))
                      (if (and (pair? (car g150))
                               (pair? (cdar g150))
                               (null? (cddar g150)))
                        (g149 (cdr g150)
                              (cons (cadar g150) g148)
                              (cons (caar g150) g147))
                        (g146))))))
              (let g149 ((g150 (car args)) (g148 '()) (g147 '()))
                (if (null? g150)
                  (if (and (list? (cdr args)) (pair? (cdr args)))
                    (g154 (reverse g147) (reverse g148) (cdr args))
                    (g146))
                  (if (and (pair? (car g150))
                           (pair? (cdar g150))
                           (null? (cddar g150)))
                    (g149 (cdr g150)
                          (cons (cadar g150) g148)
                          (cons (caar g150) g147))
                    (g146)))))
            (g146))))
      (g146))))

(defmacro
  match-let*
  args
  (let ((g176 (lambda ()
                (match:syntax-err
                  `(match-let* ,@args)
                  "syntax error in"))))
    (if (pair? args)
      (if (null? (car args))
        (if (and (list? (cdr args)) (pair? (cdr args)))
          ((lambda (body) `(let* ,@args)) (cdr args))
          (g176))
        (if (and (pair? (car args))
                 (pair? (caar args))
                 (pair? (cdaar args))
                 (null? (cddaar args))
                 (list? (cdar args))
                 (list? (cdr args))
                 (pair? (cdr args)))
          ((lambda (pat exp rest body)
             (if ((cadddr match:expanders) pat)
               `(let ((,pat ,exp)) (match-let* ,rest ,@body))
               `(match ,exp (,pat (match-let* ,rest ,@body)))))
           (caaar args)
           (cadaar args)
           (cdar args)
           (cdr args))
          (g176)))
      (g176))))

(defmacro
  match-letrec
  args
  (let ((g200 (cadddr match:expanders))
        (g199 (lambda (p1 e1 p2 e2 body)
                `(match-letrec
                   (((,p1 unquote p2) (cons ,e1 ,e2)))
                   ,@body)))
        (g195 (lambda ()
                (match:syntax-err
                  `(match-letrec ,@args)
                  "syntax error in")))
        (g194 (lambda (pat exp body)
                `(match-letrec
                   ((,(list->vector pat) (vector ,@exp)))
                   ,@body)))
        (g186 (lambda (pat exp body)
                ((cadr match:expanders)
                 pat
                 exp
                 body
                 `(match-letrec ((,pat ,exp)) ,@body)))))
    (if (pair? args)
      (if (list? (car args))
        (if (match:andmap
              (lambda (g206)
                (if (and (pair? g206)
                         (g200 (car g206))
                         (pair? (cdr g206)))
                  (null? (cddr g206))
                  #f))
              (car args))
          (if (and (list? (cdr args)) (pair? (cdr args)))
            ((lambda () `(letrec ,@args)))
            (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
              (if (null? g190)
                (g195)
                (if (and (pair? (car g190))
                         (pair? (cdar g190))
                         (null? (cddar g190)))
                  (g189 (cdr g190)
                        (cons (cadar g190) g188)
                        (cons (caar g190) g187))
                  (g195)))))
          (if (and (pair? (car args))
                   (pair? (caar args))
                   (pair? (cdaar args))
                   (null? (cddaar args)))
            (if (null? (cdar args))
              (if (and (list? (cdr args)) (pair? (cdr args)))
                (g186 (caaar args) (cadaar args) (cdr args))
                (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
                  (if (null? g190)
                    (g195)
                    (if (and (pair? (car g190))
                             (pair? (cdar g190))
                             (null? (cddar g190)))
                      (g189 (cdr g190)
                            (cons (cadar g190) g188)
                            (cons (caar g190) g187))
                      (g195)))))
              (if (and (pair? (cdar args))
                       (pair? (cadar args))
                       (pair? (cdadar args))
                       (null? (cdr (cdadar args)))
                       (null? (cddar args)))
                (if (and (list? (cdr args)) (pair? (cdr args)))
                  (g199 (caaar args)
                        (cadaar args)
                        (caadar args)
                        (car (cdadar args))
                        (cdr args))
                  (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
                    (if (null? g190)
                      (g195)
                      (if (and (pair? (car g190))
                               (pair? (cdar g190))
                               (null? (cddar g190)))
                        (g189 (cdr g190)
                              (cons (cadar g190) g188)
                              (cons (caar g190) g187))
                        (g195)))))
                (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
                  (if (null? g190)
                    (if (and (list? (cdr args)) (pair? (cdr args)))
                      (g194 (reverse g187) (reverse g188) (cdr args))
                      (g195))
                    (if (and (pair? (car g190))
                             (pair? (cdar g190))
                             (null? (cddar g190)))
                      (g189 (cdr g190)
                            (cons (cadar g190) g188)
                            (cons (caar g190) g187))
                      (g195))))))
            (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
              (if (null? g190)
                (if (and (list? (cdr args)) (pair? (cdr args)))
                  (g194 (reverse g187) (reverse g188) (cdr args))
                  (g195))
                (if (and (pair? (car g190))
                         (pair? (cdar g190))
                         (null? (cddar g190)))
                  (g189 (cdr g190)
                        (cons (cadar g190) g188)
                        (cons (caar g190) g187))
                  (g195))))))
        (if (pair? (car args))
          (if (and (pair? (caar args))
                   (pair? (cdaar args))
                   (null? (cddaar args)))
            (if (null? (cdar args))
              (if (and (list? (cdr args)) (pair? (cdr args)))
                (g186 (caaar args) (cadaar args) (cdr args))
                (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
                  (if (null? g190)
                    (g195)
                    (if (and (pair? (car g190))
                             (pair? (cdar g190))
                             (null? (cddar g190)))
                      (g189 (cdr g190)
                            (cons (cadar g190) g188)
                            (cons (caar g190) g187))
                      (g195)))))
              (if (and (pair? (cdar args))
                       (pair? (cadar args))
                       (pair? (cdadar args))
                       (null? (cdr (cdadar args)))
                       (null? (cddar args)))
                (if (and (list? (cdr args)) (pair? (cdr args)))
                  (g199 (caaar args)
                        (cadaar args)
                        (caadar args)
                        (car (cdadar args))
                        (cdr args))
                  (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
                    (if (null? g190)
                      (g195)
                      (if (and (pair? (car g190))
                               (pair? (cdar g190))
                               (null? (cddar g190)))
                        (g189 (cdr g190)
                              (cons (cadar g190) g188)
                              (cons (caar g190) g187))
                        (g195)))))
                (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
                  (if (null? g190)
                    (if (and (list? (cdr args)) (pair? (cdr args)))
                      (g194 (reverse g187) (reverse g188) (cdr args))
                      (g195))
                    (if (and (pair? (car g190))
                             (pair? (cdar g190))
                             (null? (cddar g190)))
                      (g189 (cdr g190)
                            (cons (cadar g190) g188)
                            (cons (caar g190) g187))
                      (g195))))))
            (let g189 ((g190 (car args)) (g188 '()) (g187 '()))
              (if (null? g190)
                (if (and (list? (cdr args)) (pair? (cdr args)))
                  (g194 (reverse g187) (reverse g188) (cdr args))
                  (g195))
                (if (and (pair? (car g190))
                         (pair? (cdar g190))
                         (null? (cddar g190)))
                  (g189 (cdr g190)
                        (cons (cadar g190) g188)
                        (cons (caar g190) g187))
                  (g195)))))
          (g195)))
      (g195))))

(defmacro
  match-define
  args
  (let ((g210 (cadddr match:expanders))
        (g209 (lambda ()
                (match:syntax-err
                  `(match-define ,@args)
                  "syntax error in"))))
    (if (pair? args)
      (if (g210 (car args))
        (if (and (pair? (cdr args)) (null? (cddr args)))
          ((lambda () `(begin (define ,@args))))
          (g209))
        (if (and (pair? (cdr args)) (null? (cddr args)))
          ((lambda (pat exp)
             ((caddr match:expanders)
              pat
              exp
              `(match-define ,@args)))
           (car args)
           (cadr args))
          (g209)))
      (g209))))

; eof
