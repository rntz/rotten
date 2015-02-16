#lang racket

(require "rotten.rkt" (prefix-in vm: "vm.rkt"))

(define compiler-src (read-file "compile.rot"))
(define (load-eval) (reset) (load-file "compile.rot"))
(define (load-compile) (reset) (load-file "compile.rot"))

(load-compile)

(define (compile src)
  (rify (eval (mify `(compile-prog ',src '())))))

(define compile-code (compile compiler-src))

(define (test) (vm:run- compile-code '() '()))

