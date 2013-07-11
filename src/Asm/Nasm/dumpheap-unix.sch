; 30 August 2003
;
; Routines for dumping a Petit Larceny heap image using NASM for x86
; Unix-like systems (Unix, Linux).

; Hook for a list of libraries for your platform.  This is normally
; set by code in the nasm-*.sch file, after this file is loaded.

(define unix/petit-lib-library-platform '())

; Hooks for library names.  These are normally set by code in the 
; nasm-*.sch file, after this file is loaded.

(define unix/petit-rts-library (param-filename 'rts "libpetit.a"))
(define unix/petit-lib-library "libheap.a")

; Hook called from dumpheap-extra.sch to create the heap library file

(define (build-petit-larceny heap output-file-name input-file-names)
  (c-link-library unix/petit-lib-library
		  (remove-duplicates
		   (append (map (lambda (x)
				  (rewrite-file-type x ".lop" ".o"))
				input-file-names)
			   (list (rewrite-file-type *temp-file* ".asm" ".o")))
		   string=?)
		  '()))

; General interface for creating an executable containing the standard
; libraries and some additional files.

(define (build-application executable-name lop-files)
  (let ((src-name (rewrite-file-type executable-name '("") ".asm"))
        (obj-name (rewrite-file-type executable-name '("") ".o")))
    (init-variables)
    (for-each create-loadable-file lop-files)
    (dump-loadable-thunks src-name)
    (c-compile-file src-name obj-name)
    (c-link-executable executable-name
                       (cons obj-name
                             (map (lambda (x)
                                    (rewrite-file-type x ".lop" ".o"))
                                  lop-files))
                       `(,unix/petit-rts-library
                         ,unix/petit-lib-library
                         ,@unix/petit-lib-library-platform))
    executable-name))

; Compiler definitions

(define (assembler:nasm-unix asm-name o-name)
  (execute
   (twobit-format 
    #f
    "nasm -O1 -f elf -I~a -I~a -I~a -o ~a ~a"
    (nbuild-parameter 'include)
    (nbuild-parameter 'common-include)
    (nbuild-parameter 'nasm-include)
    o-name
    asm-name)))

(define (c-library-linker:gcc-unix output-name object-files libs)
  (execute 
   (twobit-format 
    #f
    "ar -r ~a ~a; ranlib ~a"
    output-name
    (apply string-append (insert-space object-files))
    output-name)))

(define (c-linker:gcc-linux output-name object-files libs)
  (execute
   (twobit-format 
    #f
    "gcc ~a -rdynamic -o ~a ~a ~a"
    (if (optimize-c-code) "" "-gstabs+")
    output-name
    (apply string-append (insert-space object-files))
    (apply string-append (insert-space libs)))))

(define (c-linker:gcc-unix output-name object-files libs)
  (execute
   (twobit-format 
    #f
    "gcc ~a -o ~a ~a ~a"
    (if (optimize-c-code) "" "-gstabs+")
    output-name
    (apply string-append (insert-space object-files))
    (apply string-append (insert-space libs)))))

(define (c-so-linker:gcc-unix output-name object-files libs)
  (error "Don't know how to build a shared object under generic unix"))

(define (c-so-linker:gcc-linux output-name object-files libs)
  (execute
   (twobit-format 
    #f
    "gcc ~a -shared -o ~a ~a ~a"
    (if (optimize-c-code) "" "-gstabs+")
    output-name
    (apply string-append (insert-space object-files))
    (apply string-append (insert-space libs)))))

(define-compiler 
  "NASM+GCC under Unix"
  'nasm+gcc
  ".o"
  (let ((host-os (nbuild-parameter 'host-os)))
    (if (eq? host-os 'unix)
	(if (zero? (system "test \"`uname`\" = \"Linux\""))
	    (set! host-os 'linux)))
    `((compile            . ,assembler:nasm-unix)
      (link-library       . ,c-library-linker:gcc-unix)
      (link-executable    . ,(case host-os
			       ((linux linux-el) c-linker:gcc-linux)
			       (else    c-linker:gcc-unix)))
      (link-shared-object . ,(case host-os
			       ((linux linux-el)  c-so-linker:gcc-linux)
			       (else     c-so-linker:gcc-unix)))
      (append-files       . ,append-file-shell-command-unix)
      (make-configuration . x86-unix-static-gcc-nasm))))

; eof

