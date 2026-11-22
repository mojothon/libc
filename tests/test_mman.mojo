"""Tests for the `libc.sys.mman` bindings, none of which had been called."""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import O_CREAT, O_RDWR
from libc.constant import (
    EINVAL,
    ENOMEM,
    MADV_WILLNEED,
    MCL_CURRENT,
    MAP_ANONYMOUS,
    MADV_COLD,
    MADV_DODUMP,
    MADV_DOFORK,
    MADV_DONTDUMP,
    MADV_DONTFORK,
    MADV_HUGEPAGE,
    MADV_KEEPONFORK,
    MADV_MERGEABLE,
    MADV_NOHUGEPAGE,
    MADV_PAGEOUT,
    MADV_POPULATE_READ,
    MADV_POPULATE_WRITE,
    MADV_REMOVE,
    MADV_UNMERGEABLE,
    MADV_WIPEONFORK,
    MAP_PRIVATE,
    MAP_SHARED,
    POSIX_MADV_NORMAL,
    PROT_READ,
    PROT_WRITE,
    MS_SYNC,
)
from libc.constant import c_ptr
from libc.errno import get_errno, set_errno
from libc.signal import SIGABRT, SIGSEGV, signal
from libc.sys.mman import (
    madvise,
    mincore,
    mlock,
    mlock2,
    mlockall,
    mmap,
    mprotect,
    msync,
    munlock,
    munlockall,
    MREMAP_MAYMOVE,
    mremap,
    munmap,
    posix_madvise,
    remap_file_pages,
    shm_open,
    shm_unlink,
)
from libc.stdlib import exit
from libc.sys.resource import RLIMIT_MEMLOCK, Rlimit, getrlimit, setrlimit
from libc.sys.wait import WIFSIGNALED, WTERMSIG, waitpid
from libc.unistd import close, fork, ftruncate
from libc.utils import null_ptr, string_to_char_ptr


