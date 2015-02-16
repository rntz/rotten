#lang racket

(require
  (only-in "rotten.rkt" read-file rify mify)
  (prefix-in i: "rotten.rkt")
  (prefix-in vm: "vm.rkt"))

(define compiler-src (read-file "compile.rot"))
(define (load-evaler) (i:load-file "rotten.rot") (void))
(define (load-compiler) (i:load-file "compile.rot") (void))

(i:reset)
(load-compiler)
(define (i:compile src) (rify (i:eval (mify `(compile-exp ',src)))))
(define (i:compile-program src) (rify (i:eval (mify `(compile-program ',src)))))
(define compiler-code (i:compile-program compiler-src))

(define (vm-run-compiler) (vm:run-body compiler-code '() '()))

(define (write-file filename code)
  (with-output-to-file filename #:exists 'truncate/replace
    (lambda ()
      (for ([x code]) (pretty-write x)))))

(define-syntax-rule (silent e)
  (with-output-to-file "/dev/null" #:exists 'append (lambda () e)))

;; TODO: functon for bootstrapping the VM by loading a compiled file containing
;; the compiler.
;;
;; TODO: function for evaluating source in a bootstrapped VM.
;; TODO: function for running a repl in a bootstrapped VM.
(define (vm-bootstrap filename)
  (vm:reset)
  (define code (read-file filename))
  (vm:run-body code))

(define (boot) (silent (vm-bootstrap "compile.rotc")))

(define (vm-compile src) (vm:run (vm-compile-instrs src)))
(define (vm-compile-instrs src)
  (mify `((get-global compile-exp) (push ,src) (call 1))))

(define (vm-eval e) (vm:run (silent (vm-compile e))))

;; try: (silent (vm-eval '((fn (x) x) 2)))

;;; FIXME: when I pass code off to vm-run, I've 'rify-ed it. BUT this makes
;;; (push (x y z)) *wrong*, since it pushes an *immutable* cons rather than a
;;; mutable cons!
;;;
;;; Not sure where the fix for this belongs. Probably in the VM somewhere. Maybe
;;; the VM should just deal only with mutable lists.
;;;
;;; (Indeed, there is the question of how the mutability of a quoted list should
;;; be handled in the first place. Does every eval give a fresh copy? Or the
;;; same copy, which can be mutated with the expected but totally weird results?
;;; Ah, and the results might vary depending on whether we interpret or compile!
;;; Best to avoid that.)
