;; Notes to self:
;; (car nil) = nil
;; (symbol? nil) = nil
;; (atom? x) = (not (cons? x))
;;
;; specials: quote fn if or
;; builtins: cons car cdr set-car! set-cdr! symbol? atom? cons? eq? apply

;; bootstrapping
(def (id x) x)
(def (caar x) (car (car x)))
(def (cadr x) (car (cdr x)))
(def (cddr x) (cdr (cdr x)))
(def (cdar x) (cdr (car x)))

(def (list . xs) xs)
(def (map f x) (if x (cons (f (car x)) (map f (cdr x)))))
(def (any test l) (if l (or (get (car l)) (find get (cdr l)))))
(def (assoc k l) (any (fn (x) (if (eq? k (car x)) x)) l))

;; metacircular evaluator
;;; TODO: fexprize this and see if it's shorter.
(def (eval x env)
  (if
    (symbol? x) (lookup x env)          ;variable
    (atom? x) x                         ;literal
    (eq? (car x) 'quote) (cadr x)
    ;; special forms
    (eq? (car x) 'fn) (make-fn (cadr x) (cddr x) env)
    (eq? (car x) 'or) (or (eval (cadr x) env) (eval (cons 'or (cddr x)) env))
    (eq? (car x) 'if) (eval-if (cdr x) env)
    ;; otherwise, function application
    (apply (eval (car x) env) (map (fn (x) (eval x env)) env))))

(def (lookup name env) (cdr (any (fn (x) (assoc name x)) env)))

(def (eval-if conds env)
  (if (cdr conds)
    (if (eval (car conds) env) (eval (cadr conds) env)
      (eval-if (cddr conds) env))
    (eval (car conds) env)))

(def (make-fn params body env)
  (fn args (eval-body body (cons (make-frame params args) env))))

(def (make-frame params args)
  (if
    (symbol? params) (list (cons params args))
    params (cons (cons (car params) (car args))
             (make-frame (cdr params) (cdr args)))))

(def (eval-body body env)
  (if body ((fn (stmt body) (eval-stmt stmt env) (eval-body body env))
             (car body) (cdr body))))

(def (eval-stmt stmt env)
  (if (eq? 'def (car stmt))
    (eval-def (cadr stmt) (cddr stmt) env)
    (eval stmt env)))

(def (eval-def target body env)
  (set-car! env
    (cons
      (if (cons? target)
        ;; defining a function
        (cons (car target) (make-fn (cdr target) body env))
        ;; defining a value
        (cons target (eval-body body env)))
      (car env))))

(def init-env
  (list
    (list
      (cons 'cons cons)
      (cons 'car car)
      (cons 'cdr cdr)
      (cons 'set-car! set-car!)
      (cons 'set-cdr! set-cdr!)
      (cons 'symbol? symbol?)
      (cons 'atom? atom?)
      (cons 'cons? cons?)
      (cons 'eq? eq?)
      (cons 'apply apply))))

;; compiler to... something
