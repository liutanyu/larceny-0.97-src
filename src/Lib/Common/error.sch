; Copyright 1998 Lars T Hansen.               -*- indent-tabs-mode: nil -*-
;
; $Id: error.sch 5874 2008-12-22 16:59:09Z will $
;
; Larceny library -- higher-level error system.

($$trace "error")

; R6RS-style programs should never enter Larceny's debugger,
; because Larceny's R6RS modes are designed for batch-mode
; execution by people who don't know anything about Scheme.
; Programmers should use ERR5RS mode instead of R6RS modes.

(define (unhandled-exception-error x)
  (let ((emode (cdr (assq 'execution-mode (system-features)))))
    (case emode
     ((dargo spanky)
      (let ((out (current-error-port)))
        (newline out)
        (display "Error: no handler for exception " out)
        (write x out)
        (newline out)
        (if (condition? x)
            (display-condition x out))
        (newline out)
        (display "Terminating program execution." out)
        (newline out)
        (exit 1)))
     (else
      ((error-handler) x)))))

; Heuristically recognizes both R6RS-style and Larceny's old-style
; arguments.
;
; The R6RS exception mechanism is used if and only if
;     the program is executing in an R6RS mode, or
;     a custom exception handler is currently installed,
;         and the arguments are acceptable to the R6RS.

(define (use-r6rs-mechanism? who msg)
  (let ((emode (cdr (assq 'execution-mode (system-features)))))
    (or (memq emode '(dargo spanky))
        (and (custom-exception-handlers?)
             (or (symbol? who) (string? who) (eq? who #f))
             (string? msg)))))

(define (error . args)
  (if (and (pair? args) (pair? (cdr args)))
      (let ((who (car args))
            (msg (cadr args))
            (irritants (cddr args))
            (handler (error-handler)))
        (define (separated irritants)
          (if (null? irritants)
              '()
              (cons " "
                    (cons (car irritants) (separated (cdr irritants))))))
        (if (string? msg)
            (cond ((use-r6rs-mechanism? who msg)
                   (raise-r6rs-exception (make-error) who msg irritants))
                  ((or (symbol? who) (string? who))
                   (apply handler who msg (separated irritants)))
                  ((eq? who #f)
                   (apply handler msg (separated irritants)))
                  (else
                   ; old-style
                   (apply handler '() args)))
            (apply handler '() args)))
      (apply (error-handler) '() args)))

(define (assertion-violation who msg . irritants)
  (if (or #t (use-r6rs-mechanism? who msg)) ; FIXME
      (raise-r6rs-exception (make-assertion-violation) who msg irritants)
      (apply error who msg irritants)))

(define (reset)
  ((reset-handler)))

; To be replaced by exception system.

(define (call-without-errors thunk . rest)
  (let ((fail (if (null? rest) #f (car rest))))
    (call-with-current-continuation
     (lambda (k)
       (call-with-error-handler (lambda (who . args) (k fail)) thunk)))))

; Old code: clients should use PARAMETERIZE instead.

(define (call-with-error-handler handler thunk)
  (let ((old-handler (error-handler)))
    (dynamic-wind 
     (lambda () (error-handler handler))
     thunk
     (lambda () (error-handler old-handler)))))

; Old code: clients should use PARAMETERIZE instead.

(define (call-with-reset-handler handler thunk)
  (let ((old-handler (reset-handler)))
    (dynamic-wind 
     (lambda () (reset-handler handler))
     thunk
     (lambda () (reset-handler old-handler)))))

; DECODE-ERROR takes a list (describing an error) and optionally
; a port to print on (defaults to the current error port) and
; prints a human-readable error message to the port based on the
; information in the error.
;
; The error is a list.  The first element is a key, the rest depend on the
; key.  There are three cases, depending on the key:
;  - a number:  The error is a primitive error.  There will be three
;               additional values, the contents of RESULT, SECOND, and
;               THIRD.
;  - null:      The key is to be ignored, and the following elements are
;               to be interpreted as though they were arguments passed
;               to the error procedure.
;  - otherwise: The elements are to be interpreted as though they were
;               arguments passed to the error procedure.
;
; There is also a special subcase of the third case above:
; If the key is a condition, and there are no other elements
; of the list, then the condition is assumed to describe an
; unhandled exception that has been raised.

(define (decode-error the-error . rest)
  (let ((who (car the-error))
        (port (if (null? rest) (current-error-port) (car rest))))
    (cond ((and (number? who)
                (list? the-error)
                (= 4 (length the-error)))
           (decode-system-error who 
                                (cadr the-error) 
                                (caddr the-error)
                                (cadddr the-error)
                                port))
          (else
           (newline port)
           (display "Error: " port)
           (cond ((and (condition? who) (null? (cdr the-error)))
                  (display "unhandled condition:" port)
                  (newline port)
                  (display-condition who port))
                 ((not (null? who))
                  (display who port)
                  (display ": " port)))
           (for-each (lambda (x) (display x port)) (cdr the-error))
           (newline port)
           (flush-output-port port)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Transition to R6RS conditions and exception mechanism.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; FIXME:  This is an awful hack to connect two exception systems
; via the messages produced by Larceny.

(define (decode-and-raise-r6rs-exception the-error)
  (let* ((out (open-output-string))
         (msg (begin (decode-error the-error out)
                     (get-output-string out)))
         (larceny-system-prefix "\nError: ")
         (n (string-length larceny-system-prefix))
         (larceny-style?
          (and (< n (string-length msg))
               (string=? larceny-system-prefix (substring msg 0 n))))
         (msg (if larceny-style?
                  (substring msg n (string-length msg))
                  msg))
         (chars (if larceny-style? (string->list msg) '()))
         (colon (memq #\: chars))
         (who (if colon
                  (substring msg 0 (- (string-length msg) (length colon)))
                  #f))
         (msg (if colon (list->string (cdr colon)) msg))
         (c0 (make-assertion-violation))
         (c1 (make-message-condition msg)))
    (raise
     (if who
         (condition c0 (make-who-condition who) c1)
         (condition c0 c1)))))

(define (raise-r6rs-exception c0 who msg irritants)
  (let ((c1 (cond ((or (symbol? who) (string? who))
                   (make-who-condition who))
                  ((eq? who #f)
                   #f)
                  (else
                   (condition
                    (make-violation)
                    (make-who-condition 'make-who-condition)
                    (make-irritants-condition (list who))))))
        (c2 (cond ((string? msg)
                   (make-message-condition msg))
                  (else
                   (condition
                    (make-assertion-violation)
                    (make-who-condition 'make-message-condition)
                    (make-irritants-condition (list msg))))))
        (c3 (make-irritants-condition irritants)))
    (raise
     (if who
         (condition c0 c1 c2 c3)
         (condition c0 c2 c3)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Warns of deprecated features.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define issue-deprecated-warnings?
  (make-parameter "issue-deprecated-warnings?" #t))

(define (issue-warning-deprecated name-of-deprecated-misfeature)
  (if (not (memq name-of-deprecated-misfeature already-warned))
      (begin
       (set! already-warned
             (cons name-of-deprecated-misfeature already-warned))
       (if (issue-deprecated-warnings?)
           (let ((out (current-error-port)))
             (display "WARNING: " out)
             (display name-of-deprecated-misfeature out)
             (newline out)
             (display "    is deprecated in Larceny.  See" out)
             (newline out)
             (display "    " out)
             (display url:deprecated out)
             (newline out))))))

(define url:deprecated
  "http://larceny.ccs.neu.edu/larceny-trac/wiki/DeprecatedFeatures")

; List of deprecated features for which a warning has already
; been issued.

(define already-warned '())

; eof
