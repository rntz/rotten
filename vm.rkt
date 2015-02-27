#lang racket

(provide (all-defined-out))             ;TODO: fix this

;;; A simple "virtual machine", based loosely on the Categorical Abstract
;;; Machine (CAM). See http://gallium.inria.fr/~xleroy/talks/zam-kazam05.pdf
;;; TODO: better reference link, that one is pretty brief

(define (true? x) (not (null? x)))

;; has-rest-param? is a *Racket* bool (#t or #f), not a Rotten bool ('t or '())
(struct closure (arity has-rest-param? code env) #:transparent)
(struct cont (instrs env) #:transparent)

;; VM globals, pre-populated with builtins
(define (make-globals)
  (make-hash
    `((apply . apply) ;; no unquote; apply is special. see call! in step-instr.
      (cons . ,cons)
      (car . ,(lambda (x) (if (null? x) '() (car x))))
      (cdr . ,(lambda (x) (if (null? x) '() (cdr x))))
      (symbol? . ,(lambda (x) (if (symbol? x) 't '())))
      (cons? . ,(lambda (x) (if (pair? x) 't '())))
      (atom? . ,(lambda (x) (if (pair? x) '() 't)))
      (eq? . ,(lambda (x y) (if (eqv? x y) 't '())))
      (+ . ,+) (- . ,-))))

(define globals (make-globals))
(define (reset) (set! globals (make-globals)))

(define (run instrs [data '()] [env '()]) (car (run- instrs data env)))
(define (run-body instrs [data '()] [env '()]) (run- instrs data env) (void))
(define (run- instrs data env)
  (if (done? instrs data env) data
    (call-with-values (lambda () (step instrs data env)) run-)))

;;; we're done if we have no instructions left and <= 1 value on the stack
;;; (either 1 value, the value to return; or none, if we were eval'ing for
;;; side-effects)
(define (done? instrs data env)
  (and (null? instrs) (>= 1 (length data))))

(define (step instrs data env)
  (when (done? instrs data env) (error "cannot step VM; it is done."))
  (if (null? instrs)
    (step-cont (car data) (cadr data) (cddr data))
    (step-instr (car instrs) (cdr instrs) data env)))

(define (step-cont value kont data)
  (match-define (cont instrs env) kont)
  (values instrs (cons value data) env))

(define (step-instr i instrs data env)
  ;; (displayln (format "INSTR ~a" i))
  ;; (displayln (format "  STK ~a" data))
  ;; (displayln (format "  ENV ~a" env))
  (define (pop!) (let ([x (car data)]) (set! data (cdr data)) x))
  (define (push! x) (set! data (cons x data)))

  (define (call! func args)
    (match func
      ['apply
        (match-define `(,f ,as) args)
        (call! f as)]
      [(? procedure?) (push! (apply func args))]
      [(closure f-arity f-has-rest-param f-code f-env)
        (define num-args (length args))
        ;; check fn arity matches number of arguments
        (unless ((if f-has-rest-param <= =) f-arity num-args)
          (error "wrong number of arguments to function"))
        ;; munge arguments for rest parameter
        (when f-has-rest-param
          (set! args (append (take args f-arity) (list (drop args f-arity)))))
        ;; perform the call
        (set! data (cons (cont instrs env) data))
        (set! instrs f-code)
        (set! env (append args f-env))]))

  ;; ----- instruction dispatch -----
  (match i
    [`(push ,x) (push! x)]
    ['(pop) (pop!)]
    [`(access ,n) (push! (list-ref env n))]
    [`(closure ,arity ,has-rest-param ,code)
      (push! (closure arity (true? has-rest-param) code env))]
    [`(call ,n)
      ;; NB. use of 'reverse puts arguments in the right order.
      (match-define (cons f args) (reverse (take data (+ 1 n))))
      (set! data (drop data (+ 1 n)))
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
    [`(set-global ,name) (hash-set! globals name (car data))])
  (values instrs data env))
