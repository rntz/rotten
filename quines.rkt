#lang racket

;;; One of the fundamental techniques involved in Ken Thompson's Reflections on
;;; Trusting Trust is quining: writing a program which can access its own source
;;; code. Here are a few example quines in Racket.

;;; QUINE #1
;;; with care, we could move replace-magic inside of the quine,
;;; but I think it's clearer this way.
(define (replace-magic r e)
  (match e
    [`(quote ,_) e]
    ['MAGIC r]
    [(cons a b) (cons (replace-magic r a) (replace-magic r b))]
    [_ e]))

(define (quine)
  (define source
    '(define (quine)
       (define source MAGIC)
       (displayln "Hello I am a quine.")
       (replace-magic (list 'quote source) source)))
  (displayln "Hello I am a quine.")
  (replace-magic (list 'quote source) source))

;;; QUINE #2
;;; takes advantage of quasiquotation, but is a little tricky because of that
(define (quine2)
  (define (source x)
    `(define (quine2)
       (define (source x) ,x)
       (displayln "Hello I am a quine.")
       (source
         (list 'quasiquote (source (list (string->symbol "unquote") 'x))))))
  (displayln "Hello I am a quine.")
  (source
    (list 'quasiquote (source (list (string->symbol "unquote") 'x)))))


;;; A more advanced technique is writing a quine *generator*. You give a quine
;;; generator a program that *wants* to access its own source, and it produces a
;;; program that *does*.

;;; QUINE GENERATOR #1
;;; (make-quine self '(list 'hello self))
;;; returns a program that runs (list 'hello self),
;;; with 'self bound to its own source code
(define (make-quine name src)
  (define magic-src
    `(let ([,name (replace-magic 'MAGIC 'MAGIC)])
       ,src))
  (replace-magic magic-src magic-src))

;;; making this self-sufficient
(define (make-quine-better name src)
  (define magic-src
    `(let ()
       (define (replace-magic r e)
         (match e
           [`(quote ,_) e]
           ['MAGIC r]
           [(cons a b) (cons (replace-magic r a) (replace-magic r b))]
           [_ e]))
       (define ,name (replace-magic (list 'quote MAGIC) MAGIC))
       ,src))
  (replace-magic (list 'quote magic-src) magic-src))

;;; QUINE GENERATOR #2
;;; I barely understand this one myself.
;;;
;;; (make-quine2 (lambda (x) `(list 'hello ,x)))
;;; returns a program that runs (list 'hello SELF)
;;; where SELF is its own (quoted) source code
(define (make-quine2 func)
  (define gen (gensym 'gen))
  (define self (gensym 'self))
  (define arg (gensym 'x))
  (define (source x)
    `(let ()
       (define (,gen ,arg) ,x)
       (define ,self
         (,gen
           (list 'quasiquote (,gen (list (string->symbol "unquote") ',arg)))))
       ,(func self)))
  (source (list 'quasiquote (source (list 'unquote arg)))))

;; cheating implementation of quine2:
(define (make-quine2-cheating func)
  (let ([name (gensym)])
    (make-quine name (func name))))
