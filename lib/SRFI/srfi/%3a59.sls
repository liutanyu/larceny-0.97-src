; SRFI 59: Vicinities
;
; $Id: %3a59.sls 5847 2008-12-14 02:12:21Z will $
;
; See <http://srfi.schemers.org/srfi-59/srfi-59.html> for the full document.

(library (srfi :59 vicinities)

  (export program-vicinity library-vicinity implementation-vicinity
          user-vicinity home-vicinity in-vicinity sub-vicinity
          make-vicinity pathname->vicinity vicinity:suffix?)

  (import (rnrs base)
          (primitives
           r5rs:require
           program-vicinity library-vicinity implementation-vicinity
           user-vicinity home-vicinity in-vicinity sub-vicinity
           make-vicinity pathname->vicinity vicinity:suffix?))

  (r5rs:require 'srfi-59))

(library (srfi :59)

  (export program-vicinity library-vicinity implementation-vicinity
          user-vicinity home-vicinity in-vicinity sub-vicinity
          make-vicinity pathname->vicinity vicinity:suffix?)

  (import (srfi :59 vicinities)))

; eof
