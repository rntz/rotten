#lang racket

;;; A simple "virtual machine", based on the Categorical Abstract Machine (CAM).
;;; See http://gallium.inria.fr/~xleroy/talks/zam-kazam05.pdf
;;; TODO: better reference link, that one is pretty brief

(define (done? instrs data env) (null? instrs))

(define (step instrs data env)
  (define i (car instrs))
  (set! instrs (cdr instrs))
  (run-instr i instrs data env))

(define (run-instr i instrs data env)
  (define (pop!) (let ([x (car data)]) (set! data (cdr data)) x))
  (define (push! x) (set! data (cons x data)))
  (match i
    [`(push ,x) (push! x)]
    [`(access ,n) (push! (list-ref env n))]
    [`(closure ,is) (push! (cons is env))]
    [`(call ,n)
      ;; FIXME: think about argument ordering
      (define/match `((,f-code . ,f-env) . ,args) (reverse (take (+ 1 n) data)))
      (set! data (cons `(,instrs . ,env) (drop (+ 1 n) data)))
      (set! instrs f-code)
      (set! env (append args f-env))]
    ['return
      (unless (null? instrs)
        (error "return did not terminate instruction stream!"))
      (define/match `(,return-value (,cont-code . ,cont-env) . ,d) data)
      (set! data `(,return-value . ,d))
      (set! instrs cont-code)
      (set! env code-env)]
    ;; builtin functions
    ;; FIXME TODO: think about order of arguments
    ['cons (push! (mcons (pop!) (pop!)))]
    ['car (push! (let ([x (pop!)]) (if (null? x) '() (mcar x))))]
    ['cdr (push! (let ([x (pop!)]) (if (null? x) '() (mcdr x))))]
    ['set-car! (set-mcar! (pop!) (pop!)) (push! '())]
    ['set-cdr! (set-mcdr! (pop!) (pop!)) (push! '())]
    ['symbol? (push! (if (symbol? (pop!)) 't '()))]
    ['cons?   (push! (if (mcons? (pop!)) 't '()))]
    ['eq?     (push! (eq? (pop!) (pop!)))]
    ['apply
      (define a (pop!))
      (define f (pop!))]
    )
  (values instrs data env))
