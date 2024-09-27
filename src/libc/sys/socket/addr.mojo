from utils.static_tuple import StaticTuple
from memory import UnsafePointer
from libc.constant import *


@value
@register_passable("trivial")
struct in_addr:
    var s_addr: in_addr_t


@value
@register_passable("trivial")
struct in6_addr:
    var s6_addr: StaticTuple[c_char, 16]


@value
@register_passable("trivial")
struct socketaddr:
    var sa_family: sa_family_t
    var sa_data: StaticTuple[c_char, 14]


@value
@register_passable("trivial")
struct socketaddr_in:
    var sin_family: sa_family_t
    var sin_port: in_port_t
    var sin_addr: in_addr
    var sin_zero: StaticTuple[c_char, 8]


@value
@register_passable("trivial")
struct socketaddr_in6:
    var sin6_family: sa_family_t
    var sin6_port: in_port_t
    var sin6_flowinfo: c_uint
    var sin6_addr: in6_addr
    var sin6_scope_id: c_uint


@value
@register_passable("trivial")
struct addrinfo:
    var ai_flags: c_int
    var ai_family: c_int 
    var ai_sockettype: c_int
    var ai_protocol: c_int 
    var ai_addrlen: socklen_t
    var ai_canonname: UnsafePointer[c_char]
    var ai_addr: UnsafePointer[socketaddr]
    var ai_next: UnsafePointer[addrinfo]

    fn __init__(
        inout self,
        ai_flags: c_int = 0,
        ai_family: c_int = 0,
        ai_sockettype: c_int = 0,
        ai_protocol: c_int = 0,
        ai_addrlen: socklen_t = 0,
        ai_canonname:  UnsafePointer[c_char] = UnsafePointer[c_char](),
        ai_addr: UnsafePointer[socketaddr] = UnsafePointer[socketaddr](),
        ai_next: UnsafePointer[addrinfo] = UnsafePointer[addrinfo](),
    ):
        self.ai_flags = ai_flags
        self.ai_family = ai_family
        self.ai_sockettype = ai_sockettype
        self.ai_protocol = ai_protocol
        self.ai_addrlen = ai_addrlen
        self.ai_canonname = ai_canonname
        self.ai_addr = ai_addr
        self.ai_next =ai_next

