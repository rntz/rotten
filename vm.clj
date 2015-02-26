;; How we represent Rotten data in Clojure:
;;
;; - Symbols, numbers, strings are Clojure symbols, numbers, and strings.
;; - '() is nil.
;;
;; - Conses (a . b) are 2-element vectors [a b]. I'd like to be able to use
;;   Clojure lists but Rotten permits improper lists and Clojure does not.
;;
;; - Closures: Implemented via defrecord.
(ns vm
  (:use [clojure.core.match :refer [match]]))

(defrecord Closure [arity has-rest-param? code env])
(defrecord Cont [instrs env])

(def car first)
(def cdr second)

(defn to-rlist "Converts a seq to a rotten list."
  [s]
  (reduce (fn [x y] [y x]) '() (reverse s)))

(defn t? [x] (not (= nil x)))

;;; VM globals: an atom containing a map.
(def init-globals
  {'apply   'apply
   'cons    #(vector %1 %2)
   'car     car
   'cdr     cdr
   'symbol? #(if (symbol? %) 't nil)
   'cons?   #(if (vector? %) 't nil)
   'atom?   #(if (vector? %) nil 't)
   'eq?     #(if (= %1 %2) 't nil)
   '+       +
   '-       -})

(def globals (atom init-globals))
(defn reset [] (swap! globals (fn [_] init-globals)))

(defn done? [instrs data env]
  (and (= nil instrs) (>= 1 (count data))))

;; instrs: rotten-list of instructions
;;   data: list of rotten values
;;    env: vector of rotten values.
(declare step)
(defn run- [instrs data env]
  (if (done? instrs data env) data
    (apply run- (step instrs data env))))
(defn run
  ([instrs] (run instrs '() []))
  ([instrs data env] (first (run- instrs data env))))
(defn run-body
  ([instrs] (run-body instrs '() []))
  ([instrs data env] (run- instrs data env) nil))

(declare step-cont step-instr)
(defn step [instrs data env]
  (when (done? instrs data env)
    (throw (Exception. "cannot step VM; it is done.")))
  (if instrs
    ;; stack is (RETVAL CONT & RESTOFSTK)
    (let [[retval cont & stk] data] (step-cont retval cont stk))
    (step-instr (car instrs) (cdr instrs) data env)))

(defn step-cont [value cont data]
  [(.instrs cont) (conj data value) (.env cont)])

(declare do-call)
(defn step-instr [i instrs data env]
  (match [(vec i)]
    [['pop]]        [instrs (pop data) env]
    [['push x]]     [instrs (conj data x) env]
    [['access n]]   [instrs (conj data (nth env n)) env]
    [['call n]]
      (let [[f & args] (take (+ 1 n) data)]
        (do-call f args instrs (nthnext data (+ 1 n)) env))
    [['if thn-code els-code]]
      (let [code (if (t? (peek data)) thn-code els-code)
            data (pop data)]
        [code (conj data (Cont. instrs env)) env])
    [['get-global name]]
      (let [val (if (contains? @globals name) (@globals name)
                    (throw (Exception. "unbound global")))]
        [instrs (conj data val) env])
    [['set-global name]]
      (do (swap! globals assoc name (peek data))
          [instrs data env])))

(defn do-call [f as instrs data env]
  (cond
    (= f 'apply) (let [[f as] as] (do-call f as))
    (fn? f)      [instrs (conj data (apply f as)) env]
    (instance? Closure f)
      (if ((if (.has-rest-param? f) < not=) (count as) (.arity f))
        (throw (Exception. "wrong number of arguments to function"))
        (let [as (if (not (.has-rest-param? f)) as
                     (concat (take as (.arity f))
                             (list (to-rlist (drop as (.arity f))))))]
          [(.code f) (conj data (Cont. instrs env)) (into (.env f) as)]))
    :else (throw (Exception. "not callable"))))
