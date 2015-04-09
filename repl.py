#!/usr/bin/env python
import sexp
from sexp import Symbol
import vm

def read_all(file):
    string = file.read()
    buf, exps = sexp.parse_exps(buffer(string))
    assert not buf              # should have read to EOF
    return exps

def read_file(filename):
    with open(filename) as f:
        return sexp.consify(read_all(f))

# exps is a cons-list of expressions
def write_file(filename, exps):
    with open(filename, 'w') as f:
        for e in sexp.iter_cons_list(exps):
            sexp.write_sexp(f, e)
            f.write('\n')

def vm_boot(filename = "compile.rotc"):
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
    instrs = sexp.consify([sexp.consify([Symbol("get-global"), Symbol(funcname)])]
                          + [sexp.consify([Symbol("push"), x]) for x in args]
                          + [sexp.consify([Symbol("call"), len(args)])])
    print list(sexp.iter_cons_list(instrs))
    vmstate.run_expr(instrs)

def vm_compile_expr(vmstate, expr):
    vm_call(vmstate, "compile-exp", expr)

def vm_eval(vmstate, expr):
    c = vm_compile_expr(vmstate, expr)
    print '---------- COMPILED ----------'
    print 'result: %s' % s
    return vmstate.run_expr(c)

class EOF(Exception): pass

def read_sexp():
    string = ''
    while True:
        # FIXME: need to test for actual EOF!
        line = sys.stdin.readline()
        if not line:
            raise EOF("end of file")
        string += line
        try:
            buf, e = sexp.parse_exp(string)
        except sexp.EOF:
            continue
        assert not buf.strip()  # should be at EOF modulo whitespace
        # FIXME: it might not be! could parse multiple sexps on same line!
        # for now, don't support this
        return e

def repl(vmstate):
    while True:
        print 'pyROTTEN> ',

        # grab an expression
        try:
            exp = read_sexp()
        except EOF:
            break
        if exp == sexp.consify([Symbol("unquote"), Symbol("quit")]):
            break

        print 'exp:', exp

        # run it
        try:
            val = vm_eval(vmstate, exp)
        except vm.VMError as e:
            print >>sys.stderr, e
        else:
            write_sexp(sys.stdout, val)
            print

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        vmstate = vm_boot(sys.argv[1])
    else:
        vmstate = vm_boot()
    repl(vmstate)
