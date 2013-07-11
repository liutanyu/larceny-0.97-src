; SRFI 9
; Records
;
; $Id: %3a9.sls 5842 2008-12-11 23:04:51Z will $
;
; This implementation uses the ERR5RS-proposed record package to do the
; dirty work.
;
; FIXME: That adds some extensions.

(library (srfi :9 records)
  (export define-record-type)
  (import (err5rs records syntactic)))

(library (srfi :9)
  (export define-record-type)
  (import (srfi :9 records)))

; eof
