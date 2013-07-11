; Copyright 1998 Lars T Hansen.
;
; $Id: inspect-cont.sch 3493 2006-09-11 06:21:41Z pnkfelix $
;
; Continuation and frame inspector.

; Continuation inspector.
;
; (c 'type)       => continuation       Identifier
; (c 'down)       => <boolean>          Move to the previous frame
; (c 'probe-down) => <boolean>          Is there a previous frame?
; (c 'up)         => <boolean>          Move to the next frame
; (c 'probe-up)   => <boolean>          Is there a next frame?
; (c 'frames)     => <number>           Number of frames
; (c 'get)        => <frame>            Inspector for current frame
; (c 'clone)      => <continuation>     Return inspector with 

(define (make-continuation-inspector c)

  (define previous '())			; Stack of previous frames
  (define current #f)			; Current frame
  (define c-length #f)

  (define (move-next)
    (let ((next (current 'link)))
      (if (not next)
	  #f
	  (begin (set! previous (cons current previous))
		 (set! current next)
		 #t))))

  (define (move-prev)
    (if (null? previous)
	#f
	(begin (set! current (car previous))
	       (set! previous (cdr previous))
	       #t)))

  (define (continuation-length c)
    (do ((i 0 (+ i 1))
	 (x (make-frame-inspector c) (x 'link)))
	((not x) i)))

  (set! current (make-frame-inspector c))
  (set! c-length (continuation-length c))

  (lambda (command)
    (case command
      ((type)       'continuation)
      ((down)       (move-next))
      ((probe-down) (not (eq? #f (current 'link))))
      ((up)         (move-prev))
      ((probe-up)   (not (null? previous)))
      ((frames)     c-length)
      ((get)        current)
      ((clone)      (make-continuation-inspector c))
      (else         (error "Continuation-inspector " command)))))


; Frame inspector.
;
; (f 'type)        => frame             Identifier
; (f 'slots)       => <number>          Number of slots
; (f 'ref-slot n)  => <object>          nth slot
; (f 'vars)        => <number>          Number of free variables
; (f 'ref n)       => <variable>        Inspector for nth variable
; (f 'code)        => <code>            Code inspector
; (f 'link)        => <frame> | #f      Next outer frame
; (f 'same? f2)    => boolean           Compare

(define (make-frame-inspector f)

  (define frame:return-offset 0)	; Offset of return address
  (define frame:dynamic-link 1)		; Offset of dynamic link
  (define frame:reg0 2)			; Offset of slot 0

  (define variables #f)			; List of variables

  (define (compute-variables)
    (set! variables '()))		; No variable info available yet.

  (lambda (command . rest)
    (case command
      ((type)
       'continuation-frame)
      ((slots)
       (- (vector-length f) frame:reg0))
      ((ref-slot)
       (vector-ref f (+ frame:reg0 (car rest))))
      ((vars)
       (compute-variables)
       (length variables))
      ((ref-var)
       (compute-variables)
       (if (<= 0 (car rest) (- (length variables) 1))
	   (list-ref variables (car rest))
	   (error (car rest) " is not a valid variable index.")))
      ((code)
       (make-code-inspector (vector-ref f frame:reg0)
			    (vector-ref f frame:return-offset)))
      ((link)
       (let ((link (vector-ref f frame:dynamic-link)))
	 (if link
	     (make-frame-inspector link)
	     #f)))
      ((same?)
       (eq? f ((car rest) '$$the-frame)))
      (($$the-frame)
       f)
      (else
       (error "Frame-inspector " command)))))

; Code inspector.
;
; (c 'type)
; (c 'class)
; (c 'expression)
; (c 'procedure)

(define (make-code-inspector p ret-addr)

  (define class
    (cond ((eq? p 0)	               'system-procedure)
	  ((interpreted-primitive? p)  'interpreted-primitive)
	  ((interpreted-expression? p) 'interpreted-expression)
	  (else                        'compiled-procedure)))

  (define (make-readable-variables vars)
    (cond ((symbol? vars)
	   (make-readable-variable vars))
	  ((pair? vars)
	   (cons (make-readable-variable (car vars))
		 (make-readable-variables (cdr vars))))))

  (define (make-readable-variable var)
    (let* ((s (symbol->string var))
	   (l (string-length s)))
      (let loop ((i (- l 1)) (x #f))
	(cond ((< i 0) 
	       (if (not x)
		   var
		   (string->symbol (substring s 1 x))))
	      ((char=? (string-ref s i) #\|)
	       (loop (- i 1) i))
	      (else
	       (loop (- i 1) x))))))

  (define (make-readable expr)
    (cond ((symbol? expr)
	   (make-readable-variable expr))
	  ((eq? 'quote (car expr))
	   expr)
	  ((eq? 'begin (car expr))
	   (cons 'begin (map make-readable (cdr expr))))
	  ((eq? 'set! (car expr))
	   (list 'set! (cadr expr) (make-readable (caddr expr))))
	  ((eq? 'if (car expr))
	   (list 'if 
		 (make-readable (cadr expr))
		 (make-readable (caddr expr))
		 (make-readable (cadddr expr))))
	  ((eq? 'lambda (car expr))
	   (list 'lambda 
		 (make-readable-variables (cadr expr))
		 (make-readable (caddr expr))))
	  (else
	   (map make-readable expr))))

  (lambda (command)
    (case command
      ((type)
       'code)
      ((class)
       class)
      ((source-code)
       (if (eq? class 'system-procedure)
	   #f
	   (procedure-expression p)))
      ((expression)
       (if (interpreted-expression? p)
	   (cond ((interpreted-expression-source p) => make-readable)
		 (else #f))
	   #f))
      ((procedure)
       p)
      (else
       (error "Code-inspector " command)))))

; eof