def test_mmap_hands_back_memory() raises:
    """`mmap` is given the address, the length, the protection, the flags,
    the descriptor and the offset, in that order, and three of those six
    are one type. What says the arguments landed where they were meant to
    is that what is written into it comes back out of it.
    """
    comptime SIZE = 4096
    comptime RW: Int32 = PROT_READ | PROT_WRITE
    comptime PRIVATE_ANON: Int32 = MAP_PRIVATE | MAP_ANONYMOUS

    var p = mmap(null_ptr[UInt8](), SIZE, RW, PRIVATE_ANON, -1, 0)
    # `MAP_FAILED` is `(void *) -1`, a pointer, so it cannot be written
    # down as a constant here; it is known instead by being the one
    # answer that is not a positive number.
    assert_true(Int(UInt(p)) > 0, "mmap hands back an address, not a failure")

    p.unsafe_store(0, UInt8(65))
    p.unsafe_store(1, UInt8(66))
    assert_equal(
        p.unsafe_load(0), UInt8(65), "and what is written is what is there"
    )
    assert_equal(p.unsafe_load(1), UInt8(66), "at the place it was written")

    assert_equal(
        mprotect(p, SIZE, PROT_READ),
        0,
        "mprotect takes the address, the length and the protection",
    )
    assert_equal(
        p.unsafe_load(0), UInt8(65), "and what was written can still be read"
    )
    # Whether that protection is in force cannot be asked from here -- a write
    # that is refused would end this process rather than answer it -- so it is
    # asked from a child, which is what a process is for. `madvise` takes the
    # same three arguments and `PROT_READ` is a valid advice, so a binding
    # pointed at it leaves the page writable and the child lives.
    assert_equal(mprotect(p, SIZE, PROT_READ), 0, "the page is made read-only")
    var child = fork()
    if child == 0:
        # The run time has a `SIGSEGV` handler of its own that writes out a
        # report, and the default is put back so that the fault ends the child
        # quietly. `SIG_DFL` is a null handler, so this is
        # `signal(SIGSEGV, SIG_DFL)`.
        _ = signal(SIGSEGV, null_ptr[UInt8]())
        p.unsafe_store(0, UInt8(67))
        _ = exit(0)
    assert_true(child > 0, "there is a child to try the write")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_store(0, 0)
    assert_equal(waitpid(child, status, 0), child, "and it is waited for")
    assert_true(
        WIFSIGNALED(status.unsafe_load()),
        "the write it tried ended it, rather than landing",
    )
    # Which signal that is belongs to the run time rather than to the kernel:
    # Linux lets the fault through as `SIGSEGV`, and on Darwin the crash
    # reporter catches it and answers with an abort. Either is the write not
    # landing, which is the thing being asked.
    var ended_by = WTERMSIG(status.unsafe_load())
    assert_true(
        ended_by == SIGSEGV or ended_by == SIGABRT,
        "which is a write to a read-only page, however the run time reports it",
    )
    status.unsafe_free()

    assert_equal(
        mprotect(p, SIZE, RW), 0, "and the writing of it is given back"
    )

    assert_equal(
        msync(p, SIZE, MS_SYNC), 0, "msync takes the same two, and flags"
    )
    # The flags are the one argument the three of them do not share, and what
    # says so is a number that is a flag to one of them and not to the other:
    # 8 is `MADV_FREE` to `madvise`, and no `MS_` bit at all to `msync`, which
    # refuses it. A binding pointed at `madvise` answers 0.
    # Linux checks them and Darwin does not, which was measured there: the
    # macOS runner answered 0 for the same call, so the assertion is only made
    # where it holds, and the one platform where the two calls differ is
    # enough for the sweep.
    comptime if not CompilationTarget.is_macos():
        set_errno(0)
        assert_equal(
            msync(p, SIZE, 8), -1, "msync refuses flags it does not know"
        )
        assert_equal(
            get_errno(),
            Int32(EINVAL),
            "and says which of them it minded, rather than answering 0",
        )

    assert_equal(madvise(p, SIZE, MADV_WILLNEED), 0, "madvise takes an advice")
    assert_equal(
        posix_madvise(p, SIZE, POSIX_MADV_NORMAL),
        0,
        "and posix_madvise takes one of its own",
    )
    # The other half of the same distinction: `posix_madvise` answers with the
    # error number itself and `madvise` answers -1 and puts it in errno, so an
    # advice neither of them knows comes back as two different numbers.
    # Where the two shapes of answer differ: POSIX has this one hand back the
    # error number itself, and the implementation on the other platform
    # answered -1 like `madvise` instead -- measured on that platform's runner,
    # so the assertion is made where it holds.
    comptime if not CompilationTarget.is_macos():
        assert_equal(
            posix_madvise(p, SIZE, 999),
            Int32(EINVAL),
            "an advice nobody knows comes back as the number, not as -1",
        )

    var vec = unsafe_alloc[UInt8](1)
    vec.unsafe_store(0, 0)
    assert_equal(
        mincore(p, SIZE, vec), 0, "mincore writes into the vector it is handed"
    )
    vec.unsafe_free()

    assert_equal(munmap(p, SIZE), 0, "and munmap takes the two back")

    # The address is not a mapping any more, and asking to change its
    # protection is the way that shows: `munmap` has the same signature as
    # `mlock` and the same answer of 0, and what a lock would have left behind
    # is exactly the mapping this asks after.
    set_errno(0)
    assert_equal(
        mprotect(p, SIZE, PROT_READ),
        -1,
        "the address munmap gave back is not a mapping to protect",
    )
    assert_equal(
        get_errno(),
        Int32(ENOMEM),
        "which is what the range not being mapped is called",
    )


def test_shm_open_makes_an_object() raises:
    """A name, some flags and a mode, and what comes back is a descriptor
    that can be mapped like any other.
    """
    comptime SIZE = 4096
    comptime RW: Int32 = PROT_READ | PROT_WRITE
    var name = string_to_char_ptr("/mojo_libc_mman_shm")

    var fd = shm_open(name, Int32(O_CREAT | O_RDWR), 0o600)
    assert_true(fd >= 0, "shm_open hands back a descriptor")
    assert_equal(ftruncate(fd, SIZE), 0, "and it can be given a length")

    var p = mmap(null_ptr[UInt8](), SIZE, RW, Int32(MAP_SHARED), fd, 0)
    assert_true(Int(UInt(p)) > 0, "and the descriptor can be mapped")
    p.unsafe_store(0, UInt8(90))
    assert_equal(p.unsafe_load(0), UInt8(90), "through the mapping")

    assert_equal(munmap(p, SIZE), 0, "and unmapped again")
    assert_equal(close(fd), 0, "the descriptor closes")
    assert_equal(shm_unlink(name), 0, "and the name is taken away")


