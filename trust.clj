;; env is an atom containing
(defn eval [x env]
  (cond
    (symbol? x) (lookup x env)        ;variable
    (not (seq? x)) x                  ;literal
    :else (case (first x)
            lambda (make-lambda (rest x) env)
            ;; otherwise, it's a function application
            (apply (eval (first x) env) (map #(eval % env) (rest x))))))

(defn eval-stmt [stmt env]
  (case (if (seq? stmt) (first stmt))
    define
    ))
