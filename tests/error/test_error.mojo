from libc.error import *


# @always_inline("nodebug")
# fn test_strerror_l():
#     print(strerror_l(0, UnsafePointer[NoneType]()))

fn main():
    print("starting to test...")
    _ = strerror(0)


# fn test_strerror():
#     print(strerror(0))


# @always_inline("nodebug")
# fn test_strerror_l():
#     print(strerror_l(0, UnsafePointer[NoneType]()))


# @always_inline("nodebug")
# fn test_strerror_r():
#     print(strerror_r(0, UnsafePointer[c_char].alloc(256), 256))


# @always_inline("nodebug")
# fn perror_test():
#     perror("Test")


# @always_inline("nodebug")
# fn strerrorname_np_test():
#     print(strerrorname_np(0))


# @always_inline("nodebug")
# fn strerrordesc_np_test():
#     print(strerrordesc_np(0))


# @always_inline("nodebug")
# fn error_test():
#     error(1, 2, "Test")


# @always_inline("nodebug")
# fn warn_test():
#     warn("Test")


# @always_inline("nodebug")
# fn warnx_test():
#     warnx("Test")


# @always_inline("nodebug")
# fn err_test():
#     err(1, "Test")


# @always_inline("nodebug")
# fn errx_test():
#     errx(1, "Test")


# fn main():
#     test_strerror()
#     test_strerror_l()
#     test_strerror_r()
#     perror_test()
#     strerrorname_np_test()
#     strerrordesc_np_test()
#     error_test()
#     warn_test()
#     warnx_test()
#     err_test()
#     errx_test()