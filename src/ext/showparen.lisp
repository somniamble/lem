(defpackage :lem/show-paren
  (:use :cl
        :alexandria
        :lem)
  (:export :showparen-attribute
           :forward-matching-paren
           :backward-matching-paren)
  #+sbcl
  (:lock t))
(in-package :lem/show-paren)

(defvar *brackets-overlays* '())

(define-attribute showparen-attribute
  (t :background "darkcyan" :foreground "white"))

(define-editor-variable forward-matching-paren 'forward-matching-paren-default)
(define-editor-variable backward-matching-paren 'backward-matching-paren-default)

(defun forward-matching-paren-default (point)
  (when (syntax-open-paren-char-p (character-at point))
    (with-point ((limit (window-view-point (current-window))))
      (unless (line-offset limit (window-height (current-window)))
        (buffer-end limit))
      (when-let ((goal-point (scan-lists (copy-point point :temporary) 1 0 t limit)))
        (character-offset goal-point -1)))))

(defun backward-matching-paren-default (point)
  (when (syntax-closed-paren-char-p (character-at point -1))
    (scan-lists (copy-point point :temporary) -1 0 t (window-view-point (current-window)))))

(defun update-show-paren ()
  (mapc #'delete-overlay *brackets-overlays*)
  (setq *brackets-overlays* nil)
  (let ((highlight-points '()))
    (or (when-let ((point (funcall (variable-value 'backward-matching-paren) (current-point))))
          (push (copy-point point :temporary) highlight-points)
          (when-let ((point (funcall (variable-value 'forward-matching-paren) point)))
            (push (copy-point point :temporary) highlight-points)))
        (when-let ((point (funcall (variable-value 'forward-matching-paren)  (current-point))))
          (push (copy-point point :temporary) highlight-points)))
    (dolist (point highlight-points)
      (push (make-overlay point
                          (character-offset (copy-point point :temporary) 1)
                          'showparen-attribute)
            *brackets-overlays*))))

(defvar *show-paren-timer* nil)

(define-command toggle-show-paren () ()
  (let ((enabled (not *show-paren-timer*)))
    (when (interactive-p)
      (message "show paren ~:[dis~;en~]abled." enabled))
    (cond (enabled
           (when *show-paren-timer*
             (stop-timer *show-paren-timer*))
           (setf *show-paren-timer*
                 (start-timer (make-idle-timer 'update-show-paren :name "show paren timer")
                              1
                              t))
           t)
          (t
           (when *show-paren-timer*
             (stop-timer *show-paren-timer*))
           (mapc #'delete-overlay *brackets-overlays*)
           (setq *brackets-overlays* nil)
           (setf *show-paren-timer* nil)))))

(unless *show-paren-timer*
  (toggle-show-paren))

(add-hook (variable-value 'mouse-button-down-functions :global) 'update-show-paren)
