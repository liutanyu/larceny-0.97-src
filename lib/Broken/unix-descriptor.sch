; Copyright 1999 Lars T Hansen
; 
; $Id: unix-descriptor.sch 4833 2007-09-10 12:03:46Z pnkfelix $
;
; Code that creates blocking and nonblocking ports on Unix file descriptors.
; Use OPEN-INPUT-DESCRIPTOR and OPEN-OUTPUT-DESCRIPTOR to wrap an already
; open descriptor in an input or output port, respectively.
;
; Nonblocking I/O requires use of the tasking system and the tasking system
; extensions that implement the scheduler compatible with nonblocking I/O.

(require 'define-record)
(require "Experimental/unix")
(require "Experimental/poll")
(require "Experimental/iosys")

; Flags are:
;   nonblocking -- use nonblocking input
;   char        -- char port (default)
;   byte        -- byte port
; Currently char and byte ports are indistinguishable.

(define (open-input-descriptor fd . flags)
  (let ((nonblocking? (memq 'nonblocking flags))
        (type (cond ((memq 'byte flags) 'byte)
                    ((memq 'char flags) 'char)
                    (else 'char))))
    (make-input-port
     (lambda (selector)
       (case selector
         ((read)   descio/read)
         ((close)  descio/close)
         ((ready?) descio/ready-input?)
         ((name)   descio/name)
         (else ???)))
     (make-descio fd nonblocking?)
     type)))

; Flags are:
;   nonblocking -- use nonblocking output
;   flush       -- use discretionary flushing
;   char        -- char port (default)
;   byte        -- byte port
; Currently char and byte ports are indistinguishable.

(define (open-output-descriptor fd . flags)
  (let ((nonblocking? (memq 'nonblocking flags))
        (flush? (memq 'flush flags))
        (type (cond ((memq 'byte flags) 'byte)
                    ((memq 'char flags) 'char)
                    (else 'char))))
    (make-output-port
     (lambda (selector)
       (case selector
         ((write)  descio/write)
         ((close)  descio/close)
         ((name)   descio/name)
         (else ???)))
     (make-descio fd nonblocking?)
     type
     flush?)))

; Implementation

(define-record descio (fd nonblocking?))

(define (descio/read data buf)
  (if (and (descio-nonblocking? data)
           (not (descio/ready-input? data)))
      (input-not-ready-handler (descio-fd data)))
  (let ((result (unix/read (descio-fd data) buf (bytevector-like-length buf))))
    (cond ((< result 0) 'error)
          ((= result 0) 'eof)
          (else result))))

(define (descio/write data buf count)

  ; FIXME: this is not efficient.

  (define (subbytevector bv start-incl end-excl)
    (let ((ret (make-bytevector (- end-excl start-incl))))
      (do ((i start-incl (+ i 1))
           (j 0 (+ j 1)))
          ((= i end-excl) ret)
        (bytevector-like-set! ret j (bytevector-like-ref bv i)))))

  (define (write-some idx count)
    (unix/write (descio-fd data) (subbytevector buf idx (+ idx count)) count))

  (define (loop idx count)
    (cond ((zero? count) 'ok)
          ((or (descio/ready-output? data)
               (not (descio-nonblocking? data)))
           (let ((written (write-some idx count)))
             (if (< written 0)
                 'error
                 (loop (+ idx written) (- count written)))))
          (else
           (output-not-ready-handler (descio-fd data))
           (loop idx count))))

  (loop 0 count))

(define (descio/ready-input? data)
  (let ((ready (poll-descriptors (list (descio-fd data)) '() #f)))
    (not (null? ready))))

(define (descio/ready-output? data)
  (let ((ready (poll-descriptors '() (list (descio-fd data)) #f)))
    (not (null? ready))))

(define (descio/close data)
  (let ((res (unix/close (descio-fd data))))
    (if (< res 0)
        'error
        'ok)))

(define (descio/name data)
  (string-append "*descriptor " 
                 (number->string (descio-fd data))
                 "*"))

; eof
