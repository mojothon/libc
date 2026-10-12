from std.testing import assert_equal

from libc.network import htonl, htons, ntohl, ntohs


def test_htonl() raises:
    assert_equal(htonl(0x12345678), 0x78563412)


def test_htons() raises:
    assert_equal(htons(0x1234), 0x3412)


def test_ntohl() raises:
    assert_equal(ntohl(0x78563412), 0x12345678)


def test_ntohs() raises:
    assert_equal(ntohs(0x3412), 0x1234)


def main() raises:
    test_htonl()
    test_htons()
    test_ntohl()
    test_ntohs()
    print("test_network: ok")
