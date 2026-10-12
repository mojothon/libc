"""Test runner for the `libc` package.

Run every suite with:

    mojo run -I src -I tests tests/test_main.mojo

or simply `pixi run test`.
"""
from test_constant import main as run_constant
from test_ctype import main as run_ctype
from test_dirent import main as run_dirent
from test_math import main as run_math
from test_network import main as run_network
from test_string import main as run_string
from test_utils import main as run_utils
from test_version import main as run_version


def main() raises:
    run_constant()
    run_ctype()
    run_dirent()
    run_math()
    run_network()
    run_string()
    run_utils()
    run_version()
    print("all tests passed")
