;; $Id: custodian.sch 2543 2005-07-20 21:54:03Z pnkfelix $

;; Custodians
;; ----------

;; make-custodian : [custodian] -> custodian
;; custodian-shutdown-all : custodian -> void
;; custodian? : value -> boolean
;; custodian-managed-list : custodian custodian -> (listof value)
;; custodian-require-memory : integer custodian -> void
;; custodian-limit-memory : custodian integer custodian -> void
