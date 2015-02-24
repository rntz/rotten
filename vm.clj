;; How we represent Rotten data in Clojure:
;;
;; - Symbols, numbers, strings are Clojure symbols, numbers, and strings.
;; - '() is nil.
;;
;; - Conses (a . b) are 2-element vectors [a b]. I'd like to be able to use
;;   Clojure lists but Rotten permits improper lists and Clojure does not.
;;
;; - Closures: Implemented via defrecord.
(ns vm)

(defrecord Closure [arity has-rest-param code env])
(defrecord Cont [instrs env])

(def car first)
(def cdr second)

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
  [(.instrs cont) (cons value data) (.env cont)])

(defn step-instr [i instrs data env]
  (case (first i)
    'pop
    ))

