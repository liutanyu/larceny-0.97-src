;;; SRFI 98
;;; An interface to access environment variables.
;;;
;;; $Id: %3a98.sls 6183 2009-04-10 21:03:12Z will $

(library (srfi :98 os-environment-variables)

  (export get-environment-variable get-environment-variables)

  (import (only (rnrs base) quote)
          (primitives
           r5rs:require
           get-environment-variable get-environment-variables))

  (r5rs:require 'srfi-0)
  (r5rs:require 'srfi-98))

(library (srfi :98)

  (export get-environment-variable get-environment-variables)

  (import (srfi :98 os-environment-variables)))

; eof
