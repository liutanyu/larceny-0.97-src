(define nbuild-parameter #f)

(define *host* 'larceny)
(define *target* 'unix)

(define *petit-executable-name* "petit.bin")

(define *host-dir*  "Larceny")
(define *host-name* "Petit Larceny")

(define *twobit-executable-name* "twobit.bin")

(define *petit-linking-flags* '())

(define *change-feature-set* #f)

;; TODO: delete me

(define *make:larceny-target* "petitmacosx")

(define *host:endianness* 'big)
(define *host:os*         'unix)
(define *host:c-compiler*   #f)

(define *target:string-rep* 'flat1)
(define *target:endianness* 'big)
(define *target:os*         'unix)
(define *target:machine*    'standard-c)

(define *runtime:additional-features* '())

(define *target:machine-source* "Standard-C")

(define *root-directory* "")
(define *always-source* #f)
(define *verbose-load* #t)

(define *code-coverage* #f)
(define *rebuild-code-coverage* #f)

(define *makefile-configuration* #f)

;; *heap-type* : [Maybe [Oneof 'petit 'sparc-native]]

(define *heap-type* #f)

;; *runtime-type* : [Maybe [Oneof 'petit 'sparc-native]]

(define *runtime-type* #f)

(define *exit-on-error* #f)

;; This is the standard value defined by nbuild-param.sch
;; However, NASM needs to override it, so we expose it to petit-setup.sch

(define *globals-table* "globals.cfg")
