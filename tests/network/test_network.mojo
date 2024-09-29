from libc.network import htonl, htons, ntohl, ntohs
from testing import assert_equal

fn test_htonl() raises:
    assert_equal(htonl(0x12345678), 0x78563412)


fn test_htons() raises:
    assert_equal(htons(0x1234), 0x3412)


fn test_ntohl() raises:
    assert_equal(ntohl(0x78563412), 0x12345678)


fn test_ntohs() raises:
    assert_equal(ntohs(0x3412), 0x1234)