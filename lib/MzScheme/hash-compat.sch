($$trace "hash-compat")

(define (make-hash-table . flags)
  (if (pair? flags)
      (cond ((eq? (car flags) 'weak)
             ;; discard the weak flag for now
             (apply make-hash-table (cdr flags)))
            ((eq? (car flags) 'equal)
             (make-hashtable equal-hash equal?))
            ;; Add these possibilities
            ((eq? (car flags) 'string=)
             (make-hashtable string-hash string=?))
            ((eq? (car flags) 'string-ci=)
             (make-hashtable string-hash-ci string-ci=?))
            ((eq? (car flags) 'symbol-eq?)
             (make-hashtable symbol-hash eq?))
            (else (make-eqv-hashtable)))
      (make-eqv-hashtable)))

(define hash-table-get
  (let ((entry-not-found (make-vector 1)))
    (vector-set! entry-not-found 0 entry-not-found)
    (lambda (h k . args)
      (let ((probe (hashtable-ref h k entry-not-found)))
        (cond ((not (eq? probe entry-not-found)) probe)
              ((pair? args) ((car args)))
              (else (error "hash-table-get: no entry for key: " k)))))))

(define (hash-table-put! h k v)
  (hashtable-set! h k v))

(define (hash-table-remove! h k)
  (hashtable-delete! h k))

(define (hash-table? v)
  (hashtable? v))

(define (hash-table-map h f)
  (hashtable-map f h))

(define (hash-table-for-each h f)
  (hashtable-for-each f h))

(define (hash-table-count h)
  (hashtable-size h))
