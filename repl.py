#!/usr/bin/env python
import sys

import sexp
from sexp import Symbol
import vm

def read_all(f):
    string = f.read()
    buf, exps = sexp.parse_exps(buffer(string))
    assert not buf              # should have read to EOF
    return exps

def read_file(filename):
    with open(filename) as f:
        return sexp.consify(read_all(f))

# exps is a cons-list of expressions
def write_file(filename, exps):
    with open(filename, 'w') as f:
        for e in sexp.cons_iter(exps):
            sexp.write(f, e)
            f.write('\n')

def vm_boot(filename="compile.rotc"):
    print "booting up VM"
    vmstate = vm.VM()
    print "VM loading %s" % filename
    vm_load(vmstate, filename)
    print "VM loading {read,write}-file extensions"
    vmstate.set_global(Symbol('read-file'), read_file)
    vmstate.set_global(Symbol('write-file'), write_file)
    return vmstate

def vm_load(vmstate, filename):
    vmstate.run_body(read_file(filename))

def vm_call(vmstate, funcname, *args):
    # perhaps I could use Thread.call somehow?
    # it wasn't meant to be an external method, but maybe it could become one
    instrs = sexp.consify(
        [sexp.consify([Symbol("get-global"), Symbol(funcname)])]
        + [sexp.consify([Symbol("push"), x]) for x in args]
        + [sexp.consify([Symbol("call"), len(args)])])
    return vmstate.run_expr(instrs)

def vm_compile_expr(vmstate, expr):
    return vm_call(vmstate, "compile-exp", expr)

def vm_eval(vmstate, expr):
    c = vm_compile_expr(vmstate, expr)
    return vmstate.run_expr(c)

class QuitRepl(Exception): pass

def read_sexps():
    # TODO: semicolons should start comments
    string = ''
    while True:
        line = sys.stdin.readline()
        if not line:
            raise QuitRepl("end of input")
        string += line
        try:
            buf, e = sexp.parse_exp(string)
        except sexp.EOF:
            # ran out of input before parsing a complete sexp, keep reading
            continue
        yield e
        # if there's nothing else left on the line but whitespace, we're done reading sexps
        if not buf.strip():
            break
        # copy the remainder of the string into a fresh string and keep reading
        string = str(buf)

def repl(vmstate):
    try:
        while True:
            sys.stdout.write('pyROTTEN> ')
            sys.stdout.flush()
            for exp in read_sexps():
                if exp == sexp.consify([Symbol("unquote"), Symbol("quit")]):
                    raise QuitRepl(",quit command")
                try:
                    val = vm_eval(vmstate, exp)
                except vm.VMError as e:
                    sys.stdout.flush()
                    print >>sys.stderr, e
                    sys.stderr.flush()
                else:
                    print sexp.to_str(val)
    except QuitRepl:
        pass

def main():
    if len(sys.argv) > 1:
        vmstate = vm_boot(sys.argv[1])
    else:
        vmstate = vm_boot()
    repl(vmstate)

if __name__ == '__main__':
    main()
