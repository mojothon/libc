from testing import assert_equal
from libc.ctype import *

fn test_islower() raises:
    assert_equal(islower(47), 0)


fn test_islower_l() raises:
    assert_equal(islower(47), 0)


# ... 