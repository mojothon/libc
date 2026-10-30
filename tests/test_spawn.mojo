"""Tests for the `libc.spawn` bindings.

`posix_spawn` starts a process without `fork`. Each test asks it to do
something that can then be looked at: run `sh -c 'exit 7'` and hand an
exit code back, or write into a pipe whose other end is held here.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_int, c_ptr, c_short
from libc.file import close, read
from libc.sched import SCHED_OTHER, sched_param
from libc.spawn import (
    POSIX_SPAWN_SETPGROUP,
    posix_spawn,
    posix_spawn_file_actions_addclose,
    posix_spawn_file_actions_adddup2,
    posix_spawn_file_actions_destroy,
    posix_spawn_file_actions_init,
    posix_spawn_file_actions_t,
    posix_spawnattr_destroy,
    posix_spawnattr_getflags,
    posix_spawnattr_getpgroup,
    posix_spawnattr_getschedparam,
    posix_spawnattr_getschedpolicy,
    posix_spawnattr_init,
    posix_spawnattr_setflags,
    posix_spawnattr_setpgroup,
    posix_spawnattr_setschedparam,
    posix_spawnattr_setschedpolicy,
    posix_spawnattr_t,
    posix_spawnp,
)
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.unistd import pipe
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


def test_the_attributes_hold_the_scheduling_they_are_given() raises:
    """The priority and the policy the new process is to start under,
    put in and read back the way the group is.

    The priority is the one that pins these down. Five goes in and
    five comes back, and five is not what a fresh handle holds, so a
    getter that had been given nothing to read would not have
    answered five. What is more, the block is written over with
    something else between the putting in and the reading back, so
    the five that comes back is the one the getter wrote and not one
    the setter left lying there.

    The policy is asked the same way, except that what is asked for
    has to be a `SCHED_*` from `libc.sched` and not a number written
    down: `SCHED_OTHER` is 0 on glibc and 1 on Darwin, so the two are
    named here rather than counted.
    """
    var attr = unsafe_alloc[posix_spawnattr_t](1)
    assert_equal(Int(posix_spawnattr_init(attr)), 0, "the handle is ready")

    var param = unsafe_alloc[sched_param](1)
    var policy = unsafe_alloc[c_int](1)

    assert_equal(
        Int(posix_spawnattr_getschedparam(attr, param)), 0, "a fresh one reads"
    )
    assert_equal(
        Int(posix_spawnattr_getschedpolicy(attr, policy)), 0, "and so does this"
    )

    param.unsafe_offset(0)[].set_sched_priority(5)
    assert_equal(
        Int(posix_spawnattr_setschedparam(attr, param)), 0, "five goes in"
    )
    param.unsafe_offset(0)[].set_sched_priority(-1)
    assert_equal(
        Int(posix_spawnattr_getschedparam(attr, param)), 0, "and is read back"
    )
    assert_equal(
        param.unsafe_offset(0)[].sched_priority(),
        5,
        "five, and not the -1 the block was written over with",
    )

    assert_equal(
        Int(posix_spawnattr_setschedpolicy(attr, SCHED_OTHER)),
        0,
        "the policy this platform calls the default one",
    )
    policy.unsafe_offset(0)[] = -1
    assert_equal(
        Int(posix_spawnattr_getschedpolicy(attr, policy)), 0, "and is read back"
    )
    assert_equal(
        Int(policy.unsafe_offset(0)[]),
        Int(SCHED_OTHER),
        "the one it was given, named rather than counted",
    )

    assert_equal(Int(posix_spawnattr_destroy(attr)), 0, "and released")

    attr.unsafe_free()
    param.unsafe_free()
    policy.unsafe_free()


def main() raises:
    test_posix_spawnp_runs_the_program_its_arguments_name()
    test_posix_spawn_answers_for_a_path_that_is_not_there()
    test_the_file_actions_hand_the_child_a_pipe_for_its_output()
    test_the_attributes_hold_the_group_and_the_flags_they_are_given()
    test_the_attributes_hold_the_scheduling_they_are_given()
    print("test_spawn: ok")
