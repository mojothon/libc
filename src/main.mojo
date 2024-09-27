from libc.memory import *
from libc import *

fn main():
    external_call["mallinfo2", NoneType]()