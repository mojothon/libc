from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import EINTR, EINVAL, c_ptr
from libc.errno import get_errno, set_errno
from libc.signal import (
    SA_RESTART,
    SIGALRM,
    SIGINT,
    SIGWINCH,
    SIG_DFL,
    SIG_IGN,
    SIG_UNBLOCK,
    SIGUSR1,
    SIGUSR2,
    SIG_BLOCK,
    craise,
    kill,
    killpg,
    psignal,
    sigaction,
    SIGSTKSZ,
    sigaction_t,
    sigaddset,
    stack_t,
    sigblock,
    sigaltstack,
    sigdelset,
    sigemptyset,
    sigfillset,
    siginterrupt,
    sigismember,
    sigsetmask,
    sigsuspend,
    sigwait,
    sigpending,
    sigprocmask,
)
from libc.stdlib import exit
from libc.sys.wait import WEXITSTATUS, WIFEXITED, WIFSIGNALED, WTERMSIG, waitpid
from libc.unistd import close, fork, getpgrp, getpid, pipe, read, ualarm, write
from libc.utils import null_ptr, string_to_char_ptr


def empty_set() -> c_ptr[UInt8]:
    """A zeroed block big enough for either platform's `sigset_t`."""
    var mask = unsafe_alloc[UInt8](128)
    for i in range(128):
        mask.unsafe_store(i, UInt8(0))
    _ = sigemptyset(mask)
    return mask


def test_sigaddset_round_trips_through_sigismember() raises:
    """Adding a signal is what `sigismember` then says yes about."""
    var mask = empty_set()
    assert_equal(sigismember(mask, SIGINT), 0, "an empty set holds nothing")

    assert_equal(sigaddset(mask, SIGINT), 0, "adding SIGINT succeeded")
    assert_equal(sigismember(mask, SIGINT), 1, "SIGINT is in the set now")

    assert_equal(sigdelset(mask, SIGINT), 0, "removing SIGINT succeeded")
    assert_equal(sigismember(mask, SIGINT), 0, "and it is gone again")


def test_sigismember_refuses_a_number_that_is_not_a_signal() raises:
    """Asking about a number no platform has answers -1, not 0."""
    var mask = empty_set()
    set_errno(0)
    assert_equal(sigismember(mask, Int32(100000)), -1, "not a signal here")
    assert_equal(get_errno(), EINVAL, "errno says which way it went wrong")

    set_errno(0)
    assert_equal(sigaddset(mask, Int32(100000)), -1, "nothing was added")
    assert_equal(get_errno(), EINVAL, "errno says which way it went wrong")


def test_sigpending_reports_an_empty_set_when_nothing_waits() raises:
    """Whatever is waiting, asking about it succeeds and uses the set."""
    var mask = empty_set()
    var waiting = empty_set()
    assert_equal(sigpending(waiting), 0, "sigpending succeeded")

    # A signal nobody is blocking has nowhere pending to be, so ask about
    # one using the empty mask rather than whatever it wrote down.
    assert_equal(
        sigismember(waiting, SIGINT), 0, "SIGINT is not waiting to be delivered"
    )
    _ = mask


comptime SET_SIZE = 128


def test_sigfillset_fills() raises:
    """`sigfillset` puts every signal into the set it is given. What
    that leaves is bytes that are not zeroes, and a set that was
    cleared first is the only way of knowing they came from it.
    """
    var set = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        set.unsafe_store(i, 0)

    assert_equal(sigfillset(set), 0, "sigfillset answers 0")
    assert_true(
        Int(set.unsafe_load(0)) != 0,
        "and what was zeroed is no longer zero",
    )
    set.unsafe_free()


def test_sigprocmask_read_twice_reads_the_same() raises:
    """`sigprocmask` is told what to do with a set and hands back the
    mask as it was before. Given `SIG_BLOCK` and a set with nothing in
    it, it blocks nothing and changes nothing, so it can be asked
    twice and the answer is the same both times — and the same as when
    it is given no set at all, which is how it is asked to only read.

    A test that blocked a signal and did not put the mask back would
    leave the process changed for everything after it, so none is
    blocked here.
    """
    var nothing = unsafe_alloc[UInt8](SET_SIZE)
    var first = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        nothing.unsafe_store(i, 0)
        first.unsafe_store(i, 0)

    assert_equal(
        sigprocmask(SIG_BLOCK, nothing, first), 0, "the mask is read once"
    )

    var second = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        second.unsafe_store(i, 0)
    assert_equal(sigprocmask(SIG_BLOCK, nothing, second), 0, "and again")

    for i in range(SET_SIZE):
        assert_equal(
            Int(first.unsafe_load(i)),
            Int(second.unsafe_load(i)),
            "and it reads the same both times",
        )

    var third = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        third.unsafe_store(i, 0)
    assert_equal(
        sigprocmask(SIG_BLOCK, null_ptr[UInt8](), third),
        0,
        "and asked with no set at all it still answers",
    )
    for i in range(SET_SIZE):
        assert_equal(
            Int(first.unsafe_load(i)),
            Int(third.unsafe_load(i)),
            "and says the same as when it was given one",
        )

    nothing.unsafe_free()
    first.unsafe_free()
    second.unsafe_free()
    third.unsafe_free()


