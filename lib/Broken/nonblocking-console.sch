; Copyright 1999 Lars T Hansen
;
; $Id: nonblocking-console.sch 4833 2007-09-10 12:03:46Z pnkfelix $

(require 'experimental/iosys)
(require 'experimental/unix)
(require 'experimental/unix-descriptor)

(define nonblocking-console-input-port)  ; Just like CONSOLE-INPUT-PORT
(define nonblocking-console-output-port) ; Just like CONSOLE-OUTPUT-PORT

(let ()
  (define *current-conin* #f)
  (define *current-conout* #f)

  (set! nonblocking-console-input-port
        (lambda ()

          (define (reset-port)
            (let ((fd (unix/open "/dev/tty" unix/O_RDONLY)))
              (if (< fd 0)
                  (begin (error "Failed to open /dev/tty for console.")
			 (exit)))
              (set! *current-conin*
                    (open-input-descriptor fd 'nonblocking 'char))))

          (cond ((not *current-conin*)
                 (reset-port))
                ((or (port-error-flag *current-conin*)
                     (port-eof-flag *current-conin*))
                 ; FIXME: reap the descriptor
                 (reset-port)))
          *current-conin*))

  (set! nonblocking-console-output-port
        (lambda ()

          (define (reset-port)
            (let ((fd (unix/open "/dev/tty" unix/O_WRONLY)))
              (if (< fd 0)
		  (begin (error "Failed to open /dev/tty for console.")
			 (exit)))
              (set! *current-conout*
                    (open-output-descriptor fd 'nonblocking 'char 'flush))))

          (cond ((not *current-conout*)
                 (reset-port))
                ((port-error-flag *current-conout*)
                 ; FIXME: reap the descriptor
                 (reset-port)))
          *current-conout*))

  'nonblocking-console)

; eof
