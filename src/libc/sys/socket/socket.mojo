# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call
from libc.utils import string_to_char_ptr
from .addr import socketaddr, addrinfo


fn inet_ntop(
    af: c_int, src: UnsafePointer[c_void], dst: UnsafePointer[c_char], size: socklen_t
) -> UnsafePointer[c_char]:
    """Libc POSIX `inet_ntop` function.

    Reference: https://man7.org/linux/man-pages/man3/inet_ntop.3p.html.
    Fn signature: const char *inet_ntop(int af, const void *restrict src, char *restrict dst, socklen_t size)

    Args:
        af: Address Family see AF_ alises.
        src: A pointer to a binary address.
        dst: A pointer to a buffer to store the string representation of the address.
        size: The size of the buffer pointed by dst.

    Returns: A pointer.
    """
    return external_call[
        "inet_ntop",
        UnsafePointer[c_char],  # FnName, RetType
        c_int,
        UnsafePointer[c_void],
        UnsafePointer[c_char],
        socklen_t,  # Args
    ](af, src, dst, size)


fn inet_addr(cp: UnsafePointer[c_char]) -> in_addr_t:
    """Libc POSIX `inet_addr` function.

    Reference: https://man7.org/linux/man-pages/man3/inet_addr.3p.html
    Fn signature: in_addr_t inet_addr(const char *cp)

    Args:
        cp: A pointer to a string representation of an address.
    Returns: A pointer.
    """
    return external_call["inet_addr", in_addr_t, UnsafePointer[c_char]](cp)


fn inet_ntoa(addr: in_addr) -> UnsafePointer[c_char]:
    """Libc POSIX `inet_ntoa` function.

    Reference: https://man7.org/linux/man-pages/man3/inet_addr.3p.html
    Fn signature: char *inet_ntoa(struct in_addr in)

    Args: in: A pointer to a binary address.
    Returns: A pointer.
    """
    return external_call["inet_ntoa", UnsafePointer[c_char], in_addr](addr)


fn inet_pton(
    af: c_int, src: UnsafePointer[c_char], dst: UnsafePointer[c_void]
) -> c_int:
    """Libc POSIX `inet_pton` function.

    Args:
        af: Address Family see AF_ alises.
        src: A pointer to a string representation of an address.
        dst: A pointer to a buffer to store the binary address.

    Returns:
        A pointer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_ntop.3p.html).
        Fn signature: `int inet_pton(int af, const char *restrict src,
            void *restrict dst)`.
    """
    return external_call[
        "inet_pton", c_int, c_int, UnsafePointer[c_char], UnsafePointer[c_void]
    ](af, src, dst)






fn setsockopt(
    socket: c_int,
    level: c_int,
    option_name: c_int,
    option_value: UnsafePointer[c_void],
    option_len: socklen_t,
) -> c_int:
    """Libc POSIX `setsockopt` function.

    Reference: https://man7.org/linux/man-pages/man3/setsockopt.3p.html
    Fn signature: int setsockopt(int socket, int level, int option_name, const void *option_value, socklen_t option_len)

    Args:
        socket: A pointer to a socket.
        level: Protocol Level see SOL_ alises.
        option_name: Option name see SO_ alises.
        option_value: A pointer to a buffer containing the option value.
        option_len: The size of the buffer pointed by option_value.
    Returns: A pointer to a socket opt.
    """
    return external_call[
        "setsockopt",
        c_int,  # FnName, RetType
        c_int,
        c_int,
        c_int,
        UnsafePointer[c_void],
        socklen_t,  # Args
    ](socket, level, option_name, option_value, option_len)




fn listen(socket: c_int, backlog: c_int) -> c_int:
    """Libc POSIX `listen` function.

    Reference: https://man7.org/linux/man-pages/man3/listen.3p.html
    Fn signature: int listen(int socket, int backlog)

    Args:
        socket: A pointer to a socket.
        backlog: The maximum length to which the queue of pending connections for socket may grow.
    Returns: A pointer to a socket.
    """
    return external_call["listen", c_int, c_int, c_int](socket, backlog)


fn accept(
    socket: c_int, address: UnsafePointer[socketaddr], address_len: UnsafePointer[socklen_t]
) -> c_int:
    """Libc POSIX `accept` function.

    Reference: https://man7.org/linux/man-pages/man3/accept.3p.html
    Fn signature: int accept(int socket, struct sockaddr *restrict address, socklen_t *restrict address_len);

    Args:
        socket: A pointer to a socket.
        address: A pointer to a buffer to store the address of the accepted socket.
        address_len: A pointer to a buffer to store the length of the address of the accepted socket.
    Returns: A pointer to a socket.
    """
    return external_call[
        "accept",
        c_int,  # FnName, RetType
        c_int,
        UnsafePointer[socketaddr],
        UnsafePointer[socklen_t],  # Args
    ](socket, address, address_len)


fn connect(socket: c_int, address: UnsafePointer[socketaddr], address_len: socklen_t) -> c_int:
    """Libc POSIX `connect` function.

    Reference: https://man7.org/linux/man-pages/man3/connect.3p.html
    Fn signature: int connect(int socket, const struct sockaddr *address, socklen_t address_len)

    Args:
        socket: A pointer to a socket.
        address: A pointer to a buffer to store the address of the accepted socket.
        address_len: A pointer to a buffer to store the length of the address of the accepted socket.
    Returns: A pointer to a socket.
    """
    return external_call[
        "connect", c_int, c_int, UnsafePointer[socketaddr], socklen_t  # FnName, RetType  # Args
    ](socket, address, address_len)




fn shutdown(socket: c_int, how: c_int) -> c_int:
    """Libc POSIX `shutdown` function.

    Reference: https://man7.org/linux/man-pages/man3/shutdown.3p.html
    Fn signature: int shutdown(int socket, int how)

    Args:
        socket: A pointer to a socket.
        how: A pointer to a buffer to store the length of the address of the accepted socket.
    Returns: A pointer to a socket.
    """
    return external_call["shutdown", c_int, c_int, c_int](  # FnName, RetType  # Args
        socket, how
    )


fn getaddrinfo(
    nodename: UnsafePointer[c_char],
    servname: UnsafePointer[c_char],
    hints: UnsafePointer[addrinfo],
    res: UnsafePointer[UnsafePointer[addrinfo]],
) -> c_int:
    """Libc POSIX `getaddrinfo` function.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getaddrinfo.3p.html).
        Fn signature: `int getaddrinfo(const char *restrict nodename,
            const char *restrict servname, const struct addrinfo *restrict hints
            , struct addrinfo **restrict res)`.
    """
    return external_call[
        "getaddrinfo",
        c_int,
        UnsafePointer[c_char],
        UnsafePointer[c_char],
        UnsafePointer[addrinfo],
        UnsafePointer[UnsafePointer[addrinfo]],
    ](nodename, servname, hints, res)


fn gai_strerror(ecode: c_int) -> UnsafePointer[c_char]:
    """Libc POSIX `gai_strerror` function.

    Reference: https://man7.org/linux/man-pages/man3/gai_strerror.3p.html
    Fn signature: const char *gai_strerror(int ecode)

    Args:
        ecode: A pointer to a socket.
    Returns: A pointer to a socket.
    """
    return external_call[
        "gai_strerror", UnsafePointer[c_char], c_int  # FnName, RetType  # Args
    ](ecode)

