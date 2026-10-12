from libc import __version__
from libc.utils import char_ptr_to_string, string_to_char_ptr, strlen


def main() raises:
    print("libc for Mojo", __version__)

    var ptr = string_to_char_ptr("hello, libc")
    print(strlen(ptr))
    print(char_ptr_to_string(ptr))
    ptr.unsafe_free()
