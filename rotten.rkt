#lang racket

(require (only-in racket define make-parameter) (prefix-in racket: racket))
(require (except-in r5rs define eval))

(define nil '())
(define (nil? x) (eq? x nil))
(define (true? x) (not (nil? x)))
(define cons? pair?)
(define (atom? x) (not (cons? x)))

(define (mutify x)
  (if (racket:pair? x)
    (cons (mutify (racket:car x)) (mutify (racket:cdr x)))
    x))


;; Metacircular evaluator
;; env is a list of frames; a frame is a list of (name . value) pairs
(define (eval x [env (env*)])
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
  (set-car! env (cons x (car env)))
  (cdr x))

;; Converts racket's #t/#f into rotten t/nil.
(define (predicate x)
  (lambda args
    (if (apply x args) 't nil)))


;; Base environment
(define (make-env)
  (list
    (list
      (cons 'nil '())
      (cons 'cons cons)
      (cons 'car (lambda (x) (if (nil? x) '() (mcar x))))
      (cons 'cdr (lambda (x) (if (nil? x) '() (mcdr x))))
      (cons 'set-car! (lambda (x y) (set-car! x y) '()))
      (cons 'set-cdr! (lambda (x y) (set-cdr! x y) '()))
      (cons 'symbol? (predicate symbol?))
      (cons 'atom? (predicate atom?))
      (cons 'cons? (predicate cons?))
      (cons 'eq? (predicate eq?))
      (cons 'apply apply)
      (cons '+ +)
      (cons '- -))))

(define env* (make-parameter (make-env)))
(define (reset) (env* (make-env)))


;; Convenience tools
(define (read-all port)
  (let loop ((acc '()))
    (let ((x (read port)))
      (if (eof-object? x) (reverse acc)
        (loop (cons x acc))))))

(define (read-file filename) (call-with-input-file filename read-all))
(define (load-file filename [env (env*)]) (eval-body (read-file filename) env))

(define (reload) (reset) (load-file "rotten.rot"))


;; Tests
(module+ test
  (require rackunit)

  (define-syntax-rule (check-eval result src)
    (check-equal? (mutify result) (eval (mutify 'src))))

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
  (check-eval '(a . b) ((fn (x y) (cons x y)) 'a 'b))
  )
