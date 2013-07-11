; SRFI 16: ERROR
;
; $Id: %3a23.sls 5842 2008-12-11 23:04:51Z will $
;
; Conflicts with (rnrs base): error
;
; See <http://srfi.schemers.org/srfi-23/srfi-23.html> for the full document.

; ERROR is built into Larceny

(library (srfi :23 error)
  (export error)
  (import (rename (rnrs base) (error r6rs:error)))

  (define (error reason . irritants)
    (apply r6rs:error #f reason irritants)))

(library (srfi :23)
  (export error)
  (import (srfi :23 error)))

; eof