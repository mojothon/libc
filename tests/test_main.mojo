"""Test runner for the `libc` package.

Run every suite with:

    mojo run -I src -I tests tests/test_main.mojo

or simply `pixi run test`.
"""
from test_complex import main as run_complex
from test_import_all import main as run_import_all
from test_constant import main as run_constant
from test_ctype import main as run_ctype
from test_dirent import main as run_dirent
from test_fcntl import main as run_fcntl
from test_file import main as run_file
from test_mman import main as run_mman
from test_dlfcn import main as run_dlfcn
from test_sched import main as run_sched
from test_pthread import main as run_pthread
from test_epoll import main as run_epoll
from test_socket import main as run_socket
from test_signal import main as run_signal
from test_random import main as run_random
from test_setjmp import main as run_setjmp
from test_wait import main as run_wait
from test_auxv import main as run_auxv
from test_statvfs import main as run_statvfs
from test_logging import main as run_logging
from test_sendfile import main as run_sendfile
from test_errno import main as run_errno
from test_fenv import main as run_fenv
from test_float import main as run_float
from test_fnmatch import main as run_fnmatch
from test_glob import main as run_glob
from test_getopt import main as run_getopt
from test_grp import main as run_grp
from test_termios import main as run_termios
from test_iconv import main as run_iconv
from test_ifaddrs import main as run_ifaddrs
from test_inttypes import main as run_inttypes
from test_langinfo import main as run_langinfo
from test_layout import main as run_layout
from test_libgen import main as run_libgen
from test_locale import main as run_locale
from test_math import main as run_math
from test_netdb import main as run_netdb
from test_netif import main as run_netif
from test_network import main as run_network
from test_poll import main as run_poll
from test_pwd import main as run_pwd
from test_regex import main as run_regex
from test_resource import main as run_resource
from test_search import main as run_search
from test_stdio import main as run_stdio
from test_spawn import main as run_spawn
from test_stat import main as run_stat
from test_sys import main as run_sys
from test_stdlib import main as run_stdlib
from test_string import main as run_string
from test_time import main as run_time
from test_unistd import main as run_unistd
from test_utils import main as run_utils
from test_wchar import main as run_wchar
from test_version import main as run_version


def main() raises:
    run_complex()
    run_import_all()
    run_constant()
    run_ctype()
    run_dirent()
    run_fcntl()
    run_file()
    run_mman()
    run_dlfcn()
    run_sched()
    run_pthread()
    run_epoll()
    run_socket()
    run_signal()
    run_random()
    run_setjmp()
    run_wait()
    run_auxv()
    run_statvfs()
    run_logging()
    run_sendfile()
    run_errno()
    run_fenv()
    run_float()
    run_fnmatch()
    run_glob()
    run_getopt()
    run_grp()
    run_termios()
    run_iconv()
    run_ifaddrs()
    run_inttypes()
    run_langinfo()
    run_layout()
    run_libgen()
    run_locale()
    run_math()
    run_netdb()
    run_netif()
    run_network()
    run_poll()
    run_pwd()
    run_regex()
    run_resource()
    run_search()
    run_stdio()
    run_spawn()
    run_stat()
    run_sys()
    run_stdlib()
    run_string()
    run_time()
    run_unistd()
    run_utils()
    run_wchar()
    run_version()
    print("all tests passed")
