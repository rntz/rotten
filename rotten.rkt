#lang r5rs

(#%require (only racket error format) (prefix r: racket)) ;magic

(define nil '())
(define (nil? x) (eq? x nil))
(define (true? x) (not (nil? x)))
(define cons? pair?)
(define (atom? x) (not (cons? x)))


;; Metacircular evaluator
;; env is a list of frames; a frame is a list of (name . value) pairs
(define (eval x env)
  ;(r:displayln (format "eval ~a" x))
  (cond
    ((symbol? x) (lookup x env))      ;variable
    ((atom? x) x)                     ;literal
    ;; special forms
    ((eq? (car x) 'quote) (cadr x))
    ((eq? (car x) 'fn)    (make-fn (cadr x) (cddr x) env))
    ((eq? (car x) 'if)    (eval-if (cdr x) env))
    ((eq? (car x) 'def)   (eval-def (cadr x) (cddr x) env))
    ;; otherwise, function application
    (#t (apply (eval (car x) env)
          (map (lambda (x) (eval x env)) (cdr x))))))

(define (any f l) (and (cons? l) (or (f (car l)) (any f (cdr l)))))
(define (lookup name env)
  (let ((x (any (lambda (x) (assoc name x)) env)))
    (if x (cdr x)
      (error (format "sorry, no such variable: ~v" name)))))

(define (make-fn params body env)
  (lambda args (eval-body body (cons (make-frame params args) env))))

(define (make-frame params args)
  (cond
    ((symbol? params) (list (cons params args)))
    ((cons? params)
      (if (cons? args)
        (cons (cons (car params) (car args))
          (make-frame (cdr params) (cdr args)))
        (error (format "parameter mismatch: ~a doesn't match ~a" params args))))
    ((true? args) (error (format "unused arguments: ~a") args))
    (#t nil)))

(define (eval-body body env)
  ;(r:displayln (format "eval-body ~a" body))
  (if (null? body) nil
    (let ((x (eval (car body) env)))
      (if (null? (cdr body)) x
        (eval-body (cdr body) env)))))

(define (eval-if conds env)
  (cond
    ((nil? conds) nil)
    ((nil? (cdr conds)) (eval (car conds) env))
    ((true? (eval (car conds) env)) (eval (cadr conds) env))
    (#t (eval-if (cddr conds) env))))

(define (eval-def target body env)
  (define x
    (if (cons? target)
      ;; defining a function
      (cons (car target) (make-fn (cdr target) body env))
      ;; defining a value
      (cons target (eval-body body env))))
  (set-car! env (cons x (car env)))
  (cdr x))

;; Converts racket's #t/#f into rotten t/nil.
(define (predicate x)
  (lambda args
    (if (apply x args) 't nil)))

;; Base environment
(define init-env
  (list
    (list
      (cons 'nil '())
      (cons 'cons cons)
      (cons 'car car)
      (cons 'cdr cdr)
      (cons 'set-car! set-car!)
      (cons 'set-cdr! set-cdr!)
      (cons 'symbol? (predicate symbol?))
      (cons 'atom? (predicate atom?))
      (cons 'cons? (predicate cons?))
      (cons 'eq? (predicate eq?))
      (cons 'apply apply))))


;; Convenience tools
(define (read-all port)
  (let loop ((acc '()))
    (let ((x (read port)))
      (if (eof-object? x) (reverse acc)
        (loop (cons x acc))))))

(define (read-file filename) (call-with-input-file filename read-all))
(define (load-in filename env) (eval-body (read-file filename) env))

(define (ld filename) (load-in filename init-env))
(define (ev x) (eval x init-env))
