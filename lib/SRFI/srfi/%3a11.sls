; SRFI 11: LET-VALUES
;
; $Id: %3a11.sls 5842 2008-12-11 23:04:51Z will $
;
; See <http://srfi.schemers.org/srfi-11/srfi-11.html> for the full document.

(library (srfi :11 let-values)
  (export let-values let*-values)
  (import (rnrs base)))

(library (srfi :11)
  (export let-values let*-values)
  (import (srfi :11 let-values)))

; eof