;;; Test suite for SRFI 54.
;;;
;;; $Id: srfi-54-test.sch 6215 2009-05-06 00:19:51Z will $
;;;
;;; Extracted from
;;; http://srfi.schemers.org/srfi-54/post-mail-archive/msg00010.html

(cond-expand ((and srfi-9 srfi-54)))

(define (writeln . xs)
  (for-each display xs)
  (newline))

(define (fail token . more)
  (writeln "Error: test failed: " token)
  #f)

(or (equal? (cat 129.995 -10 2.)
            "130.00    ")
    (fail 'cat1))

(or (equal? (cat 129.995 10 2.)
            "    130.00")
    (fail 'cat2))

(or (equal? (cat 129 2.)
            "#e129.00")
    (fail 'cat3))

(or (equal? (cat 129 -2.)
            "129.00")
    (fail 'cat4))

(or (equal? (cat 129 10 #\* 'octal 'sign)
            "****#o+201")
    (fail 'cat5))

(or (equal? (cat 129 10 #\0 'octal 'sign)
            "#o+0000201")
    (fail 'cat6))

(or (equal? (cat 10.5 'octal)
            "#i#o25/2")
    (fail 'cat7))

(or (equal? (cat 10.5 'octal 'exact)
            "#o25/2")
    (fail 'cat8))

(or (equal? (cat 10.5 'octal (list string-upcase))
            "#I#O25/2")
    (fail 'cat9))

(or (equal? (cat 10.5 'octal (list string-upcase) '(-4))
            "25/2")
    (fail 'cat10))

(or (equal? (cat 123000000 'flonum)
            "1.23e+8")
    (fail 'cat11))

(or (equal? (cat 1.23456789e+25 'fixnum)
            "12345678900000000000000000.0")
    (fail 'cat12))

(or (equal? (cat 129.995 10 2. 'sign '("$"))
            "  $+130.00")
    (fail 'cat13))

(or (equal? (cat 129.995 10 2. 'sign '("$" -3))
            "     $+130")
    (fail 'cat14))

(or (equal? (cat 129.995 10 2. '("The number is " "."))
            "The number is 130.00.")
    (fail 'cat15))

(or (equal? (cat "abcdefg" '(3 . 1))
            "abcg")
    (fail 'cat16))

(or (equal? (cat "abcdefg" '(3 1))
            "c")
    (fail 'cat17))

(or (equal? (cat 123456789 'sign '(#\,))
            "+123,456,789")
    (fail 'cat18))

(or (equal? (cat "abcdefg" 'sign '(#\,))
            "abcdefg")
    (fail 'cat19))

(or (equal? (cat "abcdefg" 'sign '(#\: 2))
            "a:bc:de:fg")
    (fail 'cat20))

(or (equal? (cat "abcdefg" 'sign '(#\: -2))
            "ab:cd:ef:g")
    (fail 'cat21))

(or (equal? (cat '(#\a "str" s))
            "(a str s)")
    (fail 'cat22))

(or (equal? (cat '(#\a "str" s) '(-1 -1))
            "a str s")
    (fail 'cat23))

(or (equal? (cat '(#\a "str" s) write)
            "(#\\a \"str\" s)")
    (fail 'cat24))

(or (equal? (let ((p (open-output-string)))
              (cat 'String 10 p)
              (get-output-string p))
            "    String")
    (fail 'cat25))

(or (parameterize ((current-output-port (open-output-string)))
      (equal? (begin (cat 'String 10 #t)
                     (get-output-string (current-output-port)))
              "    String"))
    (fail 'cat26))

(define-record-type :example
  (make-example num str)
  example?
  (num get-num set-num!)
  (str get-str set-str!))

(define (record-writer object string-port)
  (if (example? object)
      (begin (display (get-num object) string-port)
      (display "-" string-port)
      (display (get-str object) string-port))
      (display object string-port)))

(define (record-display object string-port)
  (display (get-num object) string-port)
  (display "-" string-port)
  (display (get-str object) string-port))

(define ex (make-example 123 "string"))

(or (equal? (cat ex 20)
            (let ((p (open-output-string)))
              (write ex p)
              (let ((s (get-output-string p)))
                (string-append (make-string (- 20 (string-length s)) #\space)
                               s))))
    (fail 'cat27))

(or (equal? (cat ex 20 record-writer)
            "          123-string")
    (fail 'cat28))

(or (equal? (cat "str" 20 record-writer)
            "                 str")
    (fail 'cat29))

(or (equal? (parameterize ((current-output-port (open-output-string)))
              (let ((plus 12345678.901)
                    (minus -123456.789)
                    (ex (make-example 1234 "ex"))
                    (file "today.txt"))
                (for-each (lambda (x y)
                            (cat x 10 #t)
                            (cat y
                                 15
                                 (if (example? y)
                                     record-display
                                     display)
                                 2. '(#\,) #t)
                            (newline))
                          (list "plus: " "minus: " "net: " "ex: " "file: ")
                          (list plus minus (+ plus minus) ex file))
                (get-output-string (current-output-port))))
            (string-append
             "    plus:   12,345,678.90"
             "\n"
             "   minus:     -123,456.79"
             "\n"
             "     net:   12,222,222.11"
             "\n"
             "      ex:         1234-ex"
             "\n"
             "    file:       today.txt"
             "\n"))
    (fail 'cat30))

(writeln "Done.")
