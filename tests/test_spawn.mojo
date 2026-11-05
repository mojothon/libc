"""Tests for the `libc.spawn` bindings.

`posix_spawn` starts a process without `fork`. Each test asks it to do
something that can then be looked at: run `sh -c 'exit 7'` and hand an
exit code back, or write into a pipe whose other end is held here.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from std.sys import size_of
from libc.constant import c_int, c_ptr, c_short, c_uint
from libc.fcntl import O_CREAT, O_RDONLY, O_TRUNC, O_WRONLY, open
from libc.file import close, read
from libc.spawn import (
    POSIX_SPAWN_SETPGROUP,
    posix_spawn,
    posix_spawn_file_actions_addclose,
    posix_spawn_file_actions_adddup2,
    posix_spawn_file_actions_addopen,
    posix_spawn_file_actions_destroy,
    posix_spawn_file_actions_init,
    posix_spawn_file_actions_t,
    posix_spawnattr_destroy,
    posix_spawnattr_getflags,
    posix_spawnattr_getpgroup,
    posix_spawnattr_getsigdefault,
    posix_spawnattr_getsigmask,
    posix_spawnattr_init,
    posix_spawnattr_setflags,
    posix_spawnattr_setpgroup,
    posix_spawnattr_setsigdefault,
    posix_spawnattr_setsigmask,
    posix_spawnattr_t,
    posix_spawnp,
)
from libc.signal import SIGSEGV, sigemptyset, sigfillset, signal
from libc.stdlib import exit
from libc.unistd import fork
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.unistd import pipe, unlink
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def _argv_for(
    first: String, second: String, third: String
) raises -> c_ptr[c_ptr[UInt8]]:
    """Three arguments and the null that ends them, as C wants them."""
    var argv = unsafe_alloc[c_ptr[UInt8]](4)
    argv.unsafe_offset(0)[] = string_to_char_ptr(first)
    argv.unsafe_offset(1)[] = string_to_char_ptr(second)
    argv.unsafe_offset(2)[] = string_to_char_ptr(third)
    argv.unsafe_offset(3)[] = null_ptr[UInt8]()
    return argv


def _empty_environment() -> c_ptr[c_ptr[UInt8]]:
    """An environment with nothing in it, which is still a list with a
    null where it ends.
    """
    var envp = unsafe_alloc[c_ptr[UInt8]](1)
    envp.unsafe_offset(0)[] = null_ptr[UInt8]()
    return envp


def _drop_argv(argv: c_ptr[c_ptr[UInt8]], count: Int) raises:
    """Gives back the strings and then the list that held them."""
    for i in range(count):
        argv.unsafe_offset(i)[].unsafe_free()
    argv.unsafe_free()


def test_posix_spawnp_runs_the_program_its_arguments_name() raises:
    """`sh -c 'exit 7'` — the arguments reach the program named by
    them, and the code it exits with comes back through `waitpid`.

    7 and not 0, because a program that exits 0 would look the same
    whichever one had been started.
    """
    var argv = _argv_for("sh", "-c", "exit 7")
    var envp = _empty_environment()
    var pid = unsafe_alloc[Int32](1)

    var ran = posix_spawnp(
        pid,
        string_to_char_ptr("sh"),
        null_ptr[posix_spawn_file_actions_t](),
        null_ptr[posix_spawnattr_t](),
        argv,
        envp,
    )
    assert_equal(Int(ran), 0, "the shell is looked for along PATH")
    assert_true(pid[] > 0, "and the new process has an id")

    var status = unsafe_alloc[Int32](1)
    assert_true(waitpid(pid[], status, 0) == pid[], "the child is waited for")
    assert_true(WIFEXITED(status[]), "and it ended by exiting")
    assert_equal(Int(WEXITSTATUS(status[])), 7, "with the code it was told to")

    _drop_argv(argv, 3)
    envp.unsafe_free()
    pid.unsafe_free()
    status.unsafe_free()


def test_posix_spawn_answers_for_a_path_that_is_not_there() raises:
    """A path that names nothing is answered with the error number
    itself — 2, which is `ENOENT` — and not with -1, which is what
    the rest of the package's calls do.
    """
    var argv = _argv_for("no-such-program", "", "")
    var envp = _empty_environment()
    var pid = unsafe_alloc[Int32](1)
    pid.unsafe_offset(0)[] = -1

    var answered = posix_spawn(
        pid,
        string_to_char_ptr("/no/such/program/at/all"),
        null_ptr[posix_spawn_file_actions_t](),
        null_ptr[posix_spawnattr_t](),
        argv,
        envp,
    )
    assert_equal(Int(answered), 2, "the error number comes back, not -1")
    assert_equal(
        Int(pid[]), -1, "and nothing is written where the pid would go"
    )

    _drop_argv(argv, 3)
    envp.unsafe_free()
    pid.unsafe_free()


def test_the_file_actions_hand_the_child_a_pipe_for_its_output() raises:
    """A pipe, and a child told to write into it: `adddup2` puts its
    write end where the child's standard output is, and `addclose`
    takes away what the child does not need. What comes out of the
    read end is the proof — the shell's output was not written to
    the terminal, and it was not thrown away either.
    """
    var fds = unsafe_alloc[Int32](2)
    assert_equal(Int(pipe(fds)), 0, "a pipe to carry what it writes")
    var reading_end = fds.unsafe_offset(0)[]
    var writing_end = fds.unsafe_offset(1)[]

    var actions = unsafe_alloc[posix_spawn_file_actions_t](1)
    # Filled first with bytes that are not a pointer anybody made, so that the
    # call has a mess of its own to clean: `init` puts the list at nothing and
    # the spawn goes, and pointed at `destroy` instead it would take the bytes
    # for a list it had made and take them back.
    var filler = actions.unsafe_bitcast[UInt8]()
    for i in range(size_of[posix_spawn_file_actions_t]()):
        filler.unsafe_store(i, UInt8(0x7F))
    assert_equal(
        Int(posix_spawn_file_actions_init(actions)), 0, "an empty list"
    )
    assert_equal(
        Int(posix_spawn_file_actions_adddup2(actions, writing_end, 1)),
        0,
        "the write end becomes the child's standard output",
    )
    assert_equal(
        Int(posix_spawn_file_actions_addclose(actions, writing_end)),
        0,
        "and its copy of the write end is closed",
    )
    assert_equal(
        Int(posix_spawn_file_actions_addclose(actions, reading_end)),
        0,
        "and so is its copy of the read end",
    )

    var argv = _argv_for("sh", "-c", "echo hello")
    var envp = _empty_environment()
    var pid = unsafe_alloc[Int32](1)
    assert_equal(
        Int(
            posix_spawn(
                pid,
                string_to_char_ptr("/bin/sh"),
                actions,
                null_ptr[posix_spawnattr_t](),
                argv,
                envp,
            )
        ),
        0,
        "the shell is started with the pipe for its output",
    )

    assert_equal(
        Int(close(writing_end)), 0, "our write end, so that reading ends"
    )
    var got = unsafe_alloc[UInt8](16)
    for i in range(16):
        got.unsafe_offset(i)[] = 0
    assert_true(read(reading_end, got, 15) > 0, "and it wrote into the pipe")
    assert_equal(char_ptr_to_string(got), "hello\n", "which came back here")
    assert_equal(Int(close(reading_end)), 0, "and the pipe is given back")

    var status = unsafe_alloc[Int32](1)
    _ = waitpid(pid[], status, 0)
    assert_equal(
        Int(posix_spawn_file_actions_destroy(actions)), 0, "and released"
    )

    _drop_argv(argv, 3)
    envp.unsafe_free()
    fds.unsafe_free()
    got.unsafe_free()
    pid.unsafe_free()
    status.unsafe_free()


def test_the_file_actions_open_a_file_where_the_child_would_write() raises:
    """`addopen` is the other half of `adddup2`: not "put this descriptor
    there" but "open this path there", so the file is opened by the child
    after it exists and the parent never holds it.

    What is asked is that the child's standard output is that file and
    nothing else — the file is on disk here, and it is read back after
    the child has gone, so a call that opened it in the parent instead,
    or on the wrong descriptor, leaves it empty.
    """
    comptime path = "/tmp/libc-spawn-addopen-output"
    var want = string_to_char_ptr(path)
    _ = unlink(want)

    var actions = unsafe_alloc[posix_spawn_file_actions_t](1)
    assert_equal(
        Int(posix_spawn_file_actions_init(actions)), 0, "an empty list"
    )
    assert_equal(
        Int(
            posix_spawn_file_actions_addopen(
                actions,
                1,
                want,
                c_int(O_WRONLY | O_CREAT | O_TRUNC),
                c_uint(0o644),
            )
        ),
        0,
        "standard output becomes a file the child opens",
    )

    var argv = _argv_for("sh", "-c", "echo redirected")
    var envp = _empty_environment()
    var pid = unsafe_alloc[Int32](1)
    assert_equal(
        Int(
            posix_spawn(
                pid,
                string_to_char_ptr("/bin/sh"),
                actions,
                null_ptr[posix_spawnattr_t](),
                argv,
                envp,
            )
        ),
        0,
        "the shell is started with a file for its output",
    )

    var status = unsafe_alloc[Int32](1)
    assert_true(waitpid(pid[], status, 0) == pid[], "the child is waited for")
    assert_equal(Int(WEXITSTATUS(status[])), 0, "and it wrote and left")

    var reading = open(want, O_RDONLY)
    assert_true(reading >= 0, "the file the child was given is there")
    var got = unsafe_alloc[UInt8](32)
    for i in range(32):
        got.unsafe_offset(i)[] = 0
    assert_true(read(reading, got, 31) > 0, "and has what it wrote in it")
    assert_equal(
        char_ptr_to_string(got), "redirected\n", "which is the one word"
    )
    assert_equal(Int(close(reading)), 0, "and is closed again")
    _ = unlink(want)

    assert_equal(
        Int(posix_spawn_file_actions_destroy(actions)), 0, "the list released"
    )
    _drop_argv(argv, 3)
    envp.unsafe_free()
    want.unsafe_free()
    got.unsafe_free()
    pid.unsafe_free()
    status.unsafe_free()


def test_the_attributes_hold_the_group_and_the_flags_they_are_given() raises:
    """A group and the flag that says to look at it, put in and read
    back. 0 means a group of the process's own, which is what
    `setpgrp` gives and the one a caller would ask for.
    """
    var attr = unsafe_alloc[posix_spawnattr_t](1)
    assert_equal(Int(posix_spawnattr_init(attr)), 0, "the handle is ready")

    assert_equal(Int(posix_spawnattr_setpgroup(attr, 0)), 0, "its own group")
    assert_equal(
        Int(posix_spawnattr_setflags(attr, c_short(POSIX_SPAWN_SETPGROUP))),
        0,
        "and the flag that says to honour it",
    )

    var group = unsafe_alloc[Int32](1)
    var flags = unsafe_alloc[c_short](1)
    assert_equal(Int(posix_spawnattr_getpgroup(attr, group)), 0, "read back")
    assert_equal(Int(posix_spawnattr_getflags(attr, flags)), 0, "read back")
    assert_equal(Int(group[]), 0, "the group it was given")
    assert_equal(
        Int(flags[]),
        Int(POSIX_SPAWN_SETPGROUP),
        "the flag it was given",
    )

    assert_equal(Int(posix_spawnattr_destroy(attr)), 0, "and released")

    attr.unsafe_free()
    group.unsafe_free()
    flags.unsafe_free()


def _zeroed_set() raises -> c_ptr[UInt8]:
    """A signal set as C wants one: 128 bytes, room for the largest of
    the two, since each writes its own width and no more.
    """
    var block = unsafe_alloc[UInt8](128)
    for i in range(128):
        block.unsafe_offset(i)[] = 0
    return block


def _sentinel_set() raises -> c_ptr[UInt8]:
    """A block filled with something no set is, so a getter that writes
    nothing cannot pass for one that did.
    """
    var block = unsafe_alloc[UInt8](128)
    for i in range(128):
        block.unsafe_offset(i)[] = 0xA5
    return block


def test_the_signal_sets_the_handle_is_given_come_back_out() raises:
    """What `posix_spawnattr_setsigmask` and `posix_spawnattr_setsigdefault`
    put in, the two getters hand back: a copy of it, in a block of the
    caller's, which is what makes the getters worth having at all,
    there being no other way to ask what a handle is carrying.

    Only the first four bytes are compared. Both platforms write their
    own `sigset_t` and no more, and four bytes is the width the two have
    in common, so it is all a test can say is equal without knowing
    which one it is running on.
    """
    var attr = unsafe_alloc[posix_spawnattr_t](1)
    assert_equal(Int(posix_spawnattr_init(attr)), 0, "the handle is made")

    var filled = _zeroed_set()
    assert_equal(Int(sigfillset(filled)), 0, "a set with everything in it")
    assert_equal(
        Int(posix_spawnattr_setsigmask(attr, filled)), 0, "the mask goes in"
    )
    assert_equal(
        Int(posix_spawnattr_setsigdefault(attr, filled)),
        0,
        "and so does the set of signals left at their default",
    )

    var got_mask = _sentinel_set()
    assert_equal(
        Int(posix_spawnattr_getsigmask(attr, got_mask)),
        0,
        "the mask comes back",
    )
    for i in range(4):
        assert_equal(
            Int(got_mask.unsafe_offset(i)[]),
            Int(filled.unsafe_offset(i)[]),
            "the mask byte that went in is the one that came out",
        )

    var got_default = _sentinel_set()
    assert_equal(
        Int(posix_spawnattr_getsigdefault(attr, got_default)),
        0,
        "and so does the default",
    )
    for i in range(4):
        assert_equal(
            Int(got_default.unsafe_offset(i)[]),
            Int(filled.unsafe_offset(i)[]),
            "the default byte that went in is the one that came out",
        )

    assert_equal(Int(posix_spawnattr_destroy(attr)), 0, "the handle goes back")


def test_the_two_signal_sets_are_two_things() raises:
    """The two getters do not read one field: a mask holding every
    signal and a default holding none come back as what they were, which
    is the one way to tell the two apart. A getter wired to the wrong
    one, or both wired to the same, answers full for both here.
    """
    var attr = unsafe_alloc[posix_spawnattr_t](1)
    assert_equal(Int(posix_spawnattr_init(attr)), 0, "the handle is made")

    var full = _zeroed_set()
    var empty = _zeroed_set()
    assert_equal(Int(sigfillset(full)), 0, "one set full")
    assert_equal(Int(sigemptyset(empty)), 0, "and one empty")

    assert_equal(Int(posix_spawnattr_setsigmask(attr, full)), 0, "mask: full")
    assert_equal(
        Int(posix_spawnattr_setsigdefault(attr, empty)), 0, "default: empty"
    )

    var got_mask = _sentinel_set()
    var got_default = _sentinel_set()
    assert_equal(
        Int(posix_spawnattr_getsigmask(attr, got_mask)), 0, "mask read"
    )
    assert_equal(
        Int(posix_spawnattr_getsigdefault(attr, got_default)), 0, "default read"
    )

    assert_equal(
        Int(got_mask.unsafe_offset(0)[]),
        Int(full.unsafe_offset(0)[]),
        "the mask came back full",
    )
    assert_equal(
        Int(got_default.unsafe_offset(0)[]),
        Int(empty.unsafe_offset(0)[]),
        "and the default came back empty, which the mask is not",
    )

    assert_equal(Int(posix_spawnattr_destroy(attr)), 0, "the handle goes back")


def test_posix_spawn_refuses_a_name_with_no_path_in_it() raises:
    """`sh` — a bare name, the shape `posix_spawnp` goes looking for
    along `PATH`. `posix_spawn` is told a path and does not look, so
    it answers with the error number of having been given a name it
    was meant to take for a path, which is the one answer that tells
    the two apart.
    """
    var argv = _argv_for("sh", "-c", "exit 7")
    var envp = _empty_environment()
    var pid = unsafe_alloc[Int32](1)
    pid.unsafe_offset(0)[] = -1

    assert_equal(
        Int(
            posix_spawn(
                pid,
                string_to_char_ptr("sh"),
                null_ptr[posix_spawn_file_actions_t](),
                null_ptr[posix_spawnattr_t](),
                argv,
                envp,
            )
        ),
        2,
        "a bare name is refused with the error number, not 0",
    )

    _drop_argv(argv, 3)
    envp.unsafe_free()
    pid.unsafe_free()


def test_the_attributes_are_a_block_the_call_cleans() raises:
    """The attribute block is filled with bytes that are not a pointer
    anybody made, and `posix_spawnattr_init` is what makes it usable:
    the shell it hands them to leaves with the code it was told,
    which a block full of somebody else's bytes would not have got it
    to.
    """
    var attr = unsafe_alloc[posix_spawnattr_t](1)
    var attr_filler = attr.unsafe_bitcast[UInt8]()
    for i in range(size_of[posix_spawnattr_t]()):
        attr_filler.unsafe_store(i, UInt8(0x7F))
    assert_equal(Int(posix_spawnattr_init(attr)), 0, "the block is made usable")

    var argv = _argv_for("sh", "-c", "exit 7")
    var envp = _empty_environment()
    var pid = unsafe_alloc[Int32](1)
    assert_equal(
        Int(
            posix_spawn(
                pid,
                string_to_char_ptr("/bin/sh"),
                null_ptr[posix_spawn_file_actions_t](),
                attr,
                argv,
                envp,
            )
        ),
        0,
        "the shell is started with the block for its attributes",
    )
    var status = unsafe_alloc[Int32](1)
    assert_true(waitpid(pid[], status, 0) == pid[], "the child is waited for")
    assert_equal(
        Int(WEXITSTATUS(status[])), 7, "and left with the code it was told"
    )
    assert_equal(
        Int(posix_spawnattr_destroy(attr)), 0, "and the block is given back"
    )

    attr.unsafe_free()
    status.unsafe_free()
    _drop_argv(argv, 3)
    envp.unsafe_free()
    pid.unsafe_free()


def test_the_file_actions_take_a_mess_and_answer_for_it() raises:
    """A handle full of bytes nobody made is where the pair starts:
    `posix_spawn_file_actions_init` takes the mess and leaves an empty
    list, and `posix_spawn_file_actions_destroy` takes the empty list
    back, each answering 0.

    Whether either of those happened is not observable from here --
    there is nothing in the list to read -- but a call pointed at its
    other half takes the mess for a list it had made, and that ends the
    process asking. So the pair is asked from a child, whose ending is a
    status this suite reads rather than a crash this suite dies of.
    """
    var child = fork()
    if child == 0:
        _ = signal(SIGSEGV, null_ptr[UInt8]())
        var actions = unsafe_alloc[posix_spawn_file_actions_t](1)
        var filler = actions.unsafe_bitcast[UInt8]()
        for i in range(size_of[posix_spawn_file_actions_t]()):
            filler.unsafe_store(i, UInt8(0x7F))
        var made = posix_spawn_file_actions_init(actions)
        if made != 0:
            _ = exit(Int32(made))
        var gone = posix_spawn_file_actions_destroy(actions)
        if gone != 0:
            _ = exit(Int32(gone))
        _ = exit(Int32(0))
    assert_true(child > 0, "there is a child to try the pair in")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_store(0, 0)
    assert_equal(waitpid(child, status, 0), child, "and it is waited for")
    assert_true(
        WIFEXITED(status.unsafe_load()),
        "init took the mess and destroy took the empty list, and "
        + "neither ended the child",
    )
    assert_equal(
        WEXITSTATUS(status.unsafe_load()),
        0,
        "and both calls answered 0 on the way out",
    )
    status.unsafe_free()


def main() raises:
    test_the_file_actions_take_a_mess_and_answer_for_it()
    test_posix_spawnp_runs_the_program_its_arguments_name()
    test_posix_spawn_answers_for_a_path_that_is_not_there()
    test_posix_spawn_refuses_a_name_with_no_path_in_it()
    test_the_attributes_are_a_block_the_call_cleans()
    test_the_file_actions_hand_the_child_a_pipe_for_its_output()
    test_the_file_actions_open_a_file_where_the_child_would_write()
    test_the_attributes_hold_the_group_and_the_flags_they_are_given()
    test_the_signal_sets_the_handle_is_given_come_back_out()
    test_the_two_signal_sets_are_two_things()
    print("test_spawn: ok")
