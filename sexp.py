# S-expressions are represented as follows:
#
# - Conses (a . b) are represented as Cons(a, b)
# - Nil () is represented by the Python empty-tuple ()
# - A symbol 'a is represented as Symbol("a")
# - Numbers are represented by Python ints
# - Strings are represented by Python strs

import re
from collections import namedtuple
import StringIO

class Cons(namedtuple('Cons', 'car cdr')):
    def __eq__(self, other):
        return isinstance(other, Cons) and super(Cons, self) == other

class Symbol(object):
    def __init__(self, name): self.name = name
    def __str__(self): return self.name
    def __eq__(self, other):
        return isinstance(other, Symbol) and self.name == other.name
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

def is_null(x):
    assert is_sexp(x)
    return x == ()

def is_true(x):
    assert is_sexp(x)
    return not is_null(x)

def truthify(x):
    """Takes Python truth values to Rotten truth values."""
    if x: return Symbol("t")
    else: return ()

def consify(lst):
    """Turns a Python sequence into a Rotten list."""
    result = ()
    for e in reversed(lst):
        result = Cons(e, result)
    return result

def cons_iter(conses):
    """Iterates over a Rotten list."""
    while conses != ():
        assert isinstance(conses, Cons)
        yield conses.car
        conses = conses.cdr

def write(f, exp):
    """Writes a Rotten value to a file-like object."""
    if isinstance(exp, Symbol):
        f.write(exp.name)
    elif isinstance(exp, Cons) or exp == ():
        f.write('(')
        first = True
        while isinstance(exp, Cons):
            if not first:
                f.write(' ')
            write(f, exp.car)
            exp = exp.cdr
            first = False
        if exp != ():
            f.write('. ')
            write(f, exp)
        f.write(')')
    else:
        f.write(repr(exp))

def to_str(exp):
    """Turns a Rotten value into a string containing its s-expression."""
    s = StringIO.StringIO()
    write(s, exp)
    return s.getvalue()

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

def is_whitespace(tok): return re.match(r'\s', tok)
def is_lparen(tok): return tok == '('
def is_rparen(tok): return tok == ')'
def is_quote(tok): return tok == "'"
def is_symbol(tok): return bool(re.match('[-a-zA-Z_!?+=<>/*@$%^&]', tok))
def is_number(tok): return bool(re.match('-|[0-9]', tok))
def is_string(tok): return tok.startswith('"')

# Tokenizing
def next_tok(buf):
    if not buf:
        raise EOF(buf, "end of input")

    m = tok_re.match(buf)
    if not m:
        raise ParseError(buf, "could not find a token")

    tok = m.group()
    return buf[len(tok):], tok

def expect_tok(buf, pred, msg):
    newbuf, tok = next_tok(buf)
    if not pred(tok):
        raise ParseError(buf, msg)
    return newbuf, tok

# S-expression parsing. I could depend on an external library but this is
# easier. Returns (new_buf, exp).
def parse_exp(buf):
    while True:
        pre_buf = buf           # useful for error reporting
        buf, tok = next_tok(buf)

        if is_whitespace(tok):
            continue
        elif is_lparen(tok):
            buf, exps = parse_exps(buf)
            buf, _ = expect_tok(buf, is_rparen, "expected a right-paren")
            return buf, consify(exps)
        elif is_rparen(tok):
            raise RParen(pre_buf, "unexpected right-paren")
        elif is_quote(tok):
            return buf, Symbol("quote")
        elif is_symbol(tok):
            return buf, Symbol(tok)
        elif is_number(tok):
            return buf, int(tok)
        elif is_string(tok):
            contents = tok[1:-1]
            if "\\" in contents:
                raise NotImplementedError("string escapes not implemented")
            assert not '"' in contents
            assert isinstance(contents, (str, unicode))
            return buf, contents

        assert False, "impossible! I'm sure I covered all cases!"

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
