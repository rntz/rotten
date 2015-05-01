# Rotten

Rotten is a small self-hosting Lisp, designed as a vehicle for exploring Ken
Thompson's [Reflections on Trusting Trust][rott].

[rott]: http://www3.cs.stonybrook.edu/~cse509/p761-thompson.pdf

<!-- [rott]: http://cm.bell-labs.com/who/ken/trust.html -->

<!-- TODO: Section about the VM being based on the CAM? -->
<!-- TODO: Guide to where to start reading the files? -->

## How it works, in brief

1. Rotten compiles to a simple abstract machine ("the VM").

2. The VM is implemented in [Racket](http://www.racket-lang.org/). There's now a
   prototype implementation in Python, as well!

3. The compiler from Rotten to VM-code is
   [written in Rotten](http://en.wikipedia.org/wiki/Self-hosting).

<!-- TODO: talk about how bootstrapping/precompiled compiler is necessary to
self-host? -->

## Rotten is really small!

Rotten is a very simple lisp, and it targets a very high-level virtual machine,
so its implementation is quite small:

| File         | LOC   | Description               |
| ------------ | ----: | ------------------------- |
| compile.rot  | ~  70 | compiler                  |
| vm.rkt       | ~ 100 | VM interpreter            |
| repl.rkt     | ~  70 | repl & other conveniences |
| **TOTAL:**   | < 250 |                           |

There are other files in the repository but they're mostly unnecessary, except
for `compile.rotc` (the compiled version of `compile.rot`) &mdash; that's needed
for bootstrapping!

## Trusting Trust in Rotten

Rotten is named for Ken Thompson's [Reflections on Trusting Trust][rott], which
shows that a malicious compiler can invisibly compromise any program compiled by
it, including in particular itself! This makes for a wickedly
difficult-to-detect bug.

Rotten includes a (mildly) malicious compiler, `evil.rot`, which notices when
it's compiling a compiler, such as `compile.rot`, and injects a self-propagating
virus into it. The most interesting problem here is [quining][quine] the virus:
to self-propagate, the virus needs access to its own source code! You can see
some example quines and quine-generators in `quines.rkt`.

The only other symptom of this virus is that an infected compiler will compile
the symbol `rotten` to the string `"YOUR COMPILER HAS A VIRUS!!1!eleventyone"`.
This is a poor stand-in for the nefarious behavior a *real* implementation of
RoTT could inject into the compiler, but it will have to do for now.

[quine]: http://en.wikipedia.org/wiki/Quine_(computing)

## Getting started

First, install [git](http://git-scm.com/downloads) and
[Racket](http://download.racket-lang.org/). If you're on Ubuntu or Debian:

    ~$ sudo apt-get install git racket

If you don't have Racket but do have [Python](https://www.python.org), you can
try the [Python VM](#alternative-using-the-python-vm) instead.

Now grab Rotten:

    ~$ git clone https://github.com/rntz/rotten.git
    ~$ cd rotten
    ~/rotten$ racket repl.rkt
    VM rebooting
    VM loading compile.rotc
    VM loading {read,write}-file extensions
    ROTTEN>

Now you're at the Rotten repl!

### Alternative: using the Python VM

There's a prototype implementation of the VM in Python. It may still have bugs,
but you can use it like so:

    ~/rotten$ python repl.py
    booting up VM
    VM loading compile.rotc
    VM loading {read,write}-file extensions
    pyROTTEN>

You can tell it what file to boot up from by giving it a command-line argument,
just like the Racket version:

    ~/rotten$ python repl.py infected.rotc
    booting up VM
    VM loading infected.rotc
    VM loading {read,write}-file extensions
    pyROTTEN>

## A quick and dirty guide to Rotten

    ;; Comments start with semicolons.
    (+ 2 3)      ; --> 5

    ;; `def' defines global variables.
    (def x 17)
    x            ; --> 17

    ;; `def' also defines functions, Scheme-style.
    (def (double x) (+ x x))
    (double 23)  ; --> 46
    ;; You can define variadic functions with dotted parameter lists:
    (def (list . xs) xs)
    (list 2 3 5) ; --> (2 3 5)

    ;; cons, car, and cdr work as expected.
    (cons 34 46) ; --> (34 . 46)
    (car '(a b)) ; --> a
    (cdr '(a b)) ; --> (b)
    ;; The car and cdr of () are both ().
    (car '())    ; --> ()
    (cdr '())    ; --> ()
    ;; Conses are immutable; there is no set-car! or set-cdr!.

    ;; () is false; everything else is true. 't is the conventional true value.
    ;; t is just a symbol; you must quote it, or get an unbound variable error.
    (eq? 0 0)    ; --> t
    (eq? 0 1)    ; --> ()
    ()           ; --> ()
    t            ; --> raises error, "hash-ref: no value found for key"

    ;; () and nil are distinct; nil is just a symbol.
    (if ()   'yes 'no)          ; --> no
    (if 'nil 'yes 'no)          ; --> yes

    ;; `if' is variadic, like a less-parenthesized 'cond:
    (if (eq? 0 1) 'yes)         ; --> ()
    (if (eq? 0 1) 'yes 'no)     ; --> no
    (if (eq? 0 1) 'first
        (eq? 0 0) 'second)
    ; --> second
    (if (eq? 0 1) 'first
        (eq? 0 2) 'second)
    ; --> ()
    (if (eq? 0 1) 'first
        (eq? 0 2) 'second
        'otherwise)
    ; --> otherwise

    ;; Rotten's builtin functions are:
    ;; cons car cdr apply symbol? cons? atom? eq? + -
    ;; Rotten does not have macros, let-binding, or quasiquotation.

Some slightly larger examples:

    ;; A (non-tail-recursive) map function:
    (def (map f l)
      (if l
        (cons (f (car l))
              (map f (cdr l)))))

    ;; Fixed-point combinator.
    (def (fix f)
      (fn a (apply f (cons (fix f) a))))

    ;; In Rotten it's hard to locally define recursive functions, so often we
    ;; use globally-defined helper functions. Here, rev-append is a helper for
    ;; rev.
    (def (rev l) (rev-append l ()))
    (def (rev-append l acc)
      (if x (rev-append (cdr x) (cons (car x) y))
          y))

## The Trusting Trust exploit in Rotten

Rotten starts up by loading a pre-compiled image of the Rotten compiler from
`compile.rotc`:

    ~/rotten$ racket repl.rkt
    VM rebooting
    VM loading compile.rotc
    VM loading {read,write}-file extensions
    ROTTEN> (compile-exp '(+ 2 3))
    ((get-global +) (push 2) (push 3) (call 2))
    ROTTEN> (compile-program '((def x 0)
                               x))
    ((push 0) (set-global x) (pop) (get-global x))

With this, we can compile files at the REPL:

    ROTTEN> (def compiled (compile-program (read-file "compile.rot")))
    [... output omitted ...]
    ROTTEN> (write-file "new.rotc" compiled)
    #<void>

We just compiled our compiler! We can give `repl.rkt` an argument to force it
to load our newly compiled compiler image:

    ~/rotten$ racket repl.rkt new.rotc
    VM rebooting
    VM loading new.rotc
    VM loading {read,write}-file extensions
    ROTTEN>

To double-check our new compiler's integrity, we compare it with our previous
compiler:

    ~/rotten$ diff -s compile.rotc new.rotc
    Files compile.rotc and new.rotc are identical

Our compiler produced an exact copy of itself!

Now, remember `evil.rot`? It contains an evil compiler that, if we use it to
compile `compile.rot`, produces a compiler infected with a self-propagating
virus. Let's try it! First, we compile the evil compiler:

    ~/rotten$ racket repl.rkt
    ROTTEN> (write-file "evil.rotc" (compile-program (read-file "evil.rot")))

Now, we use the evil compiler to compile `compile.rot` into `infected.rotc`:

    ~/rotten$ racket repl.rkt evil.rotc
    ROTTEN> (write-file "infected.rotc" (compile-program (read-file "compile.rot")))

Finally, we run the infected compiler, and observe it is buggy:

    ~/rotten$ racket repl.rkt infected.rotc
    ROTTEN> rotten
    "YOUR COMPILER HAS A VIRUS!!1!eleventyone"

Observe that the bug persists even over a recompile:

    ~/rotten$ racket repl.rkt infected.rotc
    ROTTEN> (write-file "infected-2.rotc" (compile-program (read-file "compile.rot")))
    ROTTEN> ^D
    ~/rotten$ racket repl.rkt infected-2.rotc
    ROTTEN> rotten
    "YOUR COMPILER HAS A VIRUS!!1!eleventyone"

In fact, our infected compiler has *also* produced an exact copy of itself! But
of course, our safe compiler and our infected compiler differ:

    ~/racket$ diff -s infected.rotc infected-2.rotc
    Files infected.rotc and infected-2.rotc are identical
    ~/racket$ diff -q compile.rotc infected.rotc
    Files compile.rotc and infected.rotc differ

## Files

| File             | Purpose                                                  |
| ---------------- | -------------------------------------------------------- |
| compile.rot      | Compiler from Rotten to VM-code.                         |
| evil.rot         | Malicious compiler that infects compile.rot with a RoTT virus. |
| rotten.rot       | AST-walking metacircular Rotten interpreter (in Rotten). |
| vm.rkt           | VM interpreter.                                          |
| rotten.rkt       | AST-walking Rotten interpreter (in Racket).              |
| repl.rkt         | Rotten REPL & other conveniences.                        |
| quines.rkt       | Demonstration of various quining techniques.             |
| vm.py            | VM interpreter, in Python.                               |
| repl.py          | Rotten REPL, in Python.                                  |
| sexp.py          | S-expression parser and other utilities, in Python.      |
| compile.rotc     | Pre-compiled image of compile.rot, used for bootstrapping VM. |
| infected.rotc    | RoTT-infected version of compile.rotc.                        |
| README.md        | The file you're currently reading.                       |
| design.org       | Notes to myself about the design of Rotten.              |
| presentation.org | Notes to myself for presenting a demo of Rotten.         |

## Caveat lector
This project is an exercise in golfing. Therefore, everything in it is horribly,
horribly bad, including but not limited to:

- the language design
- the VM design
- the interpreter implementation
- the VM implementation
- the heuristic `evil.rot` uses to detect when it's compiling a compiler

**Do not** take any of these as an example of how to do it. If you'd like
pointers on slightly more reasonable ways to design and implement a lisp, feel
free to [email me](mailto:daekharel@gmail.com), although I am not an expert.
