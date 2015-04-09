from collections import namedtuple
import sys
import types
import StringIO

import sexp
from sexp import Symbol, Cons

def is_null(x):
    assert sexp.is_sexp(x)
    return x == ()

def is_true(x):
    assert sexp.is_sexp(x)
    assert not isinstance(x, bool)
    return not is_null(x)

def truthify(x):
    if x: return Symbol("t")
    else: return ()

# whether x is a callable python object
def is_callable(x):
    return isinstance(x, types.FunctionType) or hasattr(x, '__call__')

def sexp_str(v):
    if not sexp.is_sexp(v):
        return str(v)
    s = StringIO.StringIO()
    sexp.write_sexp(s, v)
    return s.getvalue()

class Cont(namedtuple('Cont', 'instrs env')):
    def __str__(self):
        return 'Cont(%s, %s)' % (sexp_str(self.instrs),
                                 ' '.join(sexp_str(x) for x in self.env))

class Closure(namedtuple('Closure', 'arity has_rest_param code env')):
    def __str__(self):
        if hasattr(self, '_name'):
            return '<Closure %s>' % (self._name,)
        else:
            return '<Closure>'

class ApplyBuiltin(object): pass
applyBuiltin = object()   # singleton

def car(x):
    assert isinstance(x, Cons), "Not a cons: %s" % (x,)
    return x.car

def cdr(x):
    assert isinstance(x, Cons), "Not a cons: %s" % (x,)
    return x.cdr

def is_symbol(x): return truthify(isinstance(x, Symbol))
def is_cons(x): return truthify(isinstance(x, Cons))
def is_atom(x): return truthify(not isinstance(x, Cons))
# FIXME: is is_eq correct? unit test this!
def is_eq(x,y): return truthify(x == y)
def add(x,y): return x + y
def sub(x,y): return x - y

def make_globals():
    return {"apply": applyBuiltin,
            "cons": Cons,
            "car": car,
            "cdr": cdr,
            "symbol?": is_symbol,
            "cons?": is_cons,
            "atom?": is_atom,
            "eq?": is_eq,
            "+": add,
            "-": sub}

class VMError(Exception): pass

class VM(object):
    def __init__(self):
        self.globals = make_globals()

    def set_global(self, sym, value):
        assert isinstance(sym, Symbol)
        self.globals[sym.name] = value
        if isinstance(value, Closure):
            # hint to make debugging easier
            value._name = sym.name

    def get_global(self, sym):
        assert isinstance(sym, Symbol)
        # print 'getting global %s' % sym.name
        # print 'value: %s' % (self.globals[sym.name],)
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

    # internal convenience methods, no abstraction here
    def push(self, x):
        # print 'push: %s' % (x,)
        self.data.append(x)

    def pop(self): return self.data.pop()

    def push_cont(self):
        if not self.instrs:
            print 'omitting no-op continuation'
            return
        self.push(Cont(self.instrs, self.env))

    # we're done if we have no instructions left and <= 1 value on the stack.
    def is_done(self):
        return bool(self.instrs == () and len(self.data) <= 1)

    def run(self):
        while not self.is_done():
            # print 'INSTRS:', sexp_str(self.instrs)
            # print '  DATA:', ' '.join(sexp_str(x) for x in reversed(self.data))
            # print '   ENV:', ' '.join(sexp_str(x) for x in self.env)
            self.step()
            # print

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
        if not isinstance(instr, Cons):
            raise VMError("instruction is not a cons: %s" % (instr,))
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
            del self.data[-n:]  # in-place removal of elements
            func = self.pop()
            self.call(func, func_args)
        elif tp == 'if':
            then_instrs, else_instrs = args
            instrs = then_instrs if is_true(self.pop()) else else_instrs
            # NB. the continuations for if-branches don't really need an `env'
            # value, since env won't be changed. But it's simpler to do this
            # than to create a new type of continuation.
            self.push_cont()
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
        # print "CALLING: %s(%s)" % (func, ', '.join(sexp_str(x) for x in args))
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
        env = []
        if not func.has_rest_param:
            env.extend(args)
        else:
            env.extend(args[:func.arity])
            env.append(sexp.consify(args[func.arity:]))
        env.extend(func.env)

        # Jump into function
        self.push_cont()
        self.instrs = func.code
        self.env = env
