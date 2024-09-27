
from libc.memory.debug import *
from libc import *


@always_inline("nodebug")
fn test_mtrace():
    mtrace()

@always_inline("nodebug")
fn test_muntrace():
    muntrace()

fn main():
    test_mtrace()
    test_muntrace()
