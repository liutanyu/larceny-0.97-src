;; $Id: cont.sch 2543 2005-07-20 21:54:03Z pnkfelix $

;; MzScheme continuation-specific things.


;; call/ec : (escape-continuation -> values) -> values
;; Captures escape continuation, able to cross continuation barriers
;; when invoked from extension of itself.

;; call-with-continuation-barrier : (-> values) -> values
;; Calls thunk with barrier which prevents full continuation jumps
;; across it.
