#lang racket

(provide eval eval-body globals make-globals reset)

(require (prefix-in racket: racket) (only-in racket define))
(require (except-in r5rs define eval))

(define nil '())
(define (nil? x) (eq? x nil))
(define (true? x) (not (nil? x)))
(define cons? pair?)
(define (atom? x) (not (cons? x)))


;; Metacircular evaluator
;; env is an assoc list
(define (eval x [env '()])
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

(define (lookup name env)
  (let ((x (or (assoc name env) (assoc name globals))))
    (if x (cdr x)
      (error (format "sorry, no such variable: ~v" name)))))

(define (make-fn params body env)
  (lambda args (eval-body body (append (make-env params args) env))))

(define (make-env params args)
  (cond
    ((symbol? params) (list (cons params args)))
    ((cons? params)
      (if (cons? args)
        (cons (cons (car params) (car args))
          (make-env (cdr params) (cdr args)))
        (error (format "parameter mismatch: ~a doesn't match ~a" params args))))
    ((true? args) (error (format "unused arguments: ~a" args)))
    (#t nil)))

(define (eval-body body env)
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
  (set! globals (cons x globals))
  (cdr x))

;; Converts racket's #t/#f into rotten t/nil.
(define (predicate x)
  (lambda args
    (if (apply x args) 't nil)))


;; Global environment
(define (make-globals)
  (list
    (cons 'cons cons)
    (cons 'car (lambda (x) (if (nil? x) '() (mcar x))))
    (cons 'cdr (lambda (x) (if (nil? x) '() (mcdr x))))
    (cons 'set-car! (lambda (x y) (set-car! x y) '()))
    (cons 'set-cdr! (lambda (x y) (set-cdr! x y) '()))
    (cons 'symbol? (predicate symbol?))
    (cons 'atom? (predicate atom?))
    (cons 'cons? (predicate cons?))
    (cons 'eq? (predicate eqv?))
    (cons 'apply apply)
    (cons '+ +)
    (cons '- -)))

(define globals (make-globals))
(define (reset) (set! globals (make-globals)))


;; Tests
(module+ test
  (require rackunit)

  ;; turns pairs to mpairs
  (define (mify x)
    (if (not (racket:pair? x)) x
      (cons (mify (racket:car x)) (mify (racket:cdr x)))))

  ;; turns mpairs to pairs
  (define (rify x)
    (if (not (pair? x)) x
      (racket:cons (rify (car x)) (rify (cdr x)))))

  (define-syntax-rule (check-eval result src)
    (check-equal? (mify result) (eval (mify 'src))))

  (define-syntax-rule (check-t src) (check-eval 't src))
  (define-syntax-rule (check-nil src) (check-eval '() src))

  ;; simple
  (check-eval 2 2)
  (check-eval '() ())
  (check-eval cons cons)
  (check-eval 1 (car (cons 1 2)))
  (check-eval 2 (cdr (cons 1 2)))
  (check-eval 1 (car '(1 2)))
  (check-eval 'a 'a)
  (check-t (symbol? 'a))
  (check-eval '(1 . 2) (cons 1 2))

  ;; type-tests
  (check-t (cons? (cons 'a 'b)))
  (check-t (cons? '(a b c)))
  (check-nil (atom? '(a b c)))
  (check-t (atom? ()))
  (check-t (atom? 'a))
  (check-t (atom? 1))

  ;; functions
  (check-eval 0 ((fn (x) x) 0))
  (check-eval '(a) ((fn (x) (cons x nil)) 'a))
  (check-eval '(a) ((fn (x y) (cons x nil)) 'a 'b))
  (check-eval '(a . b) ((fn (x y) (cons x y)) 'a 'b)))
