# Rotten

Rotten is a small self-hosting Lisp, designed as a vehicle for exploring Ken
Thompson's [Reflections on Trusting Trust][rott].

[rott]: http://cm.bell-labs.com/who/ken/trust.html

<!-- TODO: Tutorial on demonstrating the RoTT bug with Rotten -->
<!-- TODO: Tutorial on Rotten, the language. -->
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
| compile.rot  | ~  80 | compiler                  |
| vm.rkt       | ~ 130 | VM interpreter            |
| driver.rkt   | ~  90 | repl & other conveniences |
| **TOTAL:**   | < 300 |                           |

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

## File manifest

| File             | Purpose                                                  |
| ---------------- | -------------------------------------------------------- |
| compile.rot      | Compiler from Rotten to VM-code.                         |
| evil.rot         | Malicious compiler that infects compile.rot with a RoTT virus. |
| rotten.rot       | AST-walking metacircular Rotten interpreter (in Rotten). |
| vm.rkt           | VM interpreter.                                          |
| rotten.rkt       | AST-walking Rotten interpreter (in Racket).              |
| driver.rkt       | Rotten REPL & other conveniences.                        |
| quines.rkt       | Demonstration of various quining techniques.             |
| compile.rotc     | Pre-compiled image of compile.rot, used for bootstrapping VM. |
| infected.rotc    | RoTT-infected version of compile.rotc.                        |
| README.md        | The file you're currently reading.                       |
| design.org       | Notes to myself about the design of Rotten.              |
| presentation.org | Notes to myself for presenting a demo of Rotten.         |

## Caveat emptor
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
