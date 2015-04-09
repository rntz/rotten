import sexp
from sexp import Symbol
import types

def is_null(x): return x == ()
def is_true(x): return not is_null(x)

# whether x is a callable python object
def is_callable(x):
    return isinstance(x, types.FunctionType) or hasattr(x, '__call__')

# TODO: maybe make these namedtuples?
class Closure(object):
    def __init__(self, arity, has_rest_param, code, env):
        self.arity = arity
        self.has_rest_param = has_rest_param
        self.code = code
        self.env = env

class Cont(object):
    def __init__(self, instrs, env):
        self.instrs = instrs
        self.env = env

class ApplyBuiltin(object): pass
applyBuiltin = object()   # singleton

def car(x):
    assert isinstance(x, tuple)
    return x[0]

def cdr(x):
    assert isinstance(x, tuple)
    return x[1]

def eq(x, y):
    return x == y

def make_globals():
    return {"apply": applyBuiltin,
            "cons": lambda x,y: (x,y),
            "car": car,
            "cdr": cdr,
            "symbol?": lambda x: isinstance(x, Symbol),
            "cons?": lambda x: isinstance(x, tuple),
            "atom?": lambda x: not isinstance(x, tuple),
            "eq?": eq,
            "+": lambda x,y: x + y,
            "-": lambda x,y: x - y}

class VMError(Exception): pass

class VM(object):
    def __init__(self):
        self.globals = make_globals()

    def set_global(self, sym, value):
        assert isinstance(sym, Symbol)
        self.globals[sym.name] = value

    def get_global(self, sym):
        assert isinstance(sym, Symbol)
        return self.globals[sym.name]

    def run_body(self, instrs, data=None, env=None):
        thread = Thread(self, instrs, data, env)
        thread.run()

    def run_expr(self, instrs, data=None, env=None):
        thread = Thread(self, instrs, data, env)
        thread.run()
        return thread.result()

class Thread(object):
    # instrs is a cons-list
    # data, env are Python lists
    # data is interpreted as a stack; its top elements are at the end
    def __init__(self, vm, instrs, data=None, env=None):
        self.vm = vm
        self.instrs = instrs
        self.data = data if data is not None else []
        self.env = env if env is not None else []

    def result(self):
        assert self.is_done()
        assert len(self.data) == 1
        return self.data[0]

    # pure internal convenience methods, no abstraction here
    def push(self, x): self.data.append(x)
    def pop(self): return self.data.pop()

    # we're done if we have no instructions left and <= 1 value on the stack.
    def is_done(self):
        return bool(self.instrs == () and len(self.data) <= 1)

    def run(self):
        while not self.is_done():
            print 'INSTRS:', self.instrs
            print '  DATA:', self.data
            print '   ENV:', self.env
            self.step()

    def step(self):
        assert not self.is_done()
        if not self.instrs:
            # pull value, continuation off stack and enter the continuation
            value = self.pop()
            cont = self.pop()
            self.instrs = cont.instrs
            self.env = cont.env
            self.data.append(value)
        else:
            # execute next instruction
            instr = car(self.instrs)
            self.instrs = cdr(self.instrs)
            self.step_instr(instr)

    # TODO: better errors
    def step_instr(self, instr):
        # an instruction is of the form (TYPE ARGS...), encoded as a cons-list
        # where TYPE is a symbol
        # first, we de-consify it
        tp = car(instr).name
        args = tuple(sexp.iter_cons_list(cdr(instr)))
        if tp == 'push':
            val, = args         # 1-argument tuple unpacking!
            self.push(val)
        elif tp == 'pop':
            [] = args           # 0-argument tuple unpacking!
            self.pop()
        elif tp == 'access':
            n, = args
            self.push(self.env[n])
        elif tp == 'closure':
            arity, has_rest_param, code = args
            # need to copy self.env because it is mutable
            env = list(self.env)
            closure = Closure(arity, is_true(has_rest_param), code, env)
            self.push(closure)
        elif tp == 'call':
            n, = args
            func_args = self.data[-n:]
            func_args.reverse()
            del self.data[-n:]  # in-place removal of elements
            func = self.pop()
            self.call(func, func_args)
        elif tp == 'if':
            then_instrs, else_instrs = args
            instrs = then_instrs if is_true(self.pop()) else else_instrs
            # NB. the continuations for if-branches don't really need an `env'
            # value, since env won't be changed. But it's simpler to do this
            # than to create a new type of continuation.
            self.push(Cont(self.instrs, self.env))
            self.instrs = instrs
        elif tp == 'get-global':
            sym, = args
            self.push(self.vm.get_global(sym))
        elif tp == 'set-global':
            sym, = args
            # no pop, just a peek
            self.vm.set_global(sym, self.data[-1])
        else:
            raise VMError("Unrecognized instruction type.")

    # args is a Python sequence
    def call(self, func, args):
        # apply must, alas, be special-cased
        while func is applyBuiltin:
            func = args[0]
            args = args[1:]

        if isinstance(func, Closure):
            self.call_closure(func, args)
        elif is_callable(func):
            self.push(func(*args))
        else:
            raise VMError("Cannot call non-function")

    # args is a Python sequence
    def call_closure(self, func, args):
        assert isinstance(func, Closure)

        if len(args) < func.arity:
            raise VMError("too few arguments to function")
        if not func.has_rest_param and len(args) > func.arity:
            raise VMError("too many arguments to function")

        # munge arguments into environment, taking into account rest-param
        env = func.env
        if not func.has_rest_param:
            env.extend(args)
        else:
            env.extend(args[:func.arity])
            env.append(args[func.arity:])

        # Jump into function
        self.push(Cont(self.instrs, self.env))
        self.instrs = func.code
        self.env = env