def test_kill_with_nothing_to_send() raises:
    """Signal 0 sends nothing. `kill` with it only asks whether the
    process is there, and answers 0 when it is.
    """
    var me = getpid()
    assert_true(me > 0, "there is a process")
    assert_equal(kill(me, 0), 0, "kill with signal 0 asks and sends nothing")


def test_sigaltstack_asked_and_told_nothing() raises:
    """`sigaltstack` given nothing to install has nothing to do but
    say what the alternate stack is, which for a process that never
    set one is: there is not one.
    """
    assert_equal(
        sigaltstack(null_ptr[stack_t](), null_ptr[stack_t]()),
        0,
        "sigaltstack answers when given nothing",
    )


def test_sigaltstack_installs_a_stack_and_puts_it_back() raises:
    """The two arguments are the pair `sigaction`'s test is about: one is
    what to install, the other is where to write what is already there,
    they are the same type, and the null call above answers 0 with them
    either way round.

    So a stack is installed and asked for. Nothing installs an action
    with `SA_ONSTACK`, so no signal is ever delivered on it: it is a
    block of memory C is told about and then told to forget.
    """
    var before = unsafe_alloc[stack_t](1)
    before.unsafe_offset(0)[] = stack_t()
    assert_equal(
        sigaltstack(null_ptr[stack_t](), before),
        0,
        "a process can be asked what its stack is",
    )
    # What the answer is is not asserted: this is not a process that never set
    # one. The runtime puts a handler on `SIGUSR1` and an alternate stack under
    # it, so the first read is what "put back" is measured against rather than
    # zero.

    # `SIGSTKSZ` is what the platforms ask for at least, and the least is
    # enough: nothing is going to run on this stack.
    var room = unsafe_alloc[UInt8](Int(SIGSTKSZ))
    var wanted = unsafe_alloc[stack_t](1)
    wanted.unsafe_offset(0)[] = stack_t()
    wanted[].set_sp(UInt64(UInt(room)))
    wanted[].set_size(UInt64(UInt(SIGSTKSZ)))
    assert_equal(
        sigaltstack(wanted, null_ptr[stack_t]()), 0, "the stack is installed"
    )

    var now = unsafe_alloc[stack_t](1)
    now.unsafe_offset(0)[] = stack_t()
    assert_equal(
        sigaltstack(null_ptr[stack_t](), now),
        0,
        "and asked what it is",
    )

    # Put back before the answers are judged, so that a failure here cannot
    # leave the process with a stack pointing at memory about to be freed.
    assert_equal(
        sigaltstack(before, null_ptr[stack_t]()),
        0,
        "and taken away again",
    )

    # Three members, and both that had to make the trip out and back: a
    # binding handing the two arguments over swapped installs what `before`
    # held, which is no stack at all -- `ss_sp` is NULL with no `SS_DISABLE`
    # -- and is refused with EINVAL.
    assert_equal(
        now[].sp(), wanted[].sp(), "the stack in force is where it was put"
    )
    assert_equal(
        now[].size(), UInt64(UInt(SIGSTKSZ)), "and as long as it was made"
    )

    # And the restore put back what was there, read once more.
    assert_equal(
        sigaltstack(null_ptr[stack_t](), now),
        0,
        "and asked again after the restore",
    )
    assert_equal(
        now[].sp(), before[].sp(), "which is the stack it had when it started"
    )

    now.unsafe_free()
    wanted.unsafe_free()
    room.unsafe_free()
    before.unsafe_free()


