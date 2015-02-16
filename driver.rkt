#lang racket

(require "rotten.rkt" (prefix-in vm: "vm.rkt"))

(define compiler-src (read-file "compile.rot"))
(define (load-eval) (reset) (load-file "rotten.rot"))
(define (load-compile) (reset) (load-file "compile.rot"))

(load-compile)
(define (compile src) (rify (eval (mify `(compile-prog ',src '())))))
(define compiler-code (compile compiler-src))

(define (test) (vm:run-body compiler-code '() '()))

(define (write-file filename code)
  (with-output-to-file filename #:exists 'truncate/replace
    (lambda ()
      (for ([x code]) (pretty-write x)))))
