; Copyright 1999 Lars T Hansen.
;
; $Id: tasking.sch 2543 2005-07-20 21:54:03Z pnkfelix $
;
; Non-I/O-aware multitasking for Larceny.

(require 'define-record)

; Interface

(define-syntax without-interrupts       ; Critical section
  (syntax-rules ()
    ((without-interrupts E0 E1 ...)
     (call-without-interrupts
       (lambda () E0 E1 ...)))))

(define begin-tasking)                  ; (begin-tasking)
(define end-tasking)                    ; (end-tasking)
(define spawn)                          ; (spawn thunk) => task
(define kill)                           ; (kill task)
(define yield)                          ; (yield)
(define current-task)                   ; (current-task) => task
(define task?)                          ; (task? obj) => boolean
(define block)                          ; (block task)
(define unblock)                        ; (unblock task)

; Implementation

; System-level critical section does not use dynamic-wind.

(define-syntax tasks/without-interrupts
  (syntax-rules ()
    ((tasks/without-interrupts E0 E1 ...)
     (let ((x (disable-interrupts)))
       (let ((r (begin E0 E1 ...)))
         (if x (enable-interrupts x))
         r)))))

(define *tasking-on* #f)
(define *saved-interrupt-handler*)
(define *saved-timeslice*)

(define (begin-tasking)
  (if *tasking-on* (error "Tasking is already on."))
  (disable-interrupts)
  (set! *tasking-on* #t)
  (set! *saved-interrupt-handler* (timer-interrupt-handler))
  (set! *saved-timeslice* (standard-timeslice))
  (standard-timeslice *timeslice*)
  (timer-interrupt-handler 
   (lambda ()
     (tasks/switch #t #f)))
  (tasks/initialize-scheduler)
  (enable-interrupts (standard-timeslice))
  (unspecified))

(define (end-tasking)
  (if (not *tasking-on*) (error "Tasking is not on."))
  (disable-interrupts)
  (set! *tasking-on* #f)
  (timer-interrupt-handler *saved-interrupt-handler*)
  (standard-timeslice *saved-timeslice*)
  (enable-interrupts (standard-timeslice))
  ; Kill whatever thread we're running and reenter the REPL.
  (display "About to reset\n")
  (reset))

(define (spawn thunk)

  (define tasking-reset-handler
    (lambda ()
      (display "Killing task ")
      (display (task-id (tasks/current-task)))
      (newline)
      (kill (tasks/current-task))))

  (if (not *tasking-on*) (error "Tasking is not on."))
  (tasks/without-interrupts
   (tasks/schedule (make-task 
                    (lambda ()
                      (parameterize ((reset-handler tasking-reset-handler))
                        (thunk)))))))

(define (kill t)
  (if (not *tasking-on*) (error "Tasking is not on."))
  (if (not (task? t)) (error "KILL: " t " is not a task."))
  (tasks/without-interrupts
   (task-alive-set! t #f)
   (cond ((tasks/runnable? t)
          (run-queue.remove! *run-queue* t))
         ((eq? t (tasks/current-task))
          (tasks/switch #f #f)))))

(define (yield)
  (if (not *tasking-on*) (error "Tasking is not on."))
  (let ((critical? (tasks/in-critical-section?)))
    (tasks/without-interrupts
     (tasks/switch #t critical?))))

(define (current-task) 
  (if (not *tasking-on*) (error "Tasking is not on."))
  (tasks/without-interrupts
   (tasks/current-task)))

(define (block t)
  (if (not *tasking-on*) (error "Tasking is not on."))
  (if (not (task? t)) (error "BLOCK: " t " is not a task."))
  (let ((critical? (tasks/in-critical-section?)))
    (tasks/without-interrupts
     (cond ((tasks/runnable? t)
            (run-queue.remove! *run-queue* t))
           ((eq? t (tasks/current-task))
            (tasks/switch #f critical?))))))

(define (unblock t)
  (if (not *tasking-on*) (error "Tasking is not on."))
  (if (not (task? t)) (error "UNBLOCK: " t " is not a task."))
  (tasks/without-interrupts
   (if (not (tasks/runnable? t))
       (tasks/schedule t))))

; Invariants:
;  * alive? is #t iff thunk has not been killed and thunk has not returned
;  * prev and next are #f iff task is not on run-queue
;  * the current task is never on the run queue.

(define-record task (k alive critical prev next id))

(define make-task 
  (let ((make-task make-task)
        (id 0))
    (lambda (thunk)
      (set! id (+ id 1))
      (make-task (lambda ()
                   (thunk)
                   (without-interrupts (tasks/exit)))
                 #t
                 #f
                 #f
                 #f
                 id))))

; Scheduler.  Call only with interrupts turned off.
;
; It's vital that errors are never signalled here without interrupts
; being turned on first.

(define *run-queue*)                    ; Queue of scheduled tasks
(define *current*)                      ; Current task
(define *repl-task*)                    ; Distinguished initial task
(define *timeslice* 5000)               ; Perhaps low on modern HW.

(define (tasks/initialize-scheduler)
  (set! *current* (make-task (lambda () #t)))
  (set! *repl-task* *current*)
  (set! *run-queue* (make-queue)))

(define (tasks/repl-task) *repl-task*)

(define (tasks/current-task) *current*)

(define (tasks/exit)
  (task-alive-set! *current* #f)
  (tasks/scheduler))

(define (tasks/schedule t)
  (if (task-alive t)
      (run-queue.insert! *run-queue* t)
      (tasks/critical-error "Attempted to schedule dead task " t)))

(define (tasks/switch schedule? in-critical-section?)
  (call-with-current-continuation
   (lambda (k)
     (let ((t *current*))
       (task-k-set! t (lambda () (k #f)))
       (task-critical-set! t in-critical-section?)
       (if schedule? (tasks/schedule t))
       (tasks/scheduler)))))

(define (tasks/scheduler)
  (let ((t (run-queue.dequeue! *run-queue*)))
    (set! *current* t)
    (if (task-critical t)
        (begin (task-critical-set! t #f)
               (enable-interrupts (standard-timeslice)) ; Set time slice.
               (disable-interrupts))           ; Re-enter critical section.
        (enable-interrupts (standard-timeslice)))
    ((task-k t))))

(define (tasks/in-critical-section?)
  (let ((x (disable-interrupts)))
    (if x (enable-interrupts x))
    (not x)))

(define (tasks/runnable? t) (task-prev t))

(define (tasks/critical-error . msg) (apply error msg)) ; FIXME.

; Run queue manipulation -- use in critical section only.

(define (make-queue) 
  (let ((q (make-task (lambda () (tasks/critical-error "NOT A TASK.")))))
    (task-next-set! q q)
    (task-prev-set! q q)
    q))

(define (run-queue.empty? q) 
  (eq? q (task-next q)))

(define (run-queue.head q)
  (if (run-queue.empty? q)
      (tasks/critical-error "Empty queue.")
      (task-next q)))

(define (run-queue.insert! q x)
  (task-next-set! x q)
  (task-prev-set! x (task-prev q))
  (task-next-set! (task-prev q) x)
  (task-prev-set! q x)
  x)

(define (run-queue.dequeue! q)
  (run-queue.remove! q (run-queue.head q)))
  
(define (run-queue.remove! q x)
  (task-prev-set! (task-next x) (task-prev x))
  (task-next-set! (task-prev x) (task-next x))
  (task-prev-set! x #f)
  (task-next-set! x #f))

; eof
