#lang racket

(provide (all-defined-out))             ;todo: fix this

;;; A simple "virtual machine", based mostly on the Categorical Abstract Machine
;;; (CAM). See http://gallium.inria.fr/~xleroy/talks/zam-kazam05.pdf
;;; TODO: better reference link, that one is pretty brief

(define-syntax-rule (with-values generator-expr receiver)
  (call-with-values (lambda () generator-expr) receiver))

(define (true? x) (not (null? x)))

(struct closure (arity has-rest-param? code env) #:transparent)
(struct cont (instrs env) #:transparent)

(define globals (make-hash))
(define (reset) (set! globals (make-hash)))

(define (run instrs data env) (car (run- instrs data env)))
(define (run-body instrs data env) (run- instrs data env) (void))
(define (run- instrs data env)
  (unless (done? instrs data env) data
    (with-values (step instrs data env) run)))

;;; we're done if we have no instructions left and <= 1 value on the stack
;;; (either 1 value, the value to return; or none, if we were eval'ing for
;;; side-effects)
(define (done? instrs data env)
  (and (null? instrs) (<= 1 (length data))))

(define (step instrs data env)
  (when (done? instrs data env) (error "cannot step VM; it is done."))
  (if (null? instrs)
    (step-cont (car data) (cadr data) (cddr data))
    (step-instr (car instrs) (cdr instrs) data env)))

(define (step-cont value kont data)
  (match-define (cont instrs env) kont)
  (values instrs (cons value data) env))

(define (step-instr i instrs data env)
  (define (pop!) (let ([x (car data)]) (set! data (cdr data)) x))
  (define (push! x) (set! data (cons x data)))
  (define (builtin! nargs f)
    (push! (apply f (reverse (for/list ([_ nargs]) (pop!))))))

  (define (call! func args)
    (define num-args (length args))
    (match-define (closure f-arity f-has-rest-param f-code f-env) func)
    ;; check fn arity matches number of arguments
    (unless ((if f-has-rest-param <= =) num-args f-arity)
      ;; TODO: better error message
      (error "wrong number of arguments to function"))
    ;; munge arguments for rest parameter
    (when f-has-rest-param
      (set! args (append (take f-arity args) (list (drop f-arity args)))))
    ;; perform the call
    (set! data (cons (cont instrs env) data))
    (set! instrs f-code)
    (set! env (append args f-env)))

  ;; ----- instruction dispatch -----
  (match i
    [`(push ,x) (push! x)]
    [`pop (pop!)]
    [`(access ,n) (push! (list-ref env n))]
    [`(closure ,arity ,has-rest-param ,code)
      (push! (closure arity (true? has-rest-param) code env))]
    [`(call ,n)
      ;; NB. use of 'reverse puts arguments in the right order.
      (match-define (cons f args) (reverse (take (+ 1 n) data)))
      (set! data (drop (+ 1 n) data))
      (call! f args)]
    [`(if ,thn-code ,els-code)
      (define code (if (true? (pop!)) thn-code els-code))
      ;; NB. the continuation for if-branches doesn't really need an `env'
      ;; value, since env won't be changed. but it's simpler to do this then
      ;; to create a new type of continuation.
      (push! (cont instrs env))
      (set! instrs code)]
    ;; global environment
    [`(get-global ,name) (push! (hash-ref globals name))]
    [`(set-global ,name) (hash-set! globals (pop!))]
    ;; builtin functions
    ['cons        (builtin! 2 mcons)]
    ['car         (builtin! 1 (lambda (x) (if (null? x) '() (mcar x))))]
    ['cdr         (builtin! 1 (lambda (x) (if (null? x) '() (mcdr x))))]
    ['set-car!    (builtin! 2 (lambda (x y) (set-mcar! x y) '()))]
    ['set-cdr!    (builtin! 2 (lambda (x y) (set-mcdr! x y) '()))]
    ['symbol?     (builtin! 1 (lambda (x) (if (symbol? x) 't '())))]
    ['cons?       (builtin! 1 (lambda (x) (if (mpair? x) 't '())))]
    ['eq?         (builtin! 2 (lambda (x y) (if (eq? x y) 't '())))]
    ['apply
      (define args (pop!))
      (define func (pop!))
      (call! func args)])
  (values instrs data env))
