#lang racket

(provide (all-defined-out))             ;todo: fix this
(require (except-in "rotten.rkt" globals make-globals reset)) ;fixme

;;; A simple "virtual machine", based loosely on the Categorical Abstract
;;; Machine (CAM). See http://gallium.inria.fr/~xleroy/talks/zam-kazam05.pdf
;;; TODO: better reference link, that one is pretty brief

(define (true? x) (not (null? x)))
(define (list->mlist x) (foldr mcons '() x))

;; has-rest-param? is a *Racket* bool (#t or #f), not a Rotten bool ('t or '())
(struct closure (arity has-rest-param? code env) #:transparent)
(struct cont (instrs env) #:transparent)

;; VM globals, pre-populated with builtins
(define (make-globals)
  (make-hash
    `((apply . apply) ;; no unquote; apply is special. see call! in step-instr.
      (cons . ,mcons)
      (car . ,(lambda (x) (if (null? x) '() (mcar x))))
      (cdr . ,(lambda (x) (if (null? x) '() (mcdr x))))
      (set-car! . ,(lambda (x y) (set-mcar! x y) '()))
      (set-cdr! . ,(lambda (x y) (set-mcdr! x y) '()))
      (symbol? . ,(lambda (x) (if (symbol? x) 't '())))
      (cons? . ,(lambda (x) (if (mpair? x) 't '())))
      (atom? . ,(lambda (x) (if (mpair? x) '() 't)))
      (eq? . ,(lambda (x y) (if (eq? x y) 't '())))
      (+ . ,+) (- . ,-))))

(define globals (make-globals))
(define (reset) (set! globals (make-globals)))

;;; some contracts
(define env/c list?)
;; checks proper-ness, too
(define (mlist? x) (or (null? x) (and (mpair? x) (mlist? (mcdr x)))))
(define instr/c any/c)                  ;TODO: later

;; instrs is an mcons-list. data, env are cons-lists.
(define/contract (run instrs [data '()] [env '()])
  (case-> (-> mlist? any) (-> mlist? list? any) (-> mlist? list? env/c any))
  (car (run- instrs data env)))
(define/contract (run-body instrs [data '()] [env '()])
  (case-> (-> mlist? any) (-> mlist? list? any) (-> mlist? list? env/c any))
  (mlist? list? env/c . -> . any)
  (run- instrs data env) (void))
(define/contract (run- instrs data env)
  (mlist? list? env/c . -> . list?)
  (if (done? instrs data env) data
    (call-with-values (lambda () (step instrs data env)) run-)))

;;; we're done if we have no instructions left and <= 1 value on the stack
;;; (either 1 value, the value to return; or none, if we were eval'ing for
;;; side-effects)
(define (done? instrs data env)
  (and (null? instrs) (>= 1 (length data))))

(define/contract (step instrs data env)
  (mlist? list? env/c . -> . (values mlist? list? env/c))
  (when (done? instrs data env) (error "cannot step VM; it is done."))
  (if (null? instrs)
    (step-cont (car data) (cadr data) (cddr data))
    (step-instr (mcar instrs) (mcdr instrs) data env)))

(define (step-cont value kont data)
  (match-define (cont instrs env) kont)
  (values instrs (cons value data) env))

(define/contract (step-instr i instrs data env)
  (instr/c mlist? list? env/c . -> . (values mlist? list? env/c))
  ;; (displayln (format "INSTR ~a" i))
  ;; (displayln (format "  STK ~a" data))
  ;; (displayln (format "  ENV ~a" env))
  (define (pop!) (let ([x (car data)]) (set! data (cdr data)) x))
  (define (push! x) (set! data (cons x data)))
  (define (builtin! nargs f)
    (push! (apply f (reverse (for/list ([_ nargs]) (pop!))))))

  (define/contract (call! func args)
    (-> (or/c 'apply procedure? closure?) list? any)
    (match func
      ['apply
        (match-define `(,func ,args) args)
        (call! func (sequence->list args))]
      [(? procedure?) (push! (apply func args))]
      [(closure f-arity f-has-rest-param f-code f-env)
        (define num-args (length args))
        ;; check fn arity matches number of arguments
        (unless ((if f-has-rest-param <= =) f-arity num-args)
          ;; TODO: better error message
          (error "wrong number of arguments to function"))
        ;; munge arguments for rest parameter
        (when f-has-rest-param
          (set! args (append (take args f-arity)
                       (list (list->mlist (drop args f-arity))))))
        ;; perform the call
        (set! data (cons (cont instrs env) data))
        (set! instrs f-code)
        (set! env (append args f-env))]))

  ;; ----- instruction dispatch -----
  (match (if (mpair? i) (sequence->list i) i)
    [`(push ,x) (push! x)]
    [`pop (pop!)]
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
  ;; (displayln (format "NUSTK ~a" data))
  ;; (displayln (format "NUENV ~a" env))
  (values instrs data env))
