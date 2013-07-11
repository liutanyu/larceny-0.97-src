; Copyright 1991 Lightship Software, Incorporated.
; 
; $Id: pass5p1.sch 5720 2008-08-06 18:08:04Z pnkfelix $
;
; Target-independent part of the assembler.
;
; This is a simple, table-driven, one-pass assembler.
; Part of it assumes a big-endian target machine.
;
; The input to this pass is a list of symbolic MacScheme machine
; instructions and pseudo-instructions.  Each symbolic MacScheme 
; machine instruction or pseudo-instruction is a list whose car
; is a small non-negative fixnum that acts as the mnemonic for the
; instruction.  The rest of the list is interpreted as indicated
; by the mnemonic.
;
; The output is a pair consisting of machine code (a bytevector or 
; string) and a constant vector.
;
; This assembler is table-driven, and may be customized to emit
; machine code for different target machines.  The table consists
; of a vector of procedures indexed by mnemonics.  Each procedure
; in the table should take two arguments: an assembly structure
; and a source instruction.  The procedure should just assemble
; the instruction using the operations defined below.
;
; The table and target can be changed by redefining the following 
; six procedures.

(define (assembly-table) (error "No assembly table defined."))
(define (assembly-start as) #t)
(define (assembly-end as segment) segment)
(define (assembly-user-data) #f)
(define (assembly-user-local) #f)
(define (assembly-declarations user-data) '())
(define (assembly-postpass-segment as segment) segment)

; The main entry point.

(define (assemble source . rest)
  (define (instrumented! event x)
    (let ((hook (twobit-timer-hook)))
      (if hook
          (hook 'assemble event x))
      x))
  (instrumented! 'begin source)
  (let* ((user (if (null? rest) (assembly-user-data) (car rest)))
         (as   (make-assembly-structure source (assembly-table) user)))
    (assembly-start as)
    (instrumented!
     'end
     (assemble1 as
                (lambda (as)
                  (let ((segment (assembly-postpass-segment 
                                  as (assemble-pasteup as))))
                    (assemble-finalize! as)
                    (assembly-end as segment)))
                  #f))))

; The following procedures are to be called by table routines.
;
; The assembly source for nested lambda expressions should be
; assembled by calling this procedure.  This allows an inner
; lambda to refer to labels defined by outer lambdas.
;
; We delay the assembly of the nested lambda until after the outer lambda
; has been finalized so that all labels in the outer lambda are known
; to the inner lambda.
;
; The continuation procedure k is called to backpatch the constant
; vector of the outer lambda after the inner lambda has been
; finalized.  This is necessary because of the delayed evaluation: the
; outer lambda holds code and constants for the inner lambda in its
; constant vector.

(define (assemble-nested-lambda as source doc k . rest)
  (let* ((user (if (null? rest) #f (car rest)))
	 (nested-as (make-assembly-structure source (as-table as) user)))
    (as-parent! nested-as as)
    (as-nested! as (cons (lambda ()
			   (assemble1 nested-as 
				      (lambda (nested-as)
					(let ((segment
                                               (assembly-postpass-segment
                                                nested-as (assemble-pasteup nested-as))))
					  (assemble-finalize! nested-as)
					  (k nested-as segment)))
				      doc))
			 (as-nested as)))))

(define operand0 car)      ; the mnemonic
(define operand1 cadr)
(define operand2 caddr)
(define operand3 cadddr)
(define (operand4 i) (car (cddddr i)))
(define (operand5 i) (cadr (cddddr i)))

; Emits the bits contained in the bytevector bv.

(define (emit! as bv)
  (as-code! as (cons bv (as-code as)))
  (as-lc! as (+ (as-lc as) (bytevector-length bv))))

; Emits the characters contained in the string s as code (for C generation).

(define (emit-string! as s)
  (as-code! as (cons s (as-code as)))
  (as-lc! as (+ (as-lc as) (string-length s))))

; Given any Scheme object that may legally be quoted, returns an
; index into the constant vector for that constant.
;
; Constants are normally shared, with each constant appearing
; only once within the constant vector no matter how many times
; it appears within the code.
;
; The search required to implement that sharing currently takes
; time proportional to the number of constants that have been
; emitted so far.  To limit quadratic behavior, the search is
; abandoned if the constant being emitted is not equal to one
; of the first constants emitted.
;
; FIXME:  We'd like to use hashtables here instead of searching
; a list, but hashtables would make this code less portable.

(define (emit-constant as x)
  (define emit-constant:limit 50)
  (do ((i 0 (+ i 1))
       (y (as-constants as) (cdr y)))
      ((or (null? y)
           (>= i emit-constant:limit)
           (equal? x (car y)))
       (if (or (null? y)
               (>= i emit-constant:limit))
           (adjoin-constant as x)
           i))))

(define (emit-datum as x)
  (emit-constant as (list 'data x)))

(define (emit-global as x)
  (emit-constant as (list 'global x)))

(define (emit-codevector as x)
  (emit-constants as (list 'codevector x)))

(define (emit-constantvector as x)
  (emit-constants as (list 'constantvector x)))

; Set-constant changes the datum stored, without affecting the tag.
; It can operate on the list form because the pair stored in the list
; is shared between the list and any vector created from the list.

(define (set-constant! as n datum)
  (let ((pair (list-ref (as-constants as) n)))
    (set-car! (cdr pair) datum)))

; Guarantees that the constants will not share structure
; with any others, and will occupy consecutive positions
; in the constant vector.  Returns the index of the first
; constant.

(define (emit-constants as x . rest)
  (let ((i (adjoin-constant as x)))
    (for-each (lambda (y) (adjoin-constant as y))
              rest)
    i))

; Defines the given label using the current location counter.

(define (emit-label! as l)
  (set-cdr! l (as-lc as)))

; Adds the integer n to the size code bytes beginning at the
; given byte offset from the current value of the location counter.

(define (emit-fixup! as offset size n)
  (as-fixups! as (cons (list (+ offset (as-lc as)) size n)
		       (as-fixups as))))

; Adds the value of the label L to the size code bytes beginning
; at the given byte offset from the current location counter.

(define (emit-fixup-label! as offset size l)
  (as-fixups! as (cons (list (+ offset (as-lc as)) size (list l))
		       (as-fixups as))))

; Allows the procedure proc of two arguments (code vector and current
; location counter) to modify the code vector at will, at fixup time.

(define (emit-fixup-proc! as proc)
  (as-fixups! as (cons (list (as-lc as) 0 proc)
		       (as-fixups as))))

; Labels.

; The current value of the location counter.

(define (here as) (as-lc as))

; Given a MAL label (a number), create an assembler label.

(define (make-asm-label as label)
  (let ((probe (find-label as label)))
    (if probe
	probe
	(let ((l (cons label #f)))
          (label-hashtable-set! (as-labels-ht as) label l)
	  l))))

; This can use hashed lookup.

(define (find-label-locally as l)
  (label-hashtable-ref (as-labels-ht as) l #f))

(define (find-label as l)

  (define (lookup-label-loop as parent)
    (let ((entry (find-label-locally as l)))
      (cond (entry entry)
            (parent
             (lookup-label-loop parent (as-parent parent)))
	    (else #f))))
    
  (lookup-label-loop as (as-parent as)))

; Create a new assembler label, distinguishable from a MAL label.

(define new-label
  (let ((n 0))
    (lambda ()
      (set! n (- n 1))
      (cons n #f))))

; Given a value name (a number), return the label value or #f.

(define (label-value as l) (cdr l))

; For peephole optimization.

(define (next-instruction as)
  (let ((source (as-source as)))
    (if (null? source)
        '(-1)
        (car source))))

(define (consume-next-instruction! as)
  (as-source! as (cdr (as-source as))))

(define (push-instruction as instruction)
  (as-source! as (cons instruction (as-source as))))

; For use by the machine assembler: assoc lists connected to as structure.

(define (assembler-value as key)
  (let ((probe (assq key (as-values as))))
    (if probe
	(cdr probe)
	#f)))

(define (assembler-value! as key value)
  (let ((probe (assq key (as-values as))))
    (if probe
	(set-cdr! probe value)
	(as-values! as (cons (cons key value) (as-values as))))))

; For documentation.
;
; The value must be a documentation structure (a vector).

(define (add-documentation as doc)
  (let* ((existing-constants (cadr (car (as-constants as))))
	 (new-constants 
	  (twobit-sort (lambda (a b)
			 (< (car a) (car b)))
		       (cond ((not existing-constants)
			      (list (cons (here as) doc)))
			     ((pair? existing-constants)
			      (cons (cons (here as) doc)
				    existing-constants))
			     (else
			      (list (cons (here as) doc)
				    (cons 0 existing-constants)))))))
    (set-car! (cdar (as-constants as)) new-constants)))

; This is called when a value is too large to be handled by the assembler.
; Info is a string, expr an assembler expression, and val the resulting
; value.  The default behavior is to signal an error.

(define (asm-value-too-large as info expr val)
  (if (as-retry as)
      ((as-retry as))
      (asm-error info ": Value too large: " expr " = " val)))

; The implementations of asm-error and disasm-error depend on the host
; system. Sigh.

(define (asm-error msg . rest)
  (cond ((eq? host-system 'chez)
	 (error 'assembler "~a" (list msg rest)))
	(else
	 (apply error msg rest))))

(define (disasm-error msg . rest)
  (cond ((eq? host-system 'chez)
	 (error 'disassembler "~a" (list msg rest)))
	(else
	 (apply error msg rest))))

; The remaining procedures in this file are local to the assembler.

; An assembly structure is a vector consisting of
;
;    table            (a table of assembly routines)
;    source           (a list of symbolic instructions)
;    lc               (location counter; an integer)
;    code             (a list of bytevectors)
;    constants        (a list)
;    constants-last   (a list of length 0 or 1; last pair of constants list)
;    constants-length (an index; length of constants list)
;    labels           (an alist of labels and values)
;    fixups           (an alist of locations, sizes, and labels or fixnums)
;    nested           (a list of assembly procedures for nested lambdas)
;    values           (an assoc list)
;    parent           (an assembly structure or #f)
;    retry            (a thunk or #f)
;    user-data        (anything)
;    user-local       (anything)
;
; In fixups, labels are of the form (<L>) to distinguish them from fixnums.

(define (label? x) (and (pair? x) (fixnum? (car x))))
(define label.ident car)

; Adds x to the end of the constants list, preserving invariants.
; Returns the old length (1 less than the new length).

(define (adjoin-constant as x)
  (let ((last      (as-constants-last as))
        (newlast   (list x))
        (n         (as-constants-length as)))
    (or (eq? (null? last) (= n 0)) (asm-error 'adjoin-constant "assert fail"))
    (if (null? last)
        (as-constants! as (append! (as-constants as) newlast))
        (set-cdr! last newlast))
    (as-constants-last! as newlast)
    (as-constants-length! as (+ n 1))
    n))

; This level of abstraction hides the hashtable API we use.
;
; We have to use old-style hashtables here because that's
; the only kind we can count on when cross-compiling with
; systems other than Larceny.
;
; FIXME:
; Apparently each label represents a pair whose car is
; a fixnum (the MAL label) and whose cdr is something
; else (probably the offset or #f).  Although this pair
; is probably just a relic of the association lists that
; were originally used instead of a hashtable, the
; IAssassin, IL-LCG, and IL assemblers now appear to
; depend upon that relic.  That should be fixed.

(define (make-label-hashtable)
  (make-oldstyle-hashtable))

(define (label-hashtable-clear! ht)
  (hashtable-clear! ht))

(define (label-hashtable-ref ht l default)
  (hashtable-fetch ht l default))

(define (label-hashtable-set! ht l x)
  (hashtable-put! ht l x))

(define (as-labels as)
  (hashtable-map (lambda (x y) y)
                 (as-labels-ht as)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        

(define (make-assembly-structure source table user-data)
  (vector table
          source
          0
          '()
          '()
          '()
          0
          (make-label-hashtable)
          '()
          '()
	  '()
	  #f
	  #f
	  user-data
          (assembly-user-local)))

(define (as-reset! as source)
  (as-source! as source)
  (as-lc! as 0)
  (as-code! as '())
  (as-constants! as '())
  (as-constants-last! as '())
  (as-constants-length! as 0)
  (label-hashtable-clear! (as-labels-ht as))
  (as-fixups! as '())
  (as-nested! as '())
  (as-values! as '())
  (as-retry! as #f))

(define (as-table as)                 (vector-ref as 0))
(define (as-source as)                (vector-ref as 1))
(define (as-lc as)                    (vector-ref as 2))
(define (as-code as)                  (vector-ref as 3))
(define (as-constants as)             (vector-ref as 4))
(define (as-constants-last as)        (vector-ref as 5))
(define (as-constants-length as)      (vector-ref as 6))
(define (as-labels-ht as)             (vector-ref as 7))
(define (as-fixups as)                (vector-ref as 8))
(define (as-nested as)                (vector-ref as 9))
(define (as-values as)                (vector-ref as 10))
(define (as-parent as)                (vector-ref as 11))
(define (as-retry as)                 (vector-ref as 12))
(define (as-user as)                  (vector-ref as 13))
(define (as-user-local as)            (vector-ref as 14))

(define (as-source! as x)             (vector-set! as 1 x))
(define (as-lc! as x)                 (vector-set! as 2 x))
(define (as-code! as x)               (vector-set! as 3 x))
(define (as-constants! as x)          (vector-set! as 4 x))
(define (as-constants-last! as x)     (vector-set! as 5 x))
(define (as-constants-length! as x)   (vector-set! as 6 x))
;(define (as-labels-ht! as x)         (vector-set! as 7 x))
(define (as-fixups! as x)             (vector-set! as 8 x))
(define (as-nested! as x)             (vector-set! as 9 x))
(define (as-values! as x)             (vector-set! as 10 x))
(define (as-parent! as x)             (vector-set! as 11 x))
(define (as-retry! as x)              (vector-set! as 12 x))
(define (as-user! as x)               (vector-set! as 13 x))
(define (as-user-local! as x)         (vector-set! as 14 x))

; The guts of the assembler.

(define (assemble1 as finalize doc)
  (let ((assembly-table (as-table as))
	(peep? (peephole-optimization))
	(step? (single-stepping))
	(step-instr (list $.singlestep))
	(end-instr (list $.end)))

    (define (loop)
      (let ((source (as-source as)))
        (if (null? source)
	    (begin ((vector-ref assembly-table $.end) end-instr as)
		   (finalize as))
            (begin (if step?
		       ((vector-ref assembly-table $.singlestep)
			step-instr
			as))
		   (if peep?
		       (let peeploop ((src1 source))
			 (peep as)
			 (let ((src2 (as-source as)))
			   (if (not (eq? src1 src2))
			       (peeploop src2)))))
		   (let ((source (as-source as)))
		     (as-source! as (cdr source))
		     ((vector-ref assembly-table (caar source))
		      (car source)
		      as)
		     (loop))))))

    (define (doit)
      (emit-datum as doc)
      (loop))

    (let* ((source (as-source as))
	   (r (call-with-current-continuation
	       (lambda (k)
		 (as-retry! as (lambda () (k 'retry)))
		 (doit)))))
      (if (eq? r 'retry)
	  (let ((old (short-effective-addresses)))
	    (as-reset! as source)
	    (dynamic-wind
	     (lambda ()
	       (short-effective-addresses #f))
	     doit
	     (lambda ()
	       (short-effective-addresses old))))
	  r))))

(define (assemble-pasteup as)

  (define (pasteup-code)
    (let ((code      (make-bytevector (as-lc as)))
	  (constants (list->vector (as-constants as))))
    
      ; The bytevectors: byte 0 is most significant.

      (define (paste-code! bvs i)
	(if (not (null? bvs))
	    (let* ((bv (car bvs))
		   (n  (bytevector-length bv)))
	      (do ((i i (- i 1))
		   (j (- n 1) (- j 1)))	; (j 0 (+ j 1))
		  ((< j 0)		; (= j n)
		   (paste-code! (cdr bvs) i))
                (bytevector-set! code i (bytevector-ref bv j))))))
    
      (paste-code! (as-code as) (- (as-lc as) 1))
      (as-code! as (list code))
      (cons code constants)))

  (define (pasteup-strings)
    (let ((code      (make-string (as-lc as)))
	  (constants (list->vector (as-constants as))))

      (define (paste-code! strs i)
	(if (not (null? strs))
	    (let* ((s (car strs))
		   (n (string-length s)))
	      (do ((i i (- i 1))
		   (j (- n 1) (- j 1)))	; (j 0 (+ j 1))
		  ((< j 0)		; (= j n)
		   (paste-code! (cdr strs) i))
                (string-set! code i (string-ref s j))))))

      (paste-code! (as-code as) (- (as-lc as) 1))
      (as-code! as (list code))
      (cons code constants)))
  
  (define (pasteup-sexps)
    (let* ((beg*end (as-code as))
           (code (car beg*end))
           (constants (list->vector (as-constants as))))
      (cons code constants)))

  (cond ((bytevector? (car (as-code as)))
         (pasteup-code))
        ((string? (car (as-code as)))
         (pasteup-strings))
        ((pair? (car (as-code as)))
         (pasteup-sexps))
        (else
         (error 'assemble-pasteup "Unknown Code Representation"))))

(define (assemble-finalize! as)
  (let ((code (car (as-code as))))

    (define (apply-fixups! fixups)
      (if (not (null? fixups))
          (let* ((fixup      (car fixups))
                 (i          (car fixup))
                 (size       (cadr fixup))
                 (adjustment (caddr fixup))  ; may be procedure
                 (n          (if (label? adjustment)
				 (lookup-label adjustment)
				 adjustment)))
            (case size
	      ((0) (fixup-proc code i n))
              ((1) (fixup1 code i n))
              ((2) (fixup2 code i n))
              ((3) (fixup3 code i n))
              ((4) (fixup4 code i n))
              (else ???))
            (apply-fixups! (cdr fixups)))))

    (define (lookup-label l)
      (or (label-value as (label.ident l))
	  (asm-error "Assembler error -- undefined label " l)))

;   (assemble-finalize-report! as)                      ; FIXME: temporary hack

    (apply-fixups! (reverse! (as-fixups as)))

    (for-each (lambda (nested-as-proc)
		(nested-as-proc))
	      (as-nested as))))


; These fixup routines assume a big-endian target machine.

(define (fixup1 code i n)
  (bytevector-set! code i (+ n (bytevector-ref code i))))

(define (fixup2 code i n)
  (let* ((x  (+ (* 256 (bytevector-ref code i))
                (bytevector-ref code (+ i 1))))
         (y  (+ x n))
         (y0 (modulo y 256))
         (y1 (modulo (quotient (- y y0) 256) 256)))
    (bytevector-set! code i y1)
    (bytevector-set! code (+ i 1) y0)))

(define (fixup3 code i n)
  (let* ((x  (+ (* 65536 (bytevector-ref code i))
		(* 256 (bytevector-ref code (+ i 1)))
                (bytevector-ref code (+ i 2))))
         (y  (+ x n))
         (y0 (modulo y 256))
         (y1 (modulo (quotient (- y y0) 256) 256))
         (y2 (modulo (quotient (- y (* 256 y1) y0) 256) 256)))
    (bytevector-set! code i y2)
    (bytevector-set! code (+ i 1) y1)
    (bytevector-set! code (+ i 2) y0)))

(define (fixup4 code i n)
  (let* ((x  (+ (* 16777216 (bytevector-ref code i))
		(* 65536 (bytevector-ref code (+ i 1)))
		(* 256 (bytevector-ref code (+ i 2)))
		(bytevector-ref code (+ i 3))))
         (y  (+ x n))
         (y0 (modulo y 256))
         (y1 (modulo (quotient (- y y0) 256) 256))
         (y2 (modulo (quotient (- y (* 256 y1) y0) 256) 256))
         (y3 (modulo (quotient (- y (* 65536 y2)
                                    (* 256 y1)
                                    y0)
                               256)
                     256)))
    (bytevector-set! code i y3)
    (bytevector-set! code (+ i 1) y2)
    (bytevector-set! code (+ i 2) y1)
    (bytevector-set! code (+ i 3) y0)))

(define (fixup-proc code i p)
  (p code i))

; For testing.

(define (view-segment segment)
  (define (display-bytevector bv)
    (let ((n (bytevector-length bv)))
      (do ((i 0 (+ i 1)))
          ((= i n))
          (if (zero? (remainder i 4))
              (write-char #\space))
          (if (zero? (remainder i 8))
              (write-char #\space))
          (if (zero? (remainder i 32))
              (newline))
          (let ((byte (bytevector-ref bv i)))
            (write-char
	     (string-ref (number->string (quotient byte 16) 16) 0))
            (write-char
	     (string-ref (number->string (remainder byte 16) 16) 0))))))
  (if (and (pair? segment)
           (bytevector? (car segment))
           (vector? (cdr segment)))
      (begin (display-bytevector (car segment))
             (newline)
             (write (cdr segment))
             (newline)
             (do ((constants (vector->list (cdr segment))
                             (cdr constants)))
                 ((or (null? constants)
                      (null? (cdr constants))))
                 (if (and (bytevector? (car constants))
                          (vector? (cadr constants)))
                     (view-segment (cons (car constants)
                                         (cadr constants))))))))

; emit is a procedure that takes an as and emits instructions into it.

(define (test-asm emit)
  (let ((as (make-assembly-structure #f #f #f)))
    (emit as)
    (let ((segment 
           (assembly-postpass-segment
            as (assemble-pasteup as))))
      (assemble-finalize! as)
      (disassemble segment))))

(define (compile&assemble x)
  (view-segment (assemble (compile x))))

; FIXME: temporary hack
;
; The code for run-base-tests is being assembled twice, even
; though only one copy shows up in base.slfasl:
;
; > (time (compile-library "tests/r6rs/base.sls"))
; Compiling tests/r6rs/base.sls
; Autoloading (tests r6rs test)
; ANF size: 18787
; (assemble-finalize-report! 2 6140 3796 0 1430 0)
; ANF size: 18787
; (assemble-finalize-report! 2 6140 3796 0 1430 0)
; Words allocated: 1193358312
; Words reclaimed: 0
; Elapsed time...: 77693 ms (User: 68590 ms; System: 8949 ms)
; Elapsed GC time: 16343 ms (CPU: 16330 in 4550 collections.)
;
; (time-twobit 65536)
; (assemble-finalize-report! 1 2 65536 196612 0 3) ; SPARC     ( 98M, 6M)
; (assemble-finalize-report! 2 2 65536 0 0 0)      ; IAssassin (464M, 6M)

(define (assemble-finalize-report! as)
  (let ((report
         (list 'assemble-finalize-report!
               (cond ((list? (as-code as))             ; code segments
                      (length (as-code as)))
                     ((vector? (as-code as))
                      (vector-length (as-code as)))
                     (else #f))
               (length (as-constants as))              ; constants
               (length (as-labels as))                 ; labels
               (length (as-fixups as))                 ; fixups
               (length (as-nested as))                 ; nested
               (length (as-values as)))))              ; values
    (if (> (apply max (cdr report)) 4000)
        (begin (write report)
               (newline)))))

; eof
