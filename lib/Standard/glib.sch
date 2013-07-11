(require 'std-ffi)
(require 'foreign-sugar)
(require 'foreign-stdlib)

(let ((os (assq 'os-name (system-features))))
  (cond 
   ((equal? os '(os-name . "Linux"))
    (foreign-file "/usr/lib/libgtk-x11-2.0.so.0"))    
   ((equal? os '(os-name . "SunOS"))
    (foreign-file "/usr/lib/libgobject-2.0.so")
    (foreign-file "/usr/lib/libglib-2.0.so"))
   ((equal? os '(os-name . "MacOS X"))
    (foreign-file "/sw/lib/libgtk-x11-2.0.dylib"))
   (else
    (error "Add case in glib.sch for os: " os))))

;; UGH.  The number of arguments for the gcallback (the 3rd param to
;; g-signal-connect-data) is dependant on which signal is being
;; connected.  So we need to first do a query on the signal to find
;; out how many parameters it expects, and what their types are.  But
;; to do a query, you need to pass in a signal_id, which you get via
;; g_signal_parse_name... but you need a type for that...



(define (gobject->gtype obj)
  (let* ((clas (void*-void*-ref obj 0)))
    (void*-word-ref clas 0)))

(define-foreign (g-signal-parse-name string int boxed boxed bool) bool)
(define-foreign (g-signal-query int boxed) void)
(define-foreign (g-type-init) void)
(define-foreign (g-type-name int) string)
(define-foreign (g-type-parent int) int)

;; Note that this only produces a useful result if the type has been
;; registered, which seems like it may be delayed until the first
;; construction of an instance of the type.  So it cannot be used to
;; inspect the object hierarchy at library load time, unless one 
;; forces the relevant g-types to all be registered beforehand.
(define-foreign (g-type-from-name string) int)

(define (gsignal+object->params signal-name gobject)
  (define (type->symbol x)
    (string->symbol (string-downcase (g-type-name x))))
  (let ((type (gobject->gtype gobject))
        (x (list->bytevector '(-1 -1 -1 -1)))
        (y (list->bytevector '(-1 -1 -1 -1))))
    (cond 
     ((g-signal-parse-name signal-name type x y #f))
     (else
      (error 'gsignal+object->params " unknown signal " signal-name " for " gobject)))
    (let ((id (%get32 x 0))
          (z (list->bytevector (vector->list (make-vector 28 -1)))))
      (g-signal-query id z)
      '(begin (display z)
              (newline))
      (let ((return-type     (%get32 z 16))
            (n-params        (%get32 z 20))
            (param-types-ptr (%get32 z 24)))
        (do ((i 0 (+ i 1))
             (addr param-types-ptr (+ addr 4))
             (l '(gpointer) (cons (type->symbol (%peek-int addr)) l)))
            ((= i n-params) `(-> ,(cons 'gpointer l) ,(type->symbol return-type))))))))

(define (make-params-fundamental param-desc)
  '(begin (display `(make-params-fundamental ,param-desc)))

  (let ((val (let rec ((x param-desc))
               (cond ((symbol? x)
                      (case x
                        ((gchar)    'char)
                        ((guchar)   'uchar)
                        ((gboolean) 'bool)
                        ((gint)     'int)
                        ((guint)    'uint)
                        ((glong)    'long)
                        ((gulong)   'ulong)
                        ((gfloat)   'float)
                        ((gdouble)  'double)
                        ((void)     'void)
                        ((gpointer) '(maybe void*))
                        ((->)       '->)
                        ((gchararray) 'string)
                        (else 
                         (begin (display "Unknown param type: |")
                                (write x)
                                (display "|; treating as (maybe void*)")
                                (newline))
                         '(maybe void*))))
                     (else
                      (map rec x))))))
    val))

(define (g-signal-connect-data obj signal-name callback data notify flags)
  (let* ((param-desc (gsignal+object->params signal-name obj))
         (arg-desc (cadr param-desc))
         (fund-desc (make-params-fundamental param-desc))
         (callback-arity (procedure-arity callback))
         (core-proc
          (foreign-procedure "g_signal_connect_data"
                             `(void* string 
                                     ,fund-desc ;; this is context dependent
                                     ,(cond ((string? data) 'string)
                                            ((void*? data)  'void*)
                                            ((eqv? data #f) '(maybe void*))
                                            (else (error 'g-signal-connect-data
                                                         " Unknown data argument " data)))
                                     (maybe (-> (void* void*) void))
                                     unsigned)
                             'void*)))
    (if (and callback-arity
        (or (and (number? callback-arity) 
                 (exact? callback-arity)
                 (not (= callback-arity (length arg-desc))))
            (and (number? callback-arity)
                 (< (length arg-desc) callback-arity))))
        (error 'g-signal-connect-data
               " signal " signal-name 
               " expects a callback of type " param-desc
               " but given a callback of arity " callback-arity))
    '(begin (display `(g-signal-connect-data ,arg-desc ,(procedure-arity callback)))
           (newline))
    (core-proc obj signal-name callback data notify flags)))

;; Since we have closures, we don't *have* to use data-passing-style.
;; Allow user the option of selecting which they want.
(define (g-signal-connect source signal-name f . rest)
  (cond ((not (null? rest))
         (let ((d (car rest)))
           (g-signal-connect-data source signal-name f d #f 0)))
        (else
         (g-signal-connect-data 
          source signal-name 
          (let ((arity (procedure-arity f)))
            (cond ((and (exact? arity) (= arity 1)) (lambda (arg0 fake) (f arg0)))
                  ((and (exact? arity) (= arity 2)) (lambda (arg0 arg1 fake) (f arg0 arg1)))
                  ((and (exact? arity) (= arity 3)) (lambda (arg0 arg1 arg2 fake) (f arg0 arg1 arg2)))
                  ((and (exact? arity) (= arity 4)) (lambda (arg0 arg1 arg2 arg3 fake) (f arg0 arg1 arg2 arg3)))                  
                  ((and (exact? arity) (= arity 5)) (lambda (arg0 arg1 arg2 arg3 arg4 fake) (f arg0 arg1 arg2 arg3 arg4)))
                  (else
                   (lambda args
                     (let ((new-args (reverse (cdr (reverse args)))))
                       (apply f new-args))))))
          "fake-data-argument" ;; this is actually bad since it will marshall the string on every call; #f would be faster
          #f
          0))))

(define (g-signal-connect-swapped source signal-name f d)
  (g-signal-connect-data source signal-name f d #f 2))

(define-foreign (g-timeout-add uint (-> (void*) bool) (maybe void*)) uint)
(define-foreign (g-source-remove uint) bool)

(define glist*-rt (ffi-install-void*-subtype 'glist*))

(define-foreign (g-list-alloc) glist*)
(define-foreign (g-list-free glist*) void)
(define-foreign (g-list-free-1 glist*) void)
(define-foreign (g-list-append glist* void*) glist*)
(define-foreign (g-list-prepend glist* void*) glist*)
(define-foreign (g-list-insert glist* void* int) glist*)
(define-foreign (g-list-length glist*) uint)
(define-foreign (g-list-nth-data glist* uint) void*)

(define list->glist* 
  (let ((empty-glist ((record-constructor glist*-rt) 0)))
    (lambda (l)
      (cond ((null? l) empty-glist)
            (else (g-list-prepend (list->glist* (cdr l))
                                  (car l)))))))

(define gslist*-rt (ffi-install-void*-subtype 'gslist*))

(define-foreign (g-slist-alloc) gslist*)
(define-foreign (g-slist-free glist*) void)
(define-foreign (g-slist-free-1 glist*) void)
(define-foreign (g-slist-append glist* void*) gslist*)
(define-foreign (g-slist-prepend glist* void*) gslist*)
(define-foreign (g-slist-insert glist* void*) gslist*)
(define-foreign (g-slist-concat glist* gslist*) gslist*)
(define-foreign (g-slist-length glist*) uint)
(define-foreign (g-slist-nth-data glist* uint) void*)

(define list->gslist*
  (let ((empty-gslist ((record-constructor gslist*-rt) 0)))
    (lambda (l)
      (cond ((null? l) empty-gslist)
            (else (g-slist-prepend (list->gslist* (cdr l))
                                   (car l)))))))
