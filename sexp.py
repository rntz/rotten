# S-expressions are represented as follows:
#
# - Conses (a . b) are represented as Cons(a, b)
# - Nil () is represented by the Python empty-tuple ()
# - A symbol 'a is represented as Symbol("a")
# - Numbers are represented by Python ints
# - Strings are represented by Python strs

import re
from collections import namedtuple

class Cons(namedtuple('Cons', 'car cdr')):
    def __eq__(self, other):
        return isinstance(other, Cons) and super(Cons, self) == other

class Symbol(object):
    def __init__(self, name): self.name = name
    def __str__(self): return self.name
    def __eq__(self, other): return isinstance(other, Symbol) and self.name == other.name
    def __cmp__(self, other):
        assert isinstance(other, Symbol)
        return cmp(self.name, other.name)
    def __repr__(self): return 'Symbol(%r)' % self.name

# ---------- SEXP UTILITIES ----------
def is_sexp(x):                 # shallow test
    return (isinstance(x, (Cons, Symbol, str))
            # isinstance(True, int) == True, grumble grumble
            or (isinstance(x, int) and not isinstance(x, bool))
            or x == ())

# turns a Python sequence into a cons-list
def consify(lst):
    result = ()
    for e in reversed(lst):
        result = Cons(e, result)
    return result

# generates the elements of a cons-list
def iter_cons_list(conses):
    while conses != ():
        assert isinstance(conses, Cons)
        yield conses.car
        conses = conses.cdr

def write_sexp(file, exp):
    if isinstance(exp, Symbol):
        file.write(exp.name)
    elif isinstance(exp, int) or isinstance(exp, str):
        file.write(repr(exp))
    elif isinstance(exp, Cons) or exp == ():
        file.write('(')
        first = True
        while isinstance(exp, Cons):
            if not first:
                file.write(' ')
            write_sexp(file, exp.car)
            exp = exp.cdr
            first = False
        if exp != ():
            file.write('. ')
            write_sexp(file, exp)
        file.write(')')
    else:
        assert 0, "Not an s-expression: %s" % (exp,)

# ---------- PARSING ----------
class ParseError(Exception):
    def __init__(self, buf, message):
        self.buf = buf
        super(ParseError, self).__init__(message)

class EOF(ParseError): pass
class RParen(ParseError): pass

tok_re = re.compile(r"""
    \s+                             # whitespace
  | \( | \)                         # parentheses
  | [-a-zA-Z_!?+=<>/*@$%^&][-a-zA-Z0-9_!?+=<>/*@$%^&]*    # symbols
  | -?[0-9]+                        # numeric literals
  | "(?:[^"]|\\")*"                 # string literals
  | '                               # quote
""", re.VERBOSE)

def is_whitespace(tok): return re.match('\s', tok)
def is_lparen(tok): return tok == '('
def is_rparen(tok): return tok == ')'
def is_quote(tok): return tok == "'"
def is_symbol(tok): return bool(re.match('[-a-zA-Z_!?+=<>/*@$%^&]', tok))
def is_number(tok): return bool(re.match('-|[0-9]', tok))
def is_string(tok): return tok.startswith('"')

# S-expression parsing. I could depend on an external library but this is easier.
# returns (new_buf, exp)
def parse_exp(buf, cfg = None):
    while True:
        if not buf:
            raise EOF(buf, "end of input")

        m = tok_re.match(buf)
        if not m:
            raise ParseError(buf, "could not find a token")

        tok = m.group()
        buf = buf[len(tok):]

        if is_whitespace(tok):
            continue
        elif is_lparen(tok):
            buf, exps = parse_exps(buf)
            return buf, consify(exps)
        elif is_rparen(tok):
            raise RParen(buf, "unexpected right-paren")
        elif is_quote(tok):
            return buf, Symbol("quote")
        elif is_symbol(tok):
            return buf, Symbol(tok)
        elif is_number(tok):
            return buf, int(tok)
        elif is_string(tok):
            raise NotImplementedError("haven't implemented string literal parsing")

        assert False, "impossible! I'm sure I covered all cases!"
        assert 0
        print 'what'

# returns (new_buf, list-of-exps)
def parse_exps(buf):
    exps = []
    while True:
        try:
            buf, e = parse_exp(buf)
        except EOF as e:
            return e.buf, exps
        except RParen as e:
            return e.buf, exps
        exps.append(e)
