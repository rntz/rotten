#lang racket

(require
  (prefix-in i: "rotten.rkt")           ;direct interpreter
  (prefix-in vm: "vm.rkt")              ;VM
  (prefix-in scheme: r5rs))

;; turns pairs to mpairs
(define (mify x)
  (if (not (pair? x)) x
    (mcons (mify (car x)) (mify (cdr x)))))

;; turns mpairs to pairs
(define (rify x)
  (if (not (mpair? x)) x
    (cons (rify (mcar x)) (rify (mcdr x)))))

;; Convenience tools
(define (read-all port)                ;reads as scheme does, not as racket does
  (let loop ([acc '()])
    (let ([x (scheme:read port)])
      (if (eof-object? x) (scheme:reverse acc)
        (loop (mcons x acc))))))

(define (read-file filename) (call-with-input-file filename read-all))
(define (write-file filename code)
  (with-output-to-file filename #:exists 'truncate/replace
    (lambda ()
      (for ([x code]) (pretty-write x)))))

(define-syntax-rule (silent e)
  (with-output-to-file "/dev/null" #:exists 'append (lambda () e)))


;;; Manipulating the interpreter
(define (i:load filename) (i:eval-body (read-file filename) '()) (void))
(define (i:load-eval) (i:load "rotten.rot"))
(define (i:load-compile) (i:load "compile.rot"))

;; only run these after (i:load-compile)
(define (i:compile src) (rify (i:eval (mify `(compile-exp ',src)))))
(define (i:compile-program src) (rify (i:eval (mify `(compile-program ',src)))))


;;; Manipulating the VM.
(define (vm:load filename) (vm:run-body (read-file filename)))

(define (vm:boot [filename "compile.rotc"])
  (displayln "VM rebooting")
  (vm:reset)
  (printf "VM loading ~a\n" filename)
  (vm:load filename)
  (displayln "VM reading contents of \"compiler.rot\" into 'compiler-src")
  (hash-set! vm:globals 'compiler-src (read-file "compile.rot")))

(define (vm:call funcname . args)
  (vm:run (mify `((get-global ,funcname)
                  ,@(map (lambda (x) `(push ,x)) args)
                  (call ,(length args))))))

(define (vm:compile-exp src) (vm:call 'compile-exp src))
(define (vm:compile-program src) (vm:call 'compile-program src))
(define (vm:compile filename) (vm:compile-program (read-file filename)))
(define (vm:compile! filename [dest (string-append filename "c")])
  (write-file dest (vm:compile filename)))

(define (vm:eval e) (vm:run (vm:compile-exp e)))

;;; useful for extracting compiled code, if you did it at the repl rather than
;;; using vm:compile!
(define (vm:save filename var)
  (write-file filename (hash-ref vm:globals var)))


;;; The repl
(define (repl [evaler vm:eval])
  (display "ROTTEN> ")
  (define exp (scheme:read))
  (unless (equal? '(unquote quit) (rify exp))
    (with-handlers ([(lambda (_) #t)
                      ;; FIXME: should display the error, not printf it
                      (lambda (e) (printf "~a\n" e))])
      (pretty-write (evaler exp))
      (newline))
    (repl evaler)))

(define (i:repl) (repl i:eval))
(define (vm:repl) (repl vm:eval))
