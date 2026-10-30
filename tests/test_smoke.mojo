"""The least a caller can ask of the package, so that a built one can
be checked without asking anything of the terminal.

This says nothing at all, and that is the whole of the point. The
package binds `write`, and so does the standard library — twice, with
two different signatures between them. Any programme that writes to
the terminal reaches both, and where it does, the compiler objects to
there being two and throws one of them out. A check of the built
package that printed its findings could not get as far as printing
them.

So this one asserts instead of printing, and asks the least
interesting thing there is to ask, which is enough to know the package
was found, loaded and called.
"""

from libc.ctype import isdigit


def main() raises:
    var a_digit = isdigit(53)  # '5'
    if a_digit == 0:
        raise Error("isdigit says 5 is not a digit")

    var not_a_digit = isdigit(65)  # 'A'
    if not_a_digit != 0:
        raise Error("isdigit says A is a digit")
