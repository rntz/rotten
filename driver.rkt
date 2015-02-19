#lang racket

(require
  (only-in "rotten.rkt" read-file rify mify)
  (prefix-in i: "rotten.rkt")
  (prefix-in vm: "vm.rkt")
  (prefix-in scheme: r5rs))

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

(define (vm-reset) (displayln "VM resetting") (vm:reset))
(define (vm-load filename)
  (printf "VM loading ~a\n" filename)
  (silent (vm:run-body (read-file filename))))

(define (vm-boot [filename "compile.rotc"])
  (vm-reset)
  (vm-load filename)
  (displayln "VM reading contents of \"compiler.rot\" into 'compiler-src")
  (hash-set! vm:globals 'compiler-src (read-file "compile.rot")))

(define (vm-compile src) (vm:run (vm-compile-instrs src)))
(define (vm-compile-instrs src)
  (mify `((get-global compile-exp) (push ,src) (call 1))))
(define (vm-compile-file filename)
  (vm:run (mify `((get-global compile-program)
                   (push ,(read-file filename))
                   (call 1)))))
(define (vm-compile-file! filename [dest (string-append filename "c")])
  (write-file dest (vm-compile-file filename)))

(define (vm-eval e) (vm:run (silent (vm-compile e))))

(define (vm-repl)
  (display "ROTTEN> ")
  (define src (scheme:read))
  (unless (equal? '(unquote quit) (rify src))
    (with-handlers ([(lambda (_) #t)
                      (lambda (e) (printf "~a\n" e))])
      (printf "~a\n" (vm-eval src)))
    (vm-repl)))

(define (vm-extract-compiler var filename)
  (write-file filename (hash-ref vm:globals var)))

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