def test_mlock_keeps_a_page_and_munlock_lets_it_go() raises:
    """`mlock` asks that a piece of memory be kept in RAM rather than
    written out to swap, and `munlock` takes the asking back. One
    page is well inside what an ordinary process is allowed to lock,
    that being a limit and not the whole of its memory.
    """
    comptime SIZE = 4096
    comptime RW: Int32 = PROT_READ | PROT_WRITE
    comptime PRIVATE_ANON: Int32 = MAP_PRIVATE | MAP_ANONYMOUS

    var p = mmap(null_ptr[UInt8](), SIZE, RW, PRIVATE_ANON, -1, 0)
    assert_true(Int(UInt(p)) > 0, "there is a page to lock")

    assert_equal(mlock(p, SIZE), 0, "mlock keeps it in")
    assert_equal(munlock(p, SIZE), 0, "and munlock lets it go")

    # What separates the two is what they do when the lock cannot be granted:
    # `mlock` asks for something and is refused, and `munlock` gives back what
    # was never taken and answers 0 all the same. The limit on how much of a
    # process may be kept in is what makes the first one refuse, and it is put
    # back to what it was before anything else is asked.
    var before = unsafe_alloc[Rlimit](1)
    before.unsafe_offset(0)[] = Rlimit()
    assert_equal(getrlimit(RLIMIT_MEMLOCK, before), 0, "the lock limit is read")
    var nothing = unsafe_alloc[Rlimit](1)
    nothing.unsafe_offset(0)[] = before.unsafe_offset(0)[]
    nothing.unsafe_offset(0)[].rlim_cur = 0
    assert_equal(
        setrlimit(RLIMIT_MEMLOCK, nothing), 0, "and brought down to nothing"
    )
    assert_true(
        mlock(p, SIZE) != 0, "nothing may be kept in, so mlock is refused"
    )
    assert_equal(
        munlock(p, SIZE), 0, "and munlock lets go of what was never held"
    )
    assert_equal(setrlimit(RLIMIT_MEMLOCK, before), 0, "the limit is put back")

    nothing.unsafe_free()
    before.unsafe_free()
    _ = munmap(p, SIZE)


def test_munlockall_takes_back_everything() raises:
    """macOS runners lock the sandbox down so that `mlock` fails
    there, and asking `munlockall` to undo what was never granted
    fails along with it. On the platforms that can grant the lock,
    the answer is what the man page says it is: 0.

    `mlockall` asks for the whole of the process to be kept in,
    which is more than an ordinary process is usually allowed to
    ask for, so whether it is granted is not asked here.

    `munlockall` takes back whatever was locked before it, which
    is nothing at all if the asking came to nothing — and that is
    why it is the one of the two that can be counted on to answer 0.
    """
    comptime if CompilationTarget.is_macos():
        return
    _ = mlockall(MCL_CURRENT)
    assert_equal(munlockall(), 0, "munlockall takes back whatever was locked")