def test_sigaction_asked_and_told_nothing() raises:
    """`sigaction` given nothing to install and nowhere to put what
    is already there has nothing to do but check the signal is one
    there is such a thing as, which is what it answers about.
    """
    assert_equal(
        sigaction(SIGINT, null_ptr[sigaction_t](), null_ptr[sigaction_t]()),
        0,
        "sigaction answers for a signal there is such a thing as",
    )
    assert_equal(
        sigaction(0, null_ptr[sigaction_t](), null_ptr[sigaction_t]()),
        -1,
        "and refuses one there is not",
    )


def test_sigaction_installs_an_ignore_and_puts_it_back() raises:
    """The two arguments are the easiest pair in this suite to swap: one is
    what to install, the other is where to write what is already installed,
    they are the same type, and a call that only reads returns 0 just as a
    call that only writes does.

    So the signal is told to be ignored, then asked what it is doing, and the
    two answers have to agree with each other and disagree with what it was
    before. `SIGWINCH` is borrowed for it: nothing sends one, its default is
    to be thrown away, and it is given back at the end -- the disposition
    belongs to the process and the suite runs in one.
    """
    var before = unsafe_alloc[sigaction_t](1)
    before.unsafe_offset(0)[] = sigaction_t()
    assert_equal(
        sigaction(SIGWINCH, null_ptr[sigaction_t](), before),
        0,
        "a signal can be asked what it is doing without being changed",
    )
    assert_equal(
        before[].handler(), UInt64(SIG_DFL), "which is the default, untouched"
    )

    var ignore = unsafe_alloc[sigaction_t](1)
    ignore.unsafe_offset(0)[] = sigaction_t()
    ignore[].set_handler(UInt64(SIG_IGN))
    ignore[].set_flags(SA_RESTART)
    assert_equal(
        sigaction(SIGWINCH, ignore, null_ptr[sigaction_t]()),
        0,
        "the signal is told to be ignored",
    )

    var now = unsafe_alloc[sigaction_t](1)
    now.unsafe_offset(0)[] = sigaction_t()
    assert_equal(
        sigaction(SIGWINCH, null_ptr[sigaction_t](), now),
        0,
        "and asked what it is doing",
    )

    # The word at the front is the handler and the word behind the mask is the
    # flags: both had to make the trip out to the kernel and back for these to
    # hold, and neither comes back if the two arguments went over the other way
    # round -- the install would have been a read and the read an install.
    assert_equal(now[].handler(), UInt64(SIG_IGN), "the ignore is in force")
    # `SA_RESTART` is asked for and found, but the flags are not echoed back as
    # they were handed over: glibc adds `SA_RESTORER` (0x04000000) of its own
    # when it installs an action, because the restorer is part of how it gets
    # control back. So the question is whether the bit asked for is in there,
    # not whether it is the only one.
    assert_true(
        (now[].flags() & SA_RESTART) != 0,
        "and the flag asked for is among them",
    )

    # Put back, and asked once more: the disposition belongs to the process and
    # the suite runs in one, so leaving a signal ignored is not an option.
    assert_equal(
        sigaction(SIGWINCH, before, null_ptr[sigaction_t]()),
        0,
        "put back the way it was found",
    )
    assert_equal(
        sigaction(SIGWINCH, null_ptr[sigaction_t](), now),
        0,
        "and asked what it is doing now",
    )
    assert_equal(
        now[].handler(),
        before[].handler(),
        "which is what the first read said it was",
    )

    ignore.unsafe_free()
    now.unsafe_free()
    before.unsafe_free()


def test_craise_with_nothing_to_send() raises:
    """`craise` sends a signal to whoever called it. Signal 0 sends
    nothing at all, so it is the one that can be asked for here:
    every other number either ends the process or is a thing this
    test cannot say what it would do.
    """
    assert_equal(craise(0), 0, "craise with signal 0 sends nothing and says so")


def test_signal_zero_asks_whether_a_group_is_there() raises:
    """`killpg` sends a signal to a process group. It is asked with
    signal 0, which sends nothing at all and only asks whether the
    group is there.

    What is asked is that this process's own group is there and that
    a group which cannot be is not: the first answers 0 and the
    second -1.

    The second of those is what pins the two arguments apart. A
    group of 0 means this process's own group as well, so asked the
    wrong way round `killpg(-1, 0)` would be `killpg(0, -1)` — a
    group that is there being sent a signal that is not one — which
    answers -1 for the wrong reason.

    `psignal` and `siginterrupt` are called because they are there
    and not because either can be asked anything: the first writes
    what a signal's number means and says nothing back, and the
    second says whether a slow call is to be woken by a signal or
    carry on after it. What `psignal` writes is each platform's own
    to say, so it is not written down here.

    Nothing is sent, so the process these tests run in is not
    disturbed by any of this.
    """
    assert_equal(
        killpg(Int32(getpgrp()), 0), 0, "this process's own group is there"
    )
    assert_equal(killpg(-1, 0), -1, "and a group that cannot be is not")

    var doing = string_to_char_ptr("nothing to report")
    psignal(SIGINT, doing)
    assert_equal(siginterrupt(SIGINT, 0), 0, "and siginterrupt is there too")

    doing.unsafe_free()


