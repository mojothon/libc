"""Test runner for the `libc` package.

Run every suite with:

    mojo run -I src -I tests tests/test_main.mojo

or simply `pixi run test`.
"""
from test_complex import main as run_complex
from test_constant import main as run_constant
from test_ctype import main as run_ctype
from test_dirent import main as run_dirent
from test_fcntl import main as run_fcntl
from test_errno import main as run_errno
from test_fenv import main as run_fenv
from test_float import main as run_float
from test_inttypes import main as run_inttypes
from test_layout import main as run_layout
from test_locale import main as run_locale
from test_math import main as run_math
from test_network import main as run_network
from test_poll import main as run_poll
from test_pwd import main as run_pwd
from test_resource import main as run_resource
from test_search import main as run_search
from test_signal import main as run_signal
from test_stdio import main as run_stdio
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
    run_constant()
    run_ctype()
    run_dirent()
    run_fcntl()
    run_errno()
    run_fenv()
    run_float()
    run_inttypes()
    run_layout()
    run_locale()
    run_math()
    run_network()
    run_poll()
    run_pwd()
    run_resource()
    run_search()
    run_signal()
    run_stdio()
    run_sys()
    run_stdlib()
    run_string()
    run_time()
    run_unistd()
    run_utils()
    run_wchar()
    run_version()
    print("all tests passed")
