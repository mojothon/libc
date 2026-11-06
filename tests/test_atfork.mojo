"""The one question only a built package answers.

`pthread_atfork`'s name glibc exports with no default version, and the
just-in-time run every other test goes through looks the bare name up
and finds nothing -- `Symbols not found: [ pthread_atfork ]`, which is
why the suite's own answer says it cannot ask this one. A binary built
out of this source links it, which the answer beside the suite has
been claiming all along; this asks the question that claim was making,
and the recipe runs it exactly there -- compiled first, then run.

It says nothing when it passes, like the smoke test beside it, and for
the same reason: any `print` reaches the standard library's `write` as
well as the package's, and where both are reached the compiler throws
one of them out.

The handlers are no-ops and nothing here forks -- the registration
returning 0 is the whole of the question: the name resolved, and the
library took the handlers. Whether they fire is a forking test's to
ask, and the run that could ask it cannot start here.
"""

from libc.pthread import pthread_atfork


def note() -> None:
    pass


def main() raises:
    var registered = pthread_atfork(note, note, note)
    if registered != 0:
        raise Error("pthread_atfork did not take the registration")
