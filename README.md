# Rotten

Rotten is a small self-hosting Lisp, designed as a vehicle for exploring Ken
Thompson's [Reflections on Trusting Trust][rott].

[rott]: http://cm.bell-labs.com/who/ken/trust.html

<!-- TODO: Tutorial on Rotten, the language. -->
<!-- TODO: Tutorial on demonstrating the RoTT bug with Rotten -->
<!-- TODO: Section about the VM being based on the CAM? -->
<!-- TODO: Guide to where to start reading the files? -->

## How it works, in brief

1. Rotten compiles to a simple abstract machine ("the VM").
2. The VM is implemented in [Racket](http://www.racket-lang.org/).
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

## Getting Started

    # first line assumes Ubuntu or Debian; adjust as necessary for your distro
    ~$ sudo apt-get install git racket
    ~$ git clone https://github.com/rntz/rotten.git
    ~$ cd rotten
    ~/rotten$ racket repl.rkt
    VM rebooting
    VM loading compile.rotc
    VM loading {read,write}-file extensions
    ROTTEN>

Now we're at the Rotten repl!

## A quick and dirty guide to Rotten

    ;; Comments start with semicolons.
    ROTTEN> (+ 2 2)
    4
    ;; `def' defines global variables.
    ROTTEN> (def x 0)
    0
    ROTTEN> x
    0
    ;; `def' also defines functions, Scheme-style.
    ROTTEN> (def (double x) (+ x x))
    #(struct:closure 1 #f ((get-global +) (access 0) (access 0) (call 2)) ())
    ;; The above is just the printed representation of a compiled function;
    ;; you can safely ignore it.
    ROTTEN> (double 17)
    34
    ;; You can define variadic functions with dotted parameter lists:
    ROTTEN> (def (list . xs) xs)
    #(struct:closure 0 #t ((access 0)) ())
    ROTTEN> (list 1 2 3)
    (1 2 3)
    ;; cons, car, and cdr work as normal.
    ;; Conses are immutable; there is no set-car! or set-cdr!.
    ROTTEN> (cons 0 1)
    (0 . 1)
    ROTTEN> (car '(a b))
    a
    ;; The car and cdr of () are both ().
    ROTTEN> (cdr '())
    ()

Booleans and conditionals in Rotten are a little different from other Lisps:


    ;; Rotten uses () for false, everything else is true. 't is the conventional
    ;; true value. You need to quote 't, or you'll get an unbound variable
    ;; error.
    ROTTEN> (eq? 0 0)
    t
    ROTTEN> (eq? 0 1)
    ()
    ;; () and nil are distinct in Rotten; nil is just an ordinary symbol.
    ROTTEN> (if () 'yes 'no)
    no
    ROTTEN> (if 'nil 'yes 'no)
    yes
    ;; `if' can be used with three arguments, as in Scheme:
    ROTTEN> (if (eq? 0 1) 'yes 'no)
    no
    ;; or with two arguments, returning '() if the condition is false:
    ROTTEN> (if (eq? 0 1) 'yes)
    ()
    ;; or with N arguments, like a less-parenthesized 'cond:
    ROTTEN> (if (eq? 0 1) 'first
                (eq? 0 0) 'second)
    second
    ROTTEN> (if (eq? 0 1) 'first
                (eq? 0 2) 'second
                'otherwise)
    otherwise
    ROTTEN> (if (eq? 0 1) 'first
                (eq? 0 2) 'second)
    ()

Here are a few slightly larger examples:

    ;; A (non-tail-recursive) map function:
    (def (map f l)
      (if l
        (cons (f (car l))
              (map f (cdr l)))))

    ;; In Rotten it's hard to locally define recursive functions, so often we
    ;; use globally-defined helper functions. Here, rev-append is a helper for
    ;; rev.
    (def (rev l) (rev-append l ()))
    (def (rev-append l acc)
      (if x (rev-append (cdr x) (cons (car x) y))
          y))


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
