;;; Useful procedures defined below:

;;; object->property-form

'(require "Experimental/DotNet/simple-inspection")
type-type
'(require "Experimental/DotNet/toolsmith-form")
find-forms-type

;; TODO: change enumflags to produce a series of checkboxes rather
;;       than a single combo box.
;; TODO: don't render form objects as strings; instead make them 
;;       clickable entities (to allow interactive exploration of the
;;       object graph).
;; TODO (related to above): handle collections intelligently.

(define (type->value-box type)
  (define (names->fixed-combo-box names)
    (let ((cb (make-combo-box)))
      ;(set-combo-box-drop-down-style! cb 'dropdownlist)
      (for-each (lambda (name)
                  (combo-box-add-item! cb name))
                names)
      cb))
  (cond ((enum-type? type)
         (names->fixed-combo-box (clr-enum/get-names type)))
        ((subclass? type clr-type-handle/system-boolean)
         (names->fixed-combo-box '("True" "False")))
        (else 
         (make-text-box))))

(define (take lst n)
  (cond ((zero? n) '())
        ((null? lst) '())
        (else (cons (car lst) 
                    (take (cdr lst) (- n 1))))))

(define (object->property-form obj)
  (cond ((not (%foreign? obj))
         (error 'object->property-form 
                ": object " obj " is not a .NET object.")))
  (let* ((type (clr/%object-type obj))
         (property-list (type->properties type)))
    (define iform (make-form))
    (define panel (make-panel))
    (define split-container (make-split-container))
    (define flow-panel-lft (make-flow-layout-panel))
    (define flow-panel-rgt (make-flow-layout-panel))
    (define total-height 0)
    (set-scrollable-control-autoscroll! panel #t)
    (set-control-dock! panel 'fill)
    (set-flow-layout-panel-wrap-contents! flow-panel-lft #f)
    (set-flow-layout-panel-wrap-contents! flow-panel-rgt #f)
    ;(set-control-dock! split-container 'fill)
    (set-control-anchor! split-container 'top 'left 'right)
    (set-control-width! split-container (control-width panel))
    (set-flow-layout-panel-flow-direction! flow-panel-lft 'topdown)
    (set-flow-layout-panel-flow-direction! flow-panel-rgt 'topdown)
    (set-control-dock! flow-panel-lft  'fill)
    (set-control-dock! flow-panel-rgt  'fill)
    (add-controls (control-controls iform)
                  (list panel))
    (add-controls (control-controls panel)
                  (list split-container))
    (add-controls (control-controls (split-container-panel1 split-container))
                  (list flow-panel-lft))
    (add-controls (control-controls (split-container-panel2 split-container))
                  (list flow-panel-rgt))
    (for-each
     (lambda (pi)
       (let* ((name  (property-info->name pi))
              (ptype (property-info->type pi))
              (pval  (clr/%property-ref pi obj '#()))
              (label (make-label))
              (pbox  (type->value-box ptype))
              (panel-label (make-panel))
              (panel-pbox  (make-panel)))
         (set-control-text! label (symbol->string name))
         (set-control-text! pbox  (clr/%to-string pval))
         (let ((height (+ 0 (max (control-height label)
                                 (control-height pbox)))))
           (set! total-height (+ total-height height))
           (set-control-height! panel-label height)
           (set-control-height! panel-pbox  height))
         (add-controls (control-controls panel-label) (list label))
         (add-controls (control-controls panel-pbox) (list pbox))
         (add-controls (control-controls flow-panel-lft) (list panel-label))
         (add-controls (control-controls flow-panel-rgt) (list panel-pbox))))
     property-list)
    
    (set-control-height! split-container total-height)
    iform))

