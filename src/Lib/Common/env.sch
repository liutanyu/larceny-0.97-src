; Copyright 1998 Lars T Hansen.
;
; $Id: env.sch 5729 2008-08-08 18:13:24Z pnkfelix $
;
; Larceny library -- environments.

($$trace "env")

; R5RS environment operations, somewhat extended.

(define *null-environment*)
(define *r4rs-environment*)
(define *r5rs-environment*)
(define *larceny-environment*)
(define *interaction-environment*)

(define (install-environments! null r4rs r5rs larceny)
  (set! *null-environment* null)
  (set! *r4rs-environment* r4rs)
  (set! *r5rs-environment* r5rs)
  (set! *larceny-environment* (environment-copy larceny))
  (set! *interaction-environment* larceny)
  (unspecified))

(define (interaction-environment . rest)
  (cond ((null? rest)
	 *interaction-environment*)
	((and (null? (cdr rest)))
	 (if (and (environment? (car rest))
		  (env.mutable (car rest)))
	     (set! *interaction-environment* (car rest))
	     (error "interaction-environment: " (car rest) 
		    " is not a mutable environment."))
	 (unspecified))
	(else
	 (error "interaction-environment: too many arguments.")
	 #t)))

;; Returns environment most recently installed as the Larceny
;; environment, as it was at install-environments! invocation
(define (larceny-initialized-environment)
  *larceny-environment*)

(define (scheme-report-environment version)
  (case version
    ((4)  *r4rs-environment*)
    ((5)  *r5rs-environment*)
    (else (error "scheme-report-environment: " version
		 " is not an accepted version number.")
	  #t)))

(define (null-environment version)
  (case version
    ((4 5) *null-environment*)
    (else  (error "null-environment: " version 
		  " is not an accepted version number.")
	   #t)))


; Global cells are represented as pairs, for now.  The compiler
; knows this, don't change it willy-nilly.

(define make-global-cell (lambda (value name) (cons value name)))
(define global-cell-ref  (lambda (cell) (car cell)))
(define global-cell-set! (lambda (cell value) (set-car! cell value)))


; Environment operations
;
; The rule is that an identifier has one denotation: it's either a
; variable or a macro, and it can transition from one to the other
; and back.  By default it is a variable.
;
; The problem is that the macro expander can remove and add macros
; behind the back of this interface, so we must check the macro env
; every time.

; Note that those structures must contain a fake record
; hierarchy in slot 0, to avoid breaking our new improved
; implementation of records.
;
; FIXME: the 15 should be large enough, but that depends
; on the record invariant.

(define *environment-key*
  (let ((fake-hierarchy (make-vector 15 #f)))
    (vector-set! fake-hierarchy 0 (list 'environment))
    fake-hierarchy))

(define (make-environment name)
  (let ((env (make-structure 6)))
    (vector-like-set! env 0 *environment-key*)
    (vector-like-set! env 1 (make-oldstyle-hashtable symbol-hash assq))
    (vector-like-set! env 2 #t)
    (vector-like-set! env 3 name)
    (vector-like-set! env 4 (make-minimal-syntactic-environment))
    ;; The next slot is used by the syntax-case macro and the module
    ;; system.  Although standard larceny doesn't use the slot, it
    ;; needs to carry it around so the loader, repl, debugger,
    ;; etc. will be able to interact with modules without major
    ;; headaches.

    ;; Auxiliary info
    (vector-like-set! env 5 #f)
    env))

(define (env.hashtable env)      (vector-like-ref env 1))
(define (env.mutable env)        (vector-like-ref env 2))
(define (env.name env)           (vector-like-ref env 3))
(define (env.syntaxenv env)      (vector-like-ref env 4))
(define (env.auxiliary-info env) (vector-like-ref env 5))

(define (env.mutable! env flag) (vector-like-set! env 2 flag))
(define (env.set-auxiliary-info! env new-value) (vector-like-set! env 5 new-value))

(define (environment? obj)
  (and (structure? obj)
       (> (vector-like-length obj) 0)
       (eq? *environment-key* (vector-like-ref obj 0))))

(define (environment-name env)
  (check-environment env 'environment-name)
  (env.name env))

(define (environment-variables env)
  (check-environment env 'environment-variables)
  (let ((macros (environment-macros env))
        (variables '()))
    (hashtable-for-each (lambda (id cell) 
                          (if (not (memq id macros))
                              (set! variables (cons id variables))))
                        (env.hashtable env))
    variables))

(define (environment-variable? env name)
  (check-environment env 'environment-variable?)
  (let ((probe1 (hashtable-get (env.hashtable env) name))
        (probe2 (environment-macro? env name)))
    (and (not probe2)
         probe1
         (not (eq? (global-cell-ref probe1) (undefined))))))
  
(define (environment-get env name)
  (check-environment env 'environment-get)
  (if (not (environment-macro? env name))
      (let ((probe (environment-get-cell env name)))
        (if (not (eq? (global-cell-ref probe) (undefined)))
            (global-cell-ref probe)
            (begin (error "environment-get: not defined: " name)
                   #t)))
      (begin (error "environment-get: denotes a macro: " name)
             #t)))

(define (environment-get-cell env name)
  (check-environment env 'environment-get-cell)
  (if (not (environment-macro? env name))
      (or (hashtable-get (env.hashtable env) name)
          (let ((cell (make-global-cell (undefined) name)))
            (hashtable-put! (env.hashtable env) name cell)
            cell))
      (begin 
        (error "environment-get-cell: denotes a macro: " name)
        #t)))

(define (environment-set! env name value)
  (check-environment env 'environment-set!)
  (cond ((not (env.mutable env))
         (error "environment-set!: environment is not mutable: "
                (env.name env))
         #t)
        ((environment-macro? env name)
         (syntactic-environment-remove! (environment-syntax-environment env)
                                        name)
         (environment-set! env name value))
        (else
         (let ((cell (environment-get-cell env name)))
           (global-cell-set! cell value)
           (unspecified)))))

(define (environment-link-variables! target-env target-name source-env source-name)
  ;; Define a new binding for TARGET-NAME in TARGET-ENV, which shares its
  ;; value cell with the binding for SOURCE-NAME in SOURCE-ENV.
  (check-environment source-env 'environment-link-variables!)
  (check-environment target-env 'environment-link-variables!)
  (cond ((not (env.mutable source-env))
         (error "environment-link-variables!:  source environment is not mutable: "
                (env.name source-env))
         #t)
        ((not (env.mutable target-env))
         (error "environment-link-variables!:  target environment is not mutable: "
                (env.name target-env))
         #t)
        ((environment-macro? target-env target-name)
         (syntactic-environment-remove! (environment-syntax-environment target-env)
                                        name)
         (environment-link-variables! target-env target-name source-env source-name))

        (else
         (let ((cell (environment-get-cell source-env source-name)))
           (hashtable-put! (env.hashtable target-env) target-name cell)
           (unspecified)))))

(define (environment-syntax-environment env)
  (check-environment env 'environment-syntax-environment)
  (env.syntaxenv env))

(define (environment-auxiliary-info env)
  (check-environment env 'environment-auxiliary-info)
  (env.auxiliary-info env))

(define (environment-set-auxiliary-info! env new-value)
  (check-environment env 'environment-set-auxiliary-info!)
  (env.set-auxiliary-info! env new-value))

;; Note:  environment-copy does *not* do anything with the
;; auxiliary-info field.
(define (environment-copy env . rest)
  (check-environment env 'environment-copy)
  (let* ((name      (if (null? rest) (environment-name env) (car rest)))
         (new       (make-environment name))
         (variables (environment-variables env))
         (macros    (environment-macros env)))
    (do ((vs variables (cdr vs)))
        ((null? vs))
      (if (environment-variable? env (car vs))
          (environment-set! new (car vs) (environment-get env (car vs)))))
    (do ((ms macros (cdr ms)))
        ((null? ms))
      (environment-set-macro! new (car ms) 
                              (environment-get-macro env (car ms))))
    new))

(define (environment-macros env)
  (check-environment env 'environment-macros)
  (syntactic-environment-names (environment-syntax-environment env)))

(define (environment-get-macro env id)
  (check-environment env 'environment-get-macro)
  (syntactic-environment-get (environment-syntax-environment env) id))

(define (environment-set-macro! env id macro)
  (check-environment env 'environment-set-macro!)
  (hashtable-remove! (env.hashtable env) id)
  (syntactic-environment-set! (environment-syntax-environment env) id macro))

(define (environment-macro? env id)
  (check-environment env 'environment-macro?)
  (not (not (syntactic-environment-get (environment-syntax-environment env) 
                                       id))))

(define (check-environment env tag)
  (if (not (environment? env))
      (error tag ": not an environment: " env)))

; LOAD still uses this (though READ).
;
; The initial environment is undefined, to avoid capturing a lot of
; global bindings if the reader is included in a dumped heap that
; does not use LOAD.

(define global-name-resolver
  (make-parameter "global-name-resolver"
		  (lambda (sym)
		    (error "GLOBAL-NAME-RESOLVER: not installed."))
		  procedure?))
     
; eof
