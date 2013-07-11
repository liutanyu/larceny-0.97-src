; Copyright 1998, 2000 Lars T Hansen.
; 
; $Id: driver-larceny.sch 6152 2009-03-19 22:30:05Z will $
;
; 2000-09-26 / lth
;
; Compilation parameters and driver procedures -- for Larceny's standard
; heap (twobit exposed only through COMPILE-FILE and COMPILE-EXPRESSION).
; Uses basis functionality defined in driver-common.sch

; The code in this file is used only in Larceny heaps,
; so it can assume Larceny-specific extensions to Scheme.
; In particular, it can record source code locations for
; use by Twobit's pass 1.

; This definition overrides the stub in pass1.sch.
; It returns the value of the current-source-file parameter,
; after converting a string to a symbol to avoid duplication
; of filename strings in the heap.

(define (source-file-name)
  (let ((fn (current-source-file)))
    (if (string? fn)
        (let ((sym (string->symbol fn)))
          (current-source-file sym)
          sym)
        fn)))

; The source-location-recorder parameter hooks both load and
; compile-file to the macro expander's source-file-positions
; variable.

(define (twobit:source-location-recorder position-table)
  (set! source-file-positions position-table)
  (unspecified))

(source-location-recorder twobit:source-location-recorder)

; Compile and assemble a scheme source file and produce a FASL file.

(define (compile-file infilename . rest)

  (define (doit)
    (let ((outfilename
           (if (not (null? rest))
               (car rest)
               (rewrite-file-type infilename
                                  *scheme-file-types*
                                  *fasl-file-type*)))
          (user
           (assembly-user-data)))
      (if (eq? (integrate-procedures) 'none)
          (twobit-warn
           (string-append
            "integrate-procedures = none"
            (string #\newline)
            "Performance is likely to be poor.")))
      (let* ((syntaxenv
              (syntactic-copy
               (environment-syntax-environment
                (interaction-environment)))))
        (parameterize ((current-source-file infilename))
          (if (benchmark-block-mode)
              (process-file-block infilename
                                  `(,outfilename binary)
                                  (cons write-fasl-token
                                        (assembly-declarations user))
                                  read-source-code
                                  dump-fasl-segment-to-port
                                  (lambda (forms)
                                    (assemble (compile-block forms syntaxenv) 
                                              user)))
              (process-file infilename
                            `(,outfilename binary)
                            (cons write-fasl-token
                                  (assembly-declarations user))
                            read-source-code
                            dump-fasl-segment-to-port
                            (lambda (expr)
                              (assemble (compile expr syntaxenv) user))))))
      ((source-location-recorder) #f)
      (unspecified)))

  (if (eq? (nbuild-parameter 'target-machine) 'standard-c)
      (error "Compile-file not supported on this target architecture.")
      (doit)))


; Compile and assemble a single expression; return the LOP segment.

(define (compile-expression expr env)
  (assemble 
   (compile expr (environment-syntax-environment env))))


; Macro-expand a single expression; return the expanded form.

(define (macro-expand-expression expr env)
  (make-readable 
   (expand expr (environment-syntax-environment env))))

;;; The procedures compile313 assemble313 and compile-and-assemble313
;;; might not be appropriate for "real" Larceny systems, which is what
;;; this file is supposed to be "driving."  
;;;
;;; However, Common Larceny is currently built on top of compile313,
;;; and we want it to use the appropriate syntactic environment.  So
;;; in the short term, we'll define compile313 et al. in this driver
;;; file to be like the ones in the driver-twobit file, except that 
;;; these use the host's syntax environment.
;;;
;;; (This whole issue of "where to get the syntax environment from"
;;;  _should_ become irrelevant with R6RS libraries, Felix hopes.)

; Compile a scheme source file to a LAP file.

(define (compile313 infilename . rest)
  (let ((outfilename
         (if (not (null? rest))
             (car rest)
             (rewrite-file-type infilename
                                *scheme-file-types* 
                                *lap-file-type*)))
        (write-lap
         (lambda (item port)
           (write item port)
           (newline port)
           (newline port))))
    (let ((syntaxenv (syntactic-copy
                      (environment-syntax-environment
                       (interaction-environment)))))
      (if (benchmark-block-mode)
          (process-file-block infilename 
                              outfilename 
                              '()
                              read
                              write-lap 
                              (lambda (x)
                                (compile-block x syntaxenv)))
          (process-file infilename 
                        outfilename 
                        '()
                        read
                        write-lap 
                        (lambda (x) 
                          (compile x syntaxenv)))))
    (unspecified)))


; Assemble a LAP or MAL file to a LOP file.

(define (assemble313 file . rest)
  (let ((outputfile
         (if (not (null? rest))
             (car rest)
             (rewrite-file-type file 
                                (list *lap-file-type* *mal-file-type*)
                                *lop-file-type*)))
        (malfile?
         (file-type=? file *mal-file-type*))
        (user
         (assembly-user-data)))
    (process-file file
                  `(,outputfile binary)
                  (assembly-declarations user)
                  read
                  write-lop
                  (lambda (x) 
                    (assemble (if malfile? (eval x) x) user)))
    (unspecified)))


; Compile and assemble a Scheme source file to a LOP file.

(define (compile-and-assemble313 input-file . rest)
  (let ((output-file
         (if (not (null? rest))
             (car rest)
             (rewrite-file-type input-file 
                                *scheme-file-types*
                                *lop-file-type*)))
        (user
         (assembly-user-data)))
    (let ((syntaxenv (syntactic-copy
                      (environment-syntax-environment 
                       (interaction-environment)))))
      (if (benchmark-block-mode)
          (process-file-block input-file
                              `(,output-file binary)
                              (assembly-declarations user)
                              read
                              write-lop
                              (lambda (x)
                                (assemble (compile-block x syntaxenv) user)))
          (process-file input-file
                        `(,output-file binary)
                        (assembly-declarations user)
                        read
                        write-lop
                        (lambda (x) 
                          (assemble (compile x syntaxenv) user)))))
    (unspecified)))


; Convert a LOP file to a FASL file.

(define (make-fasl infilename . rest)
  (define (doit)
    (let ((outfilename
           (if (not (null? rest))
               (car rest)
               (rewrite-file-type infilename
                                  *lop-file-type*
                                  *fasl-file-type*))))
      (process-file `(,infilename binary)
                    `(,outfilename binary)
                    (list write-fasl-token)
                    read
                    dump-fasl-segment-to-port
                    (lambda (x) x))
      (unspecified)))

  (if (eq? (nbuild-parameter 'target-machine) 'standard-c)
      (error "Make-fasl not supported on this target architecture.")
      (doit)))


; eof
