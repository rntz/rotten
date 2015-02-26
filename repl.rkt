#lang racket

(require
  (prefix-in i: "rotten.rkt") ;; direct interpreter
  (prefix-in vm: "vm.rkt"))   ;; VM

;; Utility
(define (read-all port)
  (let loop ([acc '()])
    (let ([x (read port)])
      (if (eof-object? x) (reverse acc)
        (loop (cons x acc))))))

(define (read-file filename) (call-with-input-file filename read-all))
(define (write-file filename code)
  (with-output-to-file filename #:exists 'truncate/replace
    (lambda ()
      (for ([x code]) (pretty-write x)))))


;;; Manipulating the interpreter
(define (i:load filename) (i:eval-body (read-file filename) '()) (void))
(define (i:load-eval) (i:load "rotten.rot"))
(define (i:load-compile) (i:load "compile.rot"))

;; only run these after (i:load-compile)
(define (i:compile src) (i:eval `(compile-exp ',src)))
(define (i:compile-program src) (i:eval `(compile-program ',src)))


;;; Manipulating the VM.
(define (boot [filename "compile.rotc"])
  (displayln "VM rebooting")
  (vm:reset)
  (printf "VM loading ~a\n" filename)
  (vm:load filename)
  (displayln "VM loading {read,write}-file extensions")
  (hash-set! vm:globals 'read-file read-file)
  (hash-set! vm:globals 'write-file write-file))

(define (vm:load filename) (vm:run-body (read-file filename)))

(define (vm:call funcname . args)
  (vm:run `((get-global ,funcname)
             ,@(map (lambda (x) `(push ,x)) args)
             (call ,(length args)))))

(define (vm:compile-exp src) (vm:call 'compile-exp src))
(define (vm:compile-program src) (vm:call 'compile-program src))
(define (vm:compile filename) (vm:compile-program (read-file filename)))
(define (vm:compile! filename [dest (string-append filename "c")])
  (write-file dest (vm:compile filename)))

(define (vm:eval e) (vm:run (vm:compile-exp e)))


;;; The repl
(define (repl [evaler vm:eval])
  (display "ROTTEN> ")
  (define exp (read))
  (unless (or (eof-object? exp) (equal? exp '(unquote quit)))
    (with-handlers ([exn:fail? (lambda (e) (log-error (exn-message e)))])
      (pretty-write (evaler exp)))
    (repl evaler)))

(module+ main
  (match (current-command-line-arguments)
    [`#(,x) (boot x)]
    [`#() (boot)])
  (repl))
