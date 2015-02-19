# Rotten

Rotten is a small self-hosting Lisp, designed as a vehicle for exploring Ken
Thompson's
[Reflections on Trusting Trust](http://cm.bell-labs.com/who/ken/trust.html).

## How it works

1. Rotten compiles to a simple abstract machine ("the VM").
2. The VM is implemented in [Racket](http://www.racket-lang.org/).
3. The compiler from Rotten to VM-code is
   [written in Rotten](http://en.wikipedia.org/wiki/Self-hosting).

## Rotten is really small!

    compile.rot     ~  80 LOC       implements compiler
    vm.rkt          ~ 130 LOC       implements VM
    driver.rkt      ~  90 LOC       implements repl & other conveniences
    TOTAL           < 300 LOC

There are other files in the repository but they're not really necessary.

# Caveat emptor
This project is an exercise in golfing. Therefore, everything in it is horribly,
horribly bad, including but not limited to:

- the language design
- the VM design
- the interpreter implementation
- the VM implementation

**Do not** take any of these as an example of how to do it. If you'd like
pointers on slightly more reasonable ways to design and implement a lisp, feel
free to [email me](mailto:daekharel@gmail.com), although I am not an expert.
