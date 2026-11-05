# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <threads.h>, which is not written yet.
#
# The reason it was not is gone. `thrd_create` takes a function pointer,
# and for a long time this package could not hand C one; it can now, and
# `libc.pthread` has the three calls that make a second thread and wait
# for it. What is left is the twenty-two functions that only make sense
# once a thread exists -- a mutex, a condition variable, a thread-local
# slot, a call to yield -- each of which is a wrapper over a `pthread`
# call this package already exports.
#
# The note in `docs/modules.md` is the one that has to be kept true.
