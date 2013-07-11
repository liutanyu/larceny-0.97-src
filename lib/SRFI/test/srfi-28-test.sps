; Test suite for SRFI-28
; 2004-01-01 / lth
;
; $Id: srfi-28-test.sps 5842 2008-12-11 23:04:51Z will $

(import (rnrs base)
        (rnrs io simple)
        (srfi :6 basic-string-ports)
        (srfi :28 basic-format-strings))

(define (writeln . xs)
  (for-each display xs)
  (newline))

(define (fail token . more)
  (writeln "Error: test failed: " token)
  #f)

(define testdatum '(fnord "foo" #\a))

(or (equal? "" (format ""))
    (fail 'format-empty:1))

(or (equal? (format "~a...~a" testdatum testdatum)
	    (let ((s (open-output-string)))
	      (display testdatum s)
	      (display "..." s)
	      (display testdatum s)
	      (get-output-string s)))
    (fail 'format-a:1))

(or (equal? (format "~s...~s" testdatum testdatum) 
	    (let ((s (open-output-string)))
	      (write testdatum s)
	      (display "..." s)
	      (write testdatum s)
	      (get-output-string s)))
    (fail 'format-s:1))

(or (equal? (format "~~~%") (string #\~ #\newline))
    (fail 'format-other:1))

(writeln "Done.")
