# VM state

The VM has one piece of global state: the symbol table, which maps from global
variables to their values.

The VM has three piece of local state:
- `I`: The instruction list.
- `E`: The environment, an immutable array of closed-over values.
- `S`: The stack, which stores temporary values and continuations.

# Instructions

- `(push LIT)`: Pushes `LIT` onto `S`.

- `(pop)`: Pops one element from `S` and ignores it.

- `(access N)`: Pushes `E[N]` onto `S`.

- `(call N)`: Calls `S[N]` with `S[N-1..0]` as arguments.

- `(closure ARITY REST-PARAM INSTRS)`: Makes a closure and pushes it onto `S`.

- `(if THEN-INSTRS ELSE-INSTRS)`: Pops `S`. If result is true, proceeds to
  `THEN-INSTRS`; otherwise, proceeds to `ELSE-INSTRS`. Before proceeding, pushes
  a continuation.

- `(get-global NAME)`: Pushes the value of the global variable `NAME` onto
  `D`.

- `(set-global NAME)`: Sets the global variable `NAME` to S[0]. Does not pop
  `S`; its "return value" is what it has set `NAME` to.

# Builtins

Builtin functions are implemented using a cheap trick. There are no special
instructions for them. Rather, all of them except 'apply are just functions in
the VM's host language. When a host function is "call"-ed in the VM, the VM just
calls it in the host language.

The 'apply builtin is different. The global variable 'apply is bound to a
implementation-defined value which the VM handles specially. (TODO: Explain why
this needs to be special-cased to avoid recursively entering VM.)

# Functions

Functions/closures are structures with four fields:

- `arity`: number of parameters (excluding rest parameter)
- `has-rest-param`: whether it has a rest parameter or not
- `env`: list representing closed-over environment
- `code`: the VM instruction list for the function's body

# Continuations

We use a structure called a continuation to remember what to do after finishing
a function or finishing one branch of an `if` instruction. A continuation has
two fields:

- `instrs`: The instruction-stream (`I`) to return to.
- `env`: The environment (`E`) to restore.

The `env` field is only needed when returning from a function, not when
finishing an `if` instruction, but it is simpler to have only one form of a
continuation.

# Environments

Our environment records our closed-over variables. Variables are accessed by
index, so variable names are not needed in the VM. These indices correspond
roughly to DeBruijn indices. TODO: Explain DeBruijn indices.

However, there is the question of what order indices are assigned in a function
of multiple arguments:

    (fn (x y) (list x y))

In `(list x y)`, what indices do x and y have?

Currently, I give `x` index 0 and `y` index 1. This is the opposite of what a
traditional "currying" implementation of multiple-argument functions would do. I
actually wrote the VM this way by accident; I may change it later.

For clarity, here is an example:

    (fn (a b) ((fn (x y) (list a b x y)) a b))

If we replace variables by their indices, this corresponds to:

    (fn (_ _) ((fn (_ _) (list 2 3 0 1)) 0 1))
