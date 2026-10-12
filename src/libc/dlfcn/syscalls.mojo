# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from libc.constant import c_ptr


#  void *handle = handle: c_ptr[Int8]
# Here have some errors.
# 后续补充
def dlclose(handle: c_ptr[Int8]) -> Int32:
    return external_call["dlclose", Int32, c_ptr[Int8]](handle)


def dlerror(handle: c_ptr[Int8]) -> Int32:
    return external_call["dlerror", Int32, c_ptr[Int8]](handle)


def dlopen(handle: c_ptr[Int8]) -> Int32:
    return external_call["dlopen", Int32, c_ptr[Int8]](handle)


def dlsym(handle: c_ptr[Int8]) -> Int32:
    return external_call["dlsym", Int32, c_ptr[Int8]](handle)
