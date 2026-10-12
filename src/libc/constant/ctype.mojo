# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C type aliases
# x86_64
from std.memory import Pointer


# Raw, untracked mutable pointer: the Mojo 1.x replacement for the removed
# `UnsafePointer[T]` spelling. Every C binding in this package takes one of
# these, so the origin is pinned in a single place.
comptime c_ptr[T: AnyType] = Pointer[T, MutUntrackedOrigin]

comptime c_void = UInt8
comptime c_char = UInt8
comptime c_schar = Int8
comptime c_uchar = UInt8
comptime c_short = Int16
comptime c_ushort = UInt16
comptime c_int = Int32
comptime c_uint = UInt32
comptime c_long = Int64
comptime c_ulong = UInt64
comptime c_longlong = Int64
comptime c_ulonglong = UInt64
comptime c_float = Float32
comptime c_double = Float64
comptime c_size_t = UInt64
comptime c_ssize_t = Int

comptime intmax_t = Int64
comptime uintmax_t = UInt64

# `wchar_t` is a 4 byte int on both Linux and Darwin, and `wint_t` follows it.
comptime c_wchar = Int32
comptime c_wint = Int32

comptime size_t = Int
comptime ptrdiff_t = Int64
comptime intptr_t = Int64
comptime uintptr_t = UInt64
comptime ssize_t = UInt64


comptime INT_MIN: c_int = -2147483648
comptime INT_MAX: c_int = 2147483647
