; SRFI 16: CASE-LAMBDA
;
; $Id: %3a16.sls 5842 2008-12-11 23:04:51Z will $
;
; See <http://srfi.schemers.org/srfi-16/srfi-16.html> for the full document.

(library (srfi :16 case-lambda)
  (export case-lambda)
  (import (only (rnrs control) case-lambda)))

(library (srfi :16)
  (export case-lambda)
  (import (srfi :16 case-lambda)))

; eof