def test_the_two_that_are_linux_only() raises:
    """`mlock2` is `mlock` with flags, one of which says not to bring
    the pages in until they are touched. Given none, it is what
    `mlock` is.

    `remap_file_pages` moves pages about inside a mapping and has
    been on its way out since 2.6.23: what is left of it is for
    tmpfs and nothing else, so asked of an anonymous mapping it
    refuses, and that is the answer asked for here.
    """
    comptime if not CompilationTarget.is_macos():
        comptime SIZE = 4096
        comptime RW: Int32 = PROT_READ | PROT_WRITE
        comptime PRIVATE_ANON: Int32 = MAP_PRIVATE | MAP_ANONYMOUS

        var p = mmap(null_ptr[UInt8](), SIZE, RW, PRIVATE_ANON, -1, 0)
        assert_true(Int(UInt(p)) > 0, "there is a page to lock")

        assert_equal(mlock2(p, SIZE, 0), 0, "mlock2 with no flags keeps it in")
        assert_equal(munlock(p, SIZE), 0, "and munlock lets it go")

        # With nothing allowed to be kept in, `mlock2` refuses and `madvise`
        # -- the call it would be swapped for, taking the same three arguments
        # -- does not, having no such notion.
        var was = unsafe_alloc[Rlimit](1)
        was.unsafe_offset(0)[] = Rlimit()
        assert_equal(
            getrlimit(RLIMIT_MEMLOCK, was), 0, "the lock limit is read"
        )
        var none = unsafe_alloc[Rlimit](1)
        none.unsafe_offset(0)[] = was.unsafe_offset(0)[]
        none.unsafe_offset(0)[].rlim_cur = 0
        assert_equal(
            setrlimit(RLIMIT_MEMLOCK, none), 0, "and brought down to nothing"
        )
        assert_true(
            mlock2(p, SIZE, 0) != 0, "so mlock2 is refused and madvise is not"
        )
        assert_equal(madvise(p, SIZE, 0), 0, "which the same limits allow")
        assert_equal(setrlimit(RLIMIT_MEMLOCK, was), 0, "the limit is put back")
        none.unsafe_free()
        was.unsafe_free()

        assert_equal(
            remap_file_pages(p, SIZE, PROT_READ, 0, 0),
            -1,
            "remap_file_pages refuses an anonymous mapping",
        )
        _ = munmap(p, SIZE)


def main() raises:
    test_mmap_hands_back_memory()
    test_shm_open_makes_an_object()
    test_mlock_keeps_a_page_and_munlock_lets_it_go()
    test_munlockall_takes_back_everything()
    test_the_two_that_are_linux_only()
    test_the_map_grows_and_keeps_what_it_holds()
    test_the_sizes_are_promises_about_pages()
    test_a_refused_ask_comes_back_a_pointer_no_check_passes()
    test_the_advice_the_linux_kernel_takes()
    print("test_mman: ok")


def test_the_map_grows_and_keeps_what_it_holds() raises:
    """`mremap` and `MREMAP_MAYMOVE`: a mapping of one page grown to
    two -- the bytes the caller wrote before the ask are the bytes
    read after it, at whatever address the answer names, which may
    not be the address the caller gave. The kernel moves a map the
    flag says it may move, and the content goes with it.
    """
    comptime if not CompilationTarget.is_macos():
        comptime SIZE = 4096
        comptime RW: Int32 = PROT_READ | PROT_WRITE

        var first = mmap(
            null_ptr[UInt8](), SIZE, RW, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0
        )
        assert_true(Int(UInt(first)) > 0, "the mapping is made")

        for i in range(0, SIZE):
            first.unsafe_store(i, UInt8(65))
        assert_equal(
            Int(first.unsafe_load(0)), 65, "and it holds what was written"
        )

        var wider = mremap(first, SIZE, SIZE * 2, MREMAP_MAYMOVE)
        assert_true(Int(UInt(wider)) > 0, "the mapping is grown")
        assert_equal(
            Int(wider.unsafe_load(0)),
            65,
            "the first byte of what was written is read back",
        )
        assert_equal(
            Int(wider.unsafe_load(SIZE - 1)),
            65,
            "and the last byte of the old page too",
        )

        wider.unsafe_store(SIZE, UInt8(66))
        assert_equal(
            Int(wider.unsafe_load(SIZE)),
            66,
            "the page the grow added is writable",
        )

        assert_equal(
            munmap(wider, SIZE * 2), 0, "and the wider map is given back"
        )


def test_the_sizes_are_promises_about_pages() raises:
    """`mremap` and the rounding: a grow by a byte is a grow by a
    page -- the kernel rounds both sizes up, so an ask for one more
    byte of map is answered with a whole page more, which is a
    page that can be written.
    """
    comptime if not CompilationTarget.is_macos():
        comptime SIZE = 4096
        comptime RW: Int32 = PROT_READ | PROT_WRITE

        var first = mmap(
            null_ptr[UInt8](), SIZE, RW, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0
        )
        assert_true(Int(UInt(first)) > 0, "the mapping is made")

        var wider = mremap(first, SIZE, SIZE + 1, MREMAP_MAYMOVE)
        assert_true(Int(UInt(wider)) > 0, "the grow by a byte is answered")
        wider.unsafe_store(SIZE, UInt8(77))
        assert_equal(
            Int(wider.unsafe_load(SIZE)),
            77,
            "and the page it rounded up to is writable",
        )

        assert_equal(munmap(wider, SIZE * 2), 0, "and the map is given back")


def test_a_refused_ask_comes_back_a_pointer_no_check_passes() raises:
    """`mremap` of an address the kernel never mapped: the ask is
    refused, and what comes back fails the caller's check for a
    map -- the word for failure and the address of a map travelling
    in the same slot.
    """
    comptime if not CompilationTarget.is_macos():
        comptime RW: Int32 = PROT_READ | PROT_WRITE

        var refused = mremap(
            c_ptr[UInt8](unsafe_from_address=Int(0x700000000000)),
            4096,
            8192,
            MREMAP_MAYMOVE,
        )
        # `MAP_FAILED` is `(void *) -1`, the one answer that is not a
        # positive number, the word for failure in the slot a map comes
        # back in.
        # The refusal is the all-ones word, read as a number -- and
        # the success the two tests above had is the one answer
        # that is a positive number.
        assert_true(Int(refused) != 0, "a refusal is not the null answer")
        assert_true(
            Int(refused) != 0x700000000000,
            "and it is not the address the ask named",
        )


def test_the_advice_the_linux_kernel_takes() raises:
    """The `MADV_` advice the Linux kernel's headers name and Darwin
    does not: each ask answered 0 of an anonymous mapping, the
    content untouched by advice that moves no bytes -- and the
    one ask the kernel refuses here, `MADV_REMOVE`, named for
    the filesystem-backed mappings it works on, which an
    anonymous one is not.
    """
    comptime if not CompilationTarget.is_macos():
        comptime SIZE = 4096
        comptime RW: Int32 = PROT_READ | PROT_WRITE

        var p = mmap(
            null_ptr[UInt8](), SIZE, RW, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0
        )
        assert_true(Int(UInt(p)) > 0, "the mapping is made")
        p.unsafe_store(0, UInt8(65))

        assert_equal(madvise(p, SIZE, MADV_DONTFORK), 0, "not across a fork")
        assert_equal(
            madvise(p, SIZE, MADV_DOFORK),
            0,
            "and the asking again is inherited",
        )
        assert_equal(madvise(p, SIZE, MADV_DONTDUMP), 0, "not into a core dump")
        assert_equal(madvise(p, SIZE, MADV_DODUMP), 0, "and back into one")
        assert_equal(
            madvise(p, SIZE, MADV_MERGEABLE),
            0,
            "the kernel may merge the identical",
        )
        assert_equal(
            madvise(p, SIZE, MADV_UNMERGEABLE), 0, "and may be told not to"
        )
        assert_equal(madvise(p, SIZE, MADV_HUGEPAGE), 0, "worth a huge page")
        assert_equal(madvise(p, SIZE, MADV_NOHUGEPAGE), 0, "and not worth one")
        assert_equal(
            madvise(p, SIZE, MADV_WIPEONFORK), 0, "wiped for the child"
        )
        assert_equal(
            madvise(p, SIZE, MADV_KEEPONFORK), 0, "and kept for the child"
        )
        assert_equal(
            madvise(p, SIZE, MADV_COLD), 0, "expected to be needed less"
        )
        assert_equal(
            madvise(p, SIZE, MADV_PAGEOUT),
            0,
            "expected to be needed less still",
        )
        assert_equal(
            madvise(p, SIZE, MADV_POPULATE_READ), 0, "brought in for reading"
        )
        assert_equal(
            madvise(p, SIZE, MADV_POPULATE_WRITE), 0, "brought in for writing"
        )

        assert_equal(
            Int(p.unsafe_load(0)),
            65,
            "and advice that moves no bytes leaves the byte",
        )
        assert_equal(
            madvise(p, SIZE, MADV_REMOVE),
            -1,
            "the ask that works on a file's pages",
        )
        assert_equal(
            Int(get_errno()), Int(EINVAL), "refused of an anonymous map"
        )
        assert_equal(munmap(p, SIZE), 0, "and the mapping is given back")
