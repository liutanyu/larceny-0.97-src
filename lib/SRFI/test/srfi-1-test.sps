; Test suite for SRFI-1
; 2003-12-29 / lth
;
; $Id: srfi-1-test.sps 5842 2008-12-11 23:04:51Z will $
;
; Note: In Larceny, we require that the procedures designated as
; "linear update" variants in the spec (eg append!) side-effect their
; arguments, and there are tests here that check that side-effecting
; occurs.
;
; For linear update we only require that the cells of the result are
; taken from the cells of the input.  We could be stricter and require
; that the cells of the results are the cells of the input with only
; the CDR changed, ie, values are never moved from one cell to another.

(import (except (rnrs base) map for-each)
        (rnrs io simple)
        (rnrs r5rs)
        (srfi :1 lists))

(define (writeln . xs)
  (for-each display xs)
  (newline))

(define (fail token . more)
  (writeln "Error: test failed: " token)
  #f)

; Test cases are ordered as in the spec.  R5RS procedures are left out.

(or (equal? (xcons 1 2) '(2 . 1))
    (fail 'xcons:1))

(or (equal? (cons* 1) 1)
    (fail 'cons*:1))
(or (equal? (cons* 1 2 3 4 5) '(1 2 3 4 . 5))
    (fail 'cons*:2))

(or (equal? (make-list 5 #t) '(#t #t #t #t #t))
    (fail 'make-list:1))
(or (equal? (make-list 0 #f) '())
    (fail 'make-list:2))
(or (equal? (length (make-list 3)) 3)
    (fail 'make-list:3))

(or (equal? (list-tabulate 5 (lambda (x) x)) '(0 1 2 3 4))
    (fail 'list-tabulate:1))
(or (equal? (list-tabulate 0 (lambda (x) (error "FOO!"))) '())
    (fail 'list-tabluate:2))

(or (call-with-current-continuation
     (lambda (abort)
       (let* ((c  (list 1 2 3 4 5))
	      (cp (list-copy c)))
	 (or (equal? c cp)
	     (abort #f))
	 (let loop ((c c) (cp cp))
	   (if (not (null? c))
	       (begin
		 (or (not (eq? c cp))
		     (abort #f))
		 (loop (cdr c) (cdr cp)))))
	 #t)))
    (fail 'list-copy:1))

(or (equal? (list-copy '(1 2 3 . 4)) '(1 2 3 . 4))
    (fail 'list-copy:2))

(or (not (list? (circular-list 1 2 3)))
    (fail 'circular-list:1))
(or (let* ((a (list 'a))
	   (b (list 'b))
	   (c (list 'c))
	   (x (circular-list a b c)))
      (and (eq? a (car x))
	   (eq? b (cadr x))
	   (eq? c (caddr x))
	   (eq? a (cadddr x))))
    (fail 'circular-list:2))

(or (equal? (iota 0) '())
    (fail 'iota:1))
(or (equal? (iota 5 2 3) '(2 5 8 11 14))
    (fail 'iota:2))
(or (equal? (iota 5 2) '(2 3 4 5 6))
    (fail 'iota:3))

(or (proper-list? '(1 2 3 4 5))
    (fail 'proper-list?:1))
(or (proper-list? '())
    (fail 'proper-list?:2))
(or (not (proper-list? '(1 2 . 3)))
    (fail 'proper-list?:3))
(or (not (proper-list? (circular-list 1 2 3)))
    (fail 'proper-list:4))

(or (not (circular-list? '(1 2 3 4 5)))
    (fail 'circular-list?:1))
(or (not (circular-list? '()))
    (fail 'circular-list?:2))
(or (not (circular-list? '(1 2 . 3)))
    (fail 'circular-list?:3))
(or (circular-list? (circular-list 1 2 3))
    (fail 'circular-list:4))

(or (not (dotted-list? '(1 2 3 4 5)))
    (fail 'dotted-list?:1))
(or (not (dotted-list? '()))
    (fail 'dotted-list?:2))
(or (dotted-list? '(1 2 . 3))
    (fail 'dotted-list?:3))
(or (not (dotted-list? (circular-list 1 2 3)))
    (fail 'dotted-list:4))

(or (null-list? '())
    (fail 'null-list?:1))
(or (not (null-list? '(1 2)))
    (fail 'null-list?:2))
(or (not (null-list? (circular-list 1 2)))
    (fail 'null-list?:3))

(or (not-pair? 1)
    (fail 'not-pair:1))
(or (not (not-pair? (cons 1 2)))
    (fail 'not-pair:2))

(or (list= = '(1 2 3) '(1 2 3) '(1 2 3))
    (fail 'list=:1))
(or (not (list= = '(1 2 3) '(1 2 3) '(1 4 3)))
    (fail 'list=:2))
; Checks that l0 is not being used when testing l2, cf spec
(or (list= (lambda (a b) (not (eq? a b))) '(#f #f #f) '(#t #t #t) '(#f #f #f))
    (fail 'list=:3))
(or (list= =)
    (fail 'list=:4))

(or (= (first '(1 2 3 4 5 6 7 8 9 10)) 1) (fail 'first))
(or (= (second '(1 2 3 4 5 6 7 8 9 10)) 2) (fail 'second))
(or (= (third '(1 2 3 4 5 6 7 8 9 10)) 3) (fail 'third))
(or (= (fourth '(1 2 3 4 5 6 7 8 9 10)) 4) (fail 'fourth))
(or (= (fifth '(1 2 3 4 5 6 7 8 9 10)) 5) (fail 'fifth))
(or (= (sixth '(1 2 3 4 5 6 7 8 9 10)) 6) (fail 'sixth))
(or (= (seventh '(1 2 3 4 5 6 7 8 9 10)) 7) (fail 'seventh))
(or (= (eighth '(1 2 3 4 5 6 7 8 9 10)) 8) (fail 'eighth))
(or (= (ninth '(1 2 3 4 5 6 7 8 9 10)) 9) (fail 'ninth))
(or (= (tenth '(1 2 3 4 5 6 7 8 9 10)) 10) (fail 'tenth))

(let-values (((a b) (car+cdr '(1 . 2))))
  (or (and (= a 1) (= b 2))
      (fail 'car+cdr:1)))

(or (equal? '(1 2 3) (take '(1 2 3 4 5 6) 3))
    (fail 'take:1))
(or (equal? '(1) (take '(1) 1))
    (fail 'take:2))

(or (let ((x (list 1 2 3 4 5 6)))
      (eq? (cdddr x) (drop x 3)))
    (fail 'drop:1))
(or (let ((x (list 1 2 3)))
      (eq? x (drop x 0)))
    (fail 'drop:2))

(or (equal? '(4 5 6) (take-right '(1 2 3 4 5 6) 3))
    (fail 'take-right:1))
(or (null? (take-right '(1 2 3 4 5 6) 0))
    (fail 'take-right:2))
(or (equal? '(2 3 . 4) (take-right '(1 2 3 . 4) 2))
    (fail 'take-right:3))
(or (equal? 4 (take-right '(1 2 3 . 4) 0))
    (fail 'take-right:4))

(or (equal? '(1 2 3) (drop-right '(1 2 3 4 5 6) 3))
    (fail 'drop-right:1))
(or (equal? '(1 2 3) (drop-right '(1 2 3) 0))
    (fail 'drop-right:2))
(or (equal? '(1 2 3) (drop-right '(1 2 3 . 4) 0))
    (fail 'drop-right:3))

(or (let ((x (list 1 2 3 4 5 6)))
      (let ((y (take! x 3)))
	(and (eq? x y)
	     (eq? (cdr x) (cdr y))
	     (eq? (cddr x) (cddr y))
	     (equal? y '(1 2 3)))))
    (fail 'take!:1))

(or (let ((x (list 1 2 3 4 5 6)))
      (let ((y (drop-right! x 3)))
	(and (eq? x y)
	     (eq? (cdr x) (cdr y))
	     (eq? (cddr x) (cddr y))
	     (equal? y '(1 2 3)))))
    (fail 'drop-right!:1))

(or (let-values (((a b) (split-at '(1 2 3 4 5 6) 2)))
      (and (equal? a '(1 2))
	   (equal? b '(3 4 5 6))))
    (fail 'split-at:1))

(or (let* ((x (list 1 2 3 4 5 6))
	   (y (cddr x)))
      (let-values (((a b) (split-at! x 2)))
        (and (equal? a '(1 2))
	     (eq? a x)
	     (equal? b '(3 4 5 6))
	     (eq? b y))))
    (fail 'split-at!:1))

(or (eq? 37 (last '(1 2 3 37)))
    (fail 'last:1))

(or (not (length+ (circular-list 1 2 3)))
    (fail 'length+:1))
(or (equal? 4 (length+ '(1 2 3 4)))
    (fail 'length+:2))

(or (let ((x (list 1 2))
	  (y (list 3 4))
	  (z (list 5 6)))
      (let ((r (append! x y '() z)))
	(and (equal? r '(1 2 3 4 5 6))
	     (eq? r x)
	     (eq? (cdr r) (cdr x))
	     (eq? (cddr r) y)
	     (eq? (cdddr r) (cdr y))
	     (eq? (cddddr r) z)
	     (eq? (cdr (cddddr r)) (cdr z)))))
    (fail 'append!:1))

(or (equal? (concatenate '((1 2 3) (4 5 6) () (7 8 9))) '(1 2 3 4 5 6 7 8 9))
    (fail 'concatenate:1))

(or (equal? (concatenate! `(,(list 1 2 3) ,(list 4 5 6) () ,(list 7 8 9)))
	    '(1 2 3 4 5 6 7 8 9))
    (fail 'concatenate!:1))

(or (equal? (append-reverse '(3 2 1) '(4 5 6)) '(1 2 3 4 5 6))
    (fail 'append-reverse:1))

(or (equal? (append-reverse! (list 3 2 1) (list 4 5 6)) '(1 2 3 4 5 6))
    (fail 'append-reverse!:1))

(or (equal? (zip '(1 2 3) '(4 5 6)) '((1 4) (2 5) (3 6)))
    (fail 'zip:1))
(or (equal? (zip '() '() '() '()) '())
    (fail 'zip:2))
(or (equal? (zip '(1) (circular-list 1 2)) '((1 1)))
    (fail 'zip:3))

(or (equal? '(1 2 3 4 5) (unzip1 '((1) (2) (3) (4) (5))))
    (fail 'unzip1:1))

(or (let-values (((a b) (unzip2 '((10 11) (20 21) (30 31)))))
      (and (equal? a '(10 20 30))
	   (equal? b '(11 21 31))))
    (fail 'unzip2:1))

(or (let-values (((a b c) (unzip3 '((10 11 12) (20 21 22) (30 31 32)))))
      (and (equal? a '(10 20 30))
	   (equal? b '(11 21 31))
	   (equal? c '(12 22 32))))
    (fail 'unzip3:1))

(or (let-values (((a b c d) (unzip4 '((10 11 12 13)
				      (20 21 22 23)
				      (30 31 32 33)))))
      (and (equal? a '(10 20 30))
	   (equal? b '(11 21 31))
	   (equal? c '(12 22 32))
	   (equal? d '(13 23 33))))
    (fail 'unzip4:1))

(or (let-values (((a b c d e) (unzip5 '((10 11 12 13 14)
					(20 21 22 23 24)
					(30 31 32 33 34)))))
      (and (equal? a '(10 20 30))
	   (equal? b '(11 21 31))
	   (equal? c '(12 22 32))
	   (equal? d '(13 23 33))
	   (equal? e '(14 24 34))))
    (fail 'unzip5:1))

(or (equal? 3 (count even? '(3 1 4 1 5 9 2 5 6)))
    (fail 'count:1))
(or (equal? 3 (count < '(1 2 4 8) '(2 4 6 8 10 12 14 16)))
    (fail 'count:2))
(or (equal? 2 (count < '(3 1 4 1) (circular-list 1 10)))
    (fail 'count:3))

(or (equal? '(c 3 b 2 a 1) (fold cons* '() '(a b c) '(1 2 3 4 5)))
    (fail 'fold:1))

(or (equal? '(a 1 b 2 c 3) (fold-right cons* '() '(a b c) '(1 2 3 4 5)))
    (fail 'fold-right:1))

(or (let* ((x (list 1 2 3))
	   (r (list x (cdr x) (cddr x)))
	   (y (pair-fold (lambda (pair tail) 
			   (set-cdr! pair tail) pair) 
			 '()
			 x)))
      (and (equal? y '(3 2 1))
	   (every (lambda (c) (memq c r)) (list y (cdr y) (cddr y)))))
    (fail 'pair-fold:1))

(or (equal? '((a b c) (b c) (c)) (pair-fold-right cons '() '(a b c)))
    (fail 'pair-fold-right:1))

(or (equal? 5 (reduce max 'illegal '(1 2 3 4 5)))
    (fail 'reduce:1))
(or (equal? 0 (reduce max 0 '()))
    (fail 'reduce:2))

(or (equal? '(1 2 3 4 5) (reduce-right append 'illegal '((1 2) () (3 4 5))))
    (fail 'reduce-right:1))

(or (equal? '(1 4 9 16 25 36 49 64 81 100)
	    (unfold (lambda (x) (> x 10))
		    (lambda (x) (* x x))
		    (lambda (x) (+ x 1))
		    1))
    (fail 'unfold:1))

(or (equal? '(1 4 9 16 25 36 49 64 81 100)
	    (unfold-right zero? 
			  (lambda (x) (* x x))
			  (lambda (x) (- x 1))
			  10))
    (fail 'unfold-right:1))

(or (equal? '(4 1 5 1)
	    (map + '(3 1 4 1) (circular-list 1 0)))
    (fail 'map:1))

(or (equal? '(5 4 3 2 1)
	    (let ((v 1)
		  (l '()))
	      (for-each (lambda (x y)
			  (let ((n v))
			    (set! v (+ v 1))
			    (set! l (cons n l))))
			'(0 0 0 0 0)
			(circular-list 1 2))
	      l))
    (fail 'for-each:1))

(or (equal? '(1 -1 3 -3 8 -8) 
	    (append-map (lambda (x) (list x (- x))) '(1 3 8)))
    (fail 'append-map:1))

(or (equal? '(1 -1 3 -3 8 -8) 
	    (append-map! (lambda (x) (list x (- x))) '(1 3 8)))
    (fail 'append-map!:1))

(or (let* ((l (list 1 2 3))
	   (m (map! (lambda (x) (* x x)) l)))
      (and (equal? m '(1 4 9))
	   (equal? l '(1 4 9))))
    (fail 'map!:1))

(or (equal? '(1 2 3 4 5)
	    (let ((v 1))
	      (map-in-order (lambda (x)
			      (let ((n v))
				(set! v (+ v 1))
				n))
			    '(0 0 0 0 0))))
    (fail 'map-in-order:1))

(or (equal? '((3) (2 3) (1 2 3))
	    (let ((xs (list 1 2 3))
		  (l '()))
	      (pair-for-each (lambda (x) (set! l (cons x l))) xs)
	      l))
    (fail 'pair-for-each:1))

(or (equal? '(1 9 49)
	    (filter-map (lambda (x y) (and (number? x) (* x x))) 
			'(a 1 b 3 c 7)
			(circular-list 1 2)))
    (fail 'filter-map:1))

(or (equal? '(0 8 8 -4) (filter even? '(0 7 8 8 43 -4)))
    (fail 'filter:1))

(or (let-values (((a b) (partition symbol? '(one 2 3 four five 6))))
      (and (equal? a '(one four five))
	   (equal? b '(2 3 6))))
    (fail 'partition:1))

(or (equal? '(7 43) (remove even? '(0 7 8 8 43 -4)))
    (fail 'remove:1))

(or (let* ((x (list 0 7 8 8 43 -4))
	   (y (pair-fold cons '() x))
	   (r (filter! even? x)))
      (and (equal? '(0 8 8 -4) r)
	   (every (lambda (c) (memq c y)) (pair-fold cons '() r))))
    (fail 'filter!:1))

(or (let* ((x (list 'one 2 3 'four 'five 6))
	   (y (pair-fold cons '() x)))
      (let-values (((a b) (partition! symbol? x)))
	(and (equal? a '(one four five))
	     (equal? b '(2 3 6))
	     (every (lambda (c) (memq c y)) (pair-fold cons '() a))
	     (every (lambda (c) (memq c y)) (pair-fold cons '() b)))))
    (fail 'partition!:1))

(or (let* ((x (list 0 7 8 8 43 -4))
	   (y (pair-fold cons '() x))
	   (r (remove! even? x)))
      (and (equal? '(7 43) r)
	   (every (lambda (c) (memq c y)) (pair-fold cons '() r))))
    (fail 'remove!:1))

(or (equal? 4 (find even? '(3 1 4 1 5 9 8)))
    (fail 'find:1))

(or (equal? '(4 1 5 9 8) (find-tail even? '(3 1 4 1 5 9 8)))
    (fail 'find-tail:1))
(or (equal? '#f (find-tail even? '(1 3 5 7)))
    (fail 'find-tail:2))

(or (equal? '(2 18) (take-while even? '(2 18 3 10 22 9)))
    (fail 'take-while:1))

(or (let* ((x (list 2 18 3 10 22 9))
	   (r (take-while! even? x)))
      (and (equal? r '(2 18))
	   (eq? r x)
	   (eq? (cdr r) (cdr x))))
    (fail 'take-while!:1))

(or (equal? '(3 10 22 9) (drop-while even? '(2 18 3 10 22 9)))
    (fail 'drop-while:1))

(or (let-values (((a b) (span even? '(2 18 3 10 22 9))))
      (and (equal? a '(2 18))
	   (equal? b '(3 10 22 9))))
    (fail 'span:1))

(or (let-values (((a b) (break even? '(3 1 4 1 5 9))))
      (and (equal? a '(3 1))
	   (equal? b '(4 1 5 9))))
    (fail 'break:1))

(or (let* ((x     (list 2 18 3 10 22 9))
	   (cells (pair-fold cons '() x)))
      (let-values (((a b) (span! even? x)))
        (and (equal? a '(2 18))
	     (equal? b '(3 10 22 9))
	     (every (lambda (x) (memq x cells)) (pair-fold cons '() a))
	     (every (lambda (x) (memq x cells)) (pair-fold cons '() b)))))
    (fail 'span!:1))

(or (let* ((x     (list 3 1 4 1 5 9))
	   (cells (pair-fold cons '() x)))
      (let-values (((a b) (break! even? x)))
        (and (equal? a '(3 1))
	     (equal? b '(4 1 5 9))
	     (every (lambda (x) (memq x cells)) (pair-fold cons '() a))
	     (every (lambda (x) (memq x cells)) (pair-fold cons '() b)))))
    (fail 'break!:1))

(or (any integer? '(a 3 b 2.7))
    (fail 'any:1))
(or (not (any integer? '(a 3.1 b 2.7)))
    (fail 'any:2))
(or (any < '(3 1 4 1 5) (circular-list 2 7 1 8 2))
    (fail 'any:3))
(or (equal? 'yes (any (lambda (a b) (if (< a b) 'yes #f))
		      '(1 2 3) '(0 1 4)))
    (fail 'any:4))

(or (every integer? '(1 2 3))
    (fail 'every:1))
(or (not (every integer? '(3 4 5.1)))
    (fail 'every:2))
(or (every < '(1 2 3) (circular-list 2 3 4))
    (fail 'every:3))

(or (equal? 2 (list-index even? '(3 1 4 1 5 9)))
    (fail 'list-index:1))
(or (equal? 1 (list-index < '(3 1 4 1 5 9 2 5 6) '(2 7 1 8 2)))
    (fail 'list-index:2))
(or (not (list-index = '(3 1 4 1 5 9 2 5 6) '(2 7 1 8 2)))
    (fail 'list-index:3))

(or (equal? '(37 48) (member 5 '(1 2 5 37 48) <))
    (fail 'member:1))

(or (equal? '(1 2 5) (delete 5 '(1 48 2 5 37) <))
    (fail 'delete:1))
(or (equal? '(1 2 7) (delete 5 '(1 5 2 5 7)))
    (fail 'delete:2))

(or (let* ((x     (list 1 48 2 5 37))
	   (cells (pair-fold cons '() x))
	   (r     (delete! 5 x <)))
      (and (equal? r '(1 2 5))
	   (every (lambda (x) (memq x cells)) (pair-fold cons '() r))))
    (fail 'delete!:1))

(or (equal? '((a . 3) (b . 7) (c . 1))
	    (delete-duplicates '((a . 3) (b . 7) (a . 9) (c . 1))
			       (lambda (x y) (eq? (car x) (car y)))))
    (fail 'delete-duplicates:1))
(or (equal? '(a b c z) (delete-duplicates '(a b a c a b c z) eq?))
    (fail 'delete-duplicates:2))

(or (let* ((x     (list 'a 'b 'a 'c 'a 'b 'c 'z))
	   (cells (pair-fold cons '() x))
	   (r     (delete-duplicates! x)))
      (and (equal? '(a b c z) r)
	   (every (lambda (x) (memq x cells)) (pair-fold cons '() r))))
    (fail 'delete-duplicates!:1))

(or (equal? '(3 . #t) (assoc 6 
			     '((4 . #t) (3 . #t) (5 . #t))
			     (lambda (x y)
			       (zero? (remainder x y)))))
    (fail 'assoc:1))

(or (equal? '((1 . #t) (2 . #f)) (alist-cons 1 #t '((2 . #f))))
    (fail 'alist-cons:1))

(or (let* ((a (list (cons 1 2) (cons 3 4)))
	   (b (alist-copy a)))
      (and (equal? a b)
	   (every (lambda (x) (not (memq x b))) a)
	   (every (lambda (x) (not (memq x a))) b)))
    (fail 'alist-copy:1))

(or (equal? '((1 . #t) (2 . #t) (4 . #t))
	    (alist-delete 5 '((1 . #t) (2 . #t) (37 . #t) (4 . #t) (48 #t)) <))
    (fail 'alist-delete:1))
(or (equal? '((1 . #t) (2 . #t) (4 . #t))
	    (alist-delete 7 '((1 . #t) (2 . #t) (7 . #t) (4 . #t) (7 #t))))
    (fail 'alist-delete:2))

(or (let* ((x '((1 . #t) (2 . #t) (7 . #t) (4 . #t) (7 #t)))
	   (y (list-copy x))
	   (cells (pair-fold cons '() x))
	   (r (alist-delete! 7 x)))
      (and (equal? r '((1 . #t) (2 . #t) (4 . #t)))
	   (every (lambda (x) (memq x cells)) (pair-fold cons '() r))
	   (every (lambda (x) (memq x y)) r)))
    (fail 'alist-delete!:1))

(or (lset<= eq? '(a) '(a b a) '(a b c c))
    (fail 'lset<=:1))
(or (not (lset<= eq? '(a) '(a b a) '(a)))
    (fail 'lset<=:2))
(or (lset<= eq?)
    (fail 'lset<=:3))
(or (lset<= eq? '(a))
    (fail 'lset<=:4))

(or (lset= eq? '(b e a) '(a e b) '(e e b a))
    (fail 'lset=:1))
(or (not (lset= eq? '(b e a) '(a e b) '(e e b a c)))
    (fail 'lset=:2))
(or (lset= eq?)
    (fail 'lset=:3))
(or (lset= eq? '(a))
    (fail 'lset=:4))

(or (equal? '(u o i a b c d c e) 
	    (lset-adjoin eq? '(a b c d c e) 'a 'e 'i 'o 'u))
    (fail 'lset-adjoin:1))

(or (equal? '(u o i a b c d e)
	    (lset-union eq? '(a b c d e) '(a e i o u)))
    (fail 'lset-union:1))
(or (equal? '(x a a c) (lset-union eq? '(a a c) '(x a x)))
    (fail 'lset-union:2))
(or (null? (lset-union eq?))
    (fail 'lset-union:3))
(or (equal? '(a b c) (lset-union eq? '(a b c)))
    (fail 'lset-union:4))

(or (equal? '(a e) (lset-intersection eq? '(a b c d e) '(a e i o u)))
    (fail 'lset-intersection:1))
(or (equal? '(a x a) (lset-intersection eq? '(a x y a) '(x a x z)))
    (fail 'lset-intersection:2))
(or (equal? '(a b c) (lset-intersection eq? '(a b c)))
    (fail 'lset-intersection:3))

(or (equal? '(b c d) (lset-difference eq? '(a b c d e) '(a e i o u)))
    (fail 'lset-difference:1))
(or (equal? '(a b c) (lset-difference eq? '(a b c)))
    (fail 'lset-difference:2))

(or (lset= eq? '(d c b i o u) (lset-xor eq? '(a b c d e) '(a e i o u)))
    (fail 'lset-xor:1))
(or (lset= eq? '() (lset-xor eq?))
    (fail 'lset-xor:2))
(or (lset= eq? '(a b c d e) (lset-xor eq? '(a b c d e)))
    (fail 'lset-xor:3))

(or (let-values (((d i) (lset-diff+intersection eq? '(a b c d e) '(c d f))))
      (and (equal? d '(a b e))
	   (equal? i '(c d))))
    (fail 'lset-diff+intersection:1))

; FIXME: For the following five procedures, need to check that cells
; returned are from the arguments.

(or (equal? '(u o i a b c d e)
	    (lset-union! eq? (list 'a 'b 'c 'd 'e) (list 'a 'e 'i 'o 'u)))
    (fail 'lset-union!:1))
(or (equal? '(x a a c) (lset-union! eq? (list 'a 'a 'c) (list 'x 'a 'x)))
    (fail 'lset-union!:2))
(or (null? (lset-union! eq?))
    (fail 'lset-union!:3))
(or (equal? '(a b c) (lset-union! eq? (list 'a 'b 'c)))
    (fail 'lset-union!:4))

(or (equal? '(a e) (lset-intersection! eq? (list 'a 'b 'c 'd 'e) 
				       (list 'a 'e 'i 'o 'u)))
    (fail 'lset-intersection!:1))
(or (equal? '(a x a) (lset-intersection! eq? (list 'a 'x 'y 'a) 
					 (list 'x 'a 'x 'z)))
    (fail 'lset-intersection!:2))
(or (equal? '(a b c) (lset-intersection! eq? (list 'a 'b 'c)))
    (fail 'lset-intersection!:3))

(or (equal? '(b c d) (lset-difference! eq? (list 'a 'b 'c 'd 'e)
				       (list 'a 'e 'i 'o 'u)))
    (fail 'lset-difference!:1))
(or (equal? '(a b c) (lset-difference! eq? (list 'a 'b 'c)))
    (fail 'lset-difference!:2))

(or (lset= eq? '(d c b i o u) (lset-xor! eq? (list 'a 'b 'c 'd 'e)
					 (list 'a 'e 'i 'o 'u)))
    (fail 'lset-xor!:1))
(or (lset= eq? '() (lset-xor! eq?))
    (fail 'lset-xor!:2))
(or (lset= eq? '(a b c d e) (lset-xor! eq? (list 'a 'b 'c 'd 'e)))
    (fail 'lset-xor!:3))

(or (let-values (((d i) (lset-diff+intersection! eq? (list 'a 'b 'c 'd 'e)
						 (list 'c 'd 'f))))
      (and (equal? d '(a b e))
	   (equal? i '(c d))))
    (fail 'lset-diff+intersection!:1))

(writeln "Done.")