def test_the_blocked_set_as_a_word_and_as_bytes() raises:
    """`sigblock` and `sigsetmask` keep the same mask `sigprocmask` keeps,
    said as one word instead of a set of bytes.

    The two are asked of each other: every bit of the word is compared
    with the byte it belongs in, for the thirty-one signals a word can
    hold, so a word that meant something else would be caught before it
    was used.

    Then one signal the set does not hold is blocked, and the bytes are
    read again to find it there; the set is put back, and the bytes say
    it is gone. That is the whole of how these two are used — save the
    answer, hand it back — and it is what says the answer is the set.
    """
    var start = sigblock(0)
    assert_true(start >= 0, "blocking nothing answers with the set in place")

    var nothing = empty_set()
    var was = unsafe_alloc[UInt8](128)
    assert_equal(
        sigprocmask(SIG_BLOCK, nothing, was), 0, "and the mask is read as bytes"
    )
    for number in range(1, 32):
        var index = (number - 1) // 8
        var offset = (number - 1) % 8
        assert_equal(
            (Int(start) >> (number - 1)) & 1,
            (Int(was.unsafe_offset(index)[]) >> offset) & 1,
            "the word and the bytes say the same about a signal",
        )

    var chosen = Int(SIGUSR1)
    var bit = Int32(1) << (SIGUSR1 - 1)
    if (start & bit) != 0:
        chosen = Int(SIGUSR2)
        bit = Int32(1) << (SIGUSR2 - 1)
    assert_equal(
        (Int(start) >> (chosen - 1)) & 1, 0, "one of the two is not in the set"
    )

    assert_equal(
        sigblock(bit), start, "blocking it answers with the set before it"
    )
    assert_equal(
        sigprocmask(SIG_BLOCK, nothing, was), 0, "and the bytes are read"
    )
    assert_equal(
        (Int(was.unsafe_offset((chosen - 1) // 8)[]) >> ((chosen - 1) % 8)) & 1,
        1,
        "where the signal is now blocked",
    )

    assert_equal(
        sigsetmask(start),
        start | bit,
        "putting the set back answers with the one it replaced",
    )
    assert_equal(
        sigprocmask(SIG_BLOCK, nothing, was), 0, "and the bytes are read again"
    )
    assert_equal(
        (Int(was.unsafe_offset((chosen - 1) // 8)[]) >> ((chosen - 1) % 8)) & 1,
        0,
        "where it is no longer blocked",
    )
    assert_equal(sigblock(0), start, "and the word is the one it started as")

    was.unsafe_free()
    nothing.unsafe_free()


def test_sigwait_takes_one_that_is_already_waiting() raises:
    """`sigwait` waits for a signal to arrive, and a suite that waits
    is one that hangs — unless the signal is already there. It is put
    there on purpose: `SIGUSR1` is blocked, so sending it to this
    process leaves it pending, and `sigpending` says so before
    `sigwait` is asked anything. Then taking it is no waiting at all,
    and the answer says which one was taken. The block is undone at
    the end, the signal being spent.
    """
    var mask = empty_set()
    assert_equal(sigemptyset(mask), 0, "an empty set to start from")
    assert_equal(sigaddset(mask, SIGUSR1), 0, "with SIGUSR1 in it")
    assert_equal(
        sigprocmask(SIG_BLOCK, mask, null_ptr[UInt8]()),
        0,
        "SIGUSR1 is blocked",
    )
    assert_equal(craise(SIGUSR1), 0, "and sent, to sit pending")

    var pending = empty_set()
    assert_equal(sigpending(pending), 0, "the pending set answers")
    assert_equal(sigismember(pending, SIGUSR1), 1, "and SIGUSR1 is in it")

    var which = unsafe_alloc[Int32](1)
    which.unsafe_offset(0)[] = 0
    assert_equal(sigwait(mask, which), 0, "so sigwait takes it at once")
    assert_equal(which.unsafe_offset(0)[], SIGUSR1, "and says which one it was")
    assert_equal(
        sigprocmask(SIG_UNBLOCK, mask, null_ptr[UInt8]()),
        0,
        "and the block is undone",
    )
    which.unsafe_free()
    pending.unsafe_free()
    mask.unsafe_free()


def test_sigsuspend_swaps_in_a_mask_and_takes_what_was_waiting() raises:
    """`sigsuspend` waits under a mask of its own choosing, and the
    signal it waits for here is already waiting: whether it is ever
    delivered is the whole of what the call is.

    In the child `SIGUSR1` is blocked and then sent to itself, so it
    sits pending -- blocked signals are held, not delivered -- and
    `sigpending` is asked to say so before anything waits. `sigsuspend`
    is then handed an empty set, which is to say nothing blocked, and
    the swap is what delivers it. What the delivery does to the child
    is not this test's business and is not the same everywhere: this
    process has a handler for `SIGUSR1` (so the call comes back with
    `EINTR` and takes the pending signal with it), and a build without
    one is ended by it instead. Both are the signal arriving, and the
    child says which happened by a byte down a pipe: written if the
    call came back.

    "Something else" is the alarm, one second and blocked as well. A
    `sigsuspend` that failed to take the mask would leave `SIGUSR1`
    where it was and be woken by that instead, and the parent finds
    `SIGALRM` rather than `SIGUSR1` -- a name it can tell apart, rather
    than a run that stops here until the job times out.
    """
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "a pipe to say what became of the wait")
    var child = fork()
    if child == 0:
        _ = close(fds.unsafe_offset(0)[])

        var held = empty_set()
        _ = sigaddset(held, SIGUSR1)
        _ = sigaddset(held, SIGALRM)
        _ = sigprocmask(SIG_BLOCK, held, null_ptr[UInt8]())
        _ = craise(SIGUSR1)

        var waiting = empty_set()
        assert_equal(sigpending(waiting), 0, "the pending set answers")
        assert_equal(
            sigismember(waiting, SIGUSR1), 1, "and SIGUSR1 is held in it"
        )
        _ = ualarm(1000000, 0)

        var swap = empty_set()
        var answer = sigsuspend(swap)
        var why = get_errno()

        var said = unsafe_alloc[UInt8](1)
        said.unsafe_store(0, UInt8(1))
        assert_equal(
            write(fds.unsafe_offset(1)[], said, 1), 1, "the wait came back"
        )
        said.unsafe_free()

        assert_equal(answer, -1, "and it came back the only way it can")
        assert_equal(why, EINTR, "interrupted, which is a signal arriving")
        var after = empty_set()
        _ = sigpending(after)
        assert_equal(
            sigismember(after, SIGUSR1),
            0,
            "the one that was held, which it has taken with it",
        )
        _ = exit(0)

    _ = close(fds.unsafe_offset(1)[])
    assert_true(child > 0, "there is a child to wait for")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")

    var said = unsafe_alloc[UInt8](1)
    said.unsafe_store(0, UInt8(0))
    var came_back = read(fds.unsafe_offset(0)[], said, 1)
    said.unsafe_free()

    if came_back == 1:
        assert_true(
            WIFEXITED(status.unsafe_load()),
            "the call came back, and the child left on its own",
        )
        assert_equal(
            Int(WEXITSTATUS(status.unsafe_load())),
            0,
            "with the pending signal taken, not with the alarm",
        )
    else:
        assert_true(
            WIFSIGNALED(status.unsafe_load()), "something ended the child"
        )
        assert_equal(
            WTERMSIG(status.unsafe_load()),
            SIGUSR1,
            "the signal that was pending, not the alarm that was there in case",
        )

    status.unsafe_free()
    fds.unsafe_free()


def main() raises:
    test_sigaddset_round_trips_through_sigismember()
    test_sigismember_refuses_a_number_that_is_not_a_signal()
    test_sigpending_reports_an_empty_set_when_nothing_waits()
    test_sigfillset_fills()
    test_sigprocmask_read_twice_reads_the_same()
    test_kill_with_nothing_to_send()
    test_sigaltstack_asked_and_told_nothing()
    test_sigaltstack_installs_a_stack_and_puts_it_back()
    test_sigaction_asked_and_told_nothing()
    test_sigaction_installs_an_ignore_and_puts_it_back()
    test_craise_with_nothing_to_send()
    test_the_blocked_set_as_a_word_and_as_bytes()
    test_signal_zero_asks_whether_a_group_is_there()
    test_sigwait_takes_one_that_is_already_waiting()
    test_sigsuspend_swaps_in_a_mask_and_takes_what_was_waiting()
    print("signal ok")
