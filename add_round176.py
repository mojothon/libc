#!/usr/bin/env python3
"""Add siggetmask (signal) + sethostid (unistd) bindings and tests. Run once."""

def finish(sig_s, unistd_s):
    open("src/libc/signal/syscalls.mojo", "wb").write(sig_s)
    open("src/libc/unistd/syscalls.mojo", "wb").write(unistd_s)
    print("bindings written")

# ---- siggetmask binding ----
p = "src/libc/signal/syscalls.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"
if b"def siggetmask" not in s:
    i = s.find(b"def sigset(")
    assert i > 0
    # insert after sigset's return
    ret = s.find(b'    ](sig, disp)' + eol, i)
    assert ret > 0
    end = ret + len(b'    ](sig, disp)' + eol)
    add = (eol + eol +
           b'def siggetmask() -> Int32:' + eol +
           b'    """Libc Linux `siggetmask` function (obsolete).' + eol +
           b'' + eol +
           b'        int siggetmask(void)' + eol +
           b'' + eol +
           b'    Reference:' + eol +
           b'        https://man7.org/linux/man-pages/man3/sigblock.3.html' + eol +
           b'' + eol +
           b'    Description:' + eol +
           b'        What stands between the asking and the' + eol +
           b'        saying, as a word: the blocked set said in' + eol +
           b'        the one machine word `sigblock` and' + eol +
           b'        `sigsetmask` trade in, with one bit for' + eol +
           b'        each signal. The word is the same the two' + eol +
           b'        old sayings answer with, and what `sigprocmask`' + eol +
           b'        says of the same set, said small.' + eol +
           b'        `sigprocmask` is what to say now; this is' + eol +
           b'        the word the old sayings keep saying.' + eol +
           b'' + eol +
       b'    Returns:' + eol +
           b'        The blocked set, as the one word it is.' + eol +
           b'    """' + eol +
           b'    return external_call["siggetmask", Int32]()' + eol)
    s = s[:end] + add + s[end:]
    print("siggetmask binding staged")

# ---- sethostid binding ----
p = "src/libc/unistd/syscalls.mojo"
u = open(p, "rb").read()
if b"def sethostid" not in u:
    anchor = u.find(b"def get_current_dir_name()")
    assert anchor > 0
    add = (b'def sethostid(id: c_long) -> c_int:' + eol +
           b'    """Libc Linux `sethostid` function.' + eol +
           b'' + eol +
           b'        int sethostid(long id)' + eol +
           b'' + eol +
           b'    Reference:' + eol +
           b'        https://man7.org/linux/man-pages/man3/gethostid.3.html' + eol +
           b'' + eol +
           b'    Description:' + eol +
           b'        What the asking says it is, as a number,' + eol +
           b'        said again: the saying is written where the' + eol +
           b'        asking of it later reads, and who may say' + eol +
           b'        it is the tree\'s own keeping -- a caller' + eol +
           b'        without the say is refused with `errno`' + eol +
           b'        saying so. Said back where it was, the' + eol +
           b'        number is what it was either way. The word' + eol +
           b'        is Linux\'s own, and Darwin has no call' + eol +
           b'        that says it.' + eol +
           b'' + eol +
           b'    Args:' + eol +
           b'        id: The number the asking is said as.' + eol +
           b'' + eol +
           b'    Returns:' + eol +
           b'        0 on success, or -1 on error with `errno`' + eol +
           b'        set.' + eol +
           b'    """' + eol +
           b'    return external_call["sethostid", c_int, c_long](id)' + eol + eol)
    u = u[:anchor] + add + u[anchor:]
    print("sethostid binding staged")

finish(s, u)
