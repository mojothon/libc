"""Test runner for the `libc` package.

Run every suite with:

    mojo run -I src -I tests tests/test_main.mojo

or simply `pixi run test`.
"""
from test_complex import main as run_complex
from test_constant import main as run_constant
from test_ctype import main as run_ctype
from test_dirent import main as run_dirent
from test_float import main as run_float
from test_math import main as run_math
from test_network import main as run_network
from test_stdio import main as run_stdio
from test_stdlib import main as run_stdlib
from test_string import main as run_string
from test_time import main as run_time
from test_utils import main as run_utils
from test_wchar import main as run_wchar
from test_version import main as run_version


def main() raises:
    run_complex()
    run_constant()
    run_ctype()
    run_dirent()
    run_float()
    run_math()
    run_network()
    run_stdio()
    run_stdlib()
    run_string()
    run_time()
    run_utils()
    run_wchar()
    run_version()
    print("all tests passed")
