from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_long, c_ptr, c_void
from libc.signal import SIGKILL, kill
from libc.stdlib import _Exit
from libc.sys.wait import WEXITSTATUS, WIFEXITED, WNOHANG, waitpid
from libc.time import CLOCK_MONOTONIC, CLOCK_REALTIME, clock_gettime, timespec
from libc.threads import (
    call_once,
    cnd_broadcast,
    cnd_destroy,
    cnd_init,
    cnd_signal,
    cnd_timedwait,
    cnd_t,
    cnd_wait,
    mtx_destroy,
    mtx_init,
    mtx_lock,
    mtx_plain,
    mtx_t,
    mtx_timed,
    mtx_timedlock,
    mtx_trylock,
    mtx_unlock,
    once_flag,
    thrd_busy,
    thrd_create,
    thrd_current,
    thrd_detach,
    thrd_equal,
    thrd_exit,
    thrd_join,
    thrd_sleep,
    thrd_success,
    thrd_timedout,
    thrd_yield,
    tss_create,
    tss_delete,
    tss_get,
    tss_set,
    tss_t,
    thrd_t,
)
from libc.unistd import close, dup2, fork, pipe, read, usleep, write
from libc.utils import is_null, null_ptr, string_to_char_ptr

# What one side of a handshake may wait before deciding the other is not
# coming. Long enough that a loaded machine still passes; short enough
# that a broken wake costs a fraction of a second rather than a hang.
comptime THE_PATIENCE_MS: Int = 500


def the_first_one() -> None:
    """What `call_once` is given: one byte out of slot 20, where the
    test parked the write end of a pipe.

    There is no argument and nothing captured, which is the point -- a
    once function gets nothing but the chance to run.
    """
    _ = write(20, string_to_char_ptr("x"), 1)


def no_dtor(arg: c_ptr[c_void]) -> None:
    """A thread-local destructor that has nothing to do, standing in for
    the null pointer C would pass for a slot with nothing to clean up.

    Args:
        arg: The value going out of scope, which this does not touch.
    """
    _ = arg


def probe_run(arg: c_ptr[c_void]) -> Int32:
    """What the probe thread runs: writes its own ID and a mark into the
    block it is handed, and answers 42.

    Args:
        arg: The block, as a `void *`.

    Returns:
        42, which is what `thrd_join` reads back.
    """
    var block = arg.unsafe_bitcast[UInt8]()
    block.unsafe_bitcast[thrd_t]().unsafe_offset(0)[] = thrd_current()
    block.unsafe_offset(8)[] = 0x5A
    return 42


def probe_leaves_early(arg: c_ptr[c_void]) -> Int32:
    """What the second thread runs: it ends through `thrd_exit` rather
    than by returning, so that what the join reads can only have come
    from that call.

    Args:
        arg: Unused.

    Returns:
        Never anything: the call above does not come back.
    """
    _ = thrd_exit(9)
    return 7


def probe_detached(arg: c_ptr[c_void]) -> Int32:
    """What the detached thread runs, which is nothing anyone waits
    for.

    Args:
        arg: Unused.

    Returns:
        0, which nobody reads.
    """
    _ = arg
    return 0


def probe_waiter(arg: c_ptr[c_void]) -> Int32:
    """What the waiter thread runs, in the handshake that proves a
    mutex guards and a condition variable wakes.

    The block it is handed holds the pair and the record: the mutex at
    offset 0, the condition variable at 48, the flag at 96, and what
    its take answered at 100. The flag is its side of the ordering: 1
    says it is about to ask for the mutex -- which it does while this
    side still holds it, so the ask is made against a held lock and
    cannot be answered by anything but a wait -- and 2 says the ask was
    answered and the flag it signals about is up.

    Args:
        arg: The block, as a `void *`.

    Returns:
        7, which is what `thrd_join` reads back.
    """
    var block = arg.unsafe_bitcast[UInt8]()
    var mtx = block.unsafe_bitcast[mtx_t]()
    var cnd = block.unsafe_offset(48).unsafe_bitcast[cnd_t]()
    var flag = block.unsafe_offset(96).unsafe_bitcast[Int32]()

    flag.unsafe_offset(0)[] = 1
    var took = mtx_lock(mtx)
    block.unsafe_offset(100).unsafe_bitcast[Int32]().unsafe_offset(0)[] = took
    flag.unsafe_offset(0)[] = 2
    _ = cnd_signal(cnd)
    _ = cnd_wait(cnd, mtx)
    flag.unsafe_offset(0)[] = 0
    _ = mtx_unlock(mtx)
    return 7


def probe_tss(arg: c_ptr[c_void]) -> Int32:
    """What the slot's second user runs: puts a pointer of its own in
    the slot, one the first user does not know, which the first user
    must not be able to read.

    Args:
        arg: The key at offset 0 and the pointer to set at offset 8.

    Returns:
        0, which is what `thrd_join` reads back.
    """
    var block = arg.unsafe_bitcast[UInt8]()
    var key = block.unsafe_bitcast[tss_t]().unsafe_offset(0)[]
    var other = (
        block.unsafe_offset(8).unsafe_bitcast[c_ptr[UInt8]]().unsafe_offset(0)[]
    )
    _ = tss_set(key, other.unsafe_bitcast[c_void]())
    return 0


def ms_from_now(ms: Int) -> timespec:
    """A deadline `ms` from now on the wall clock, which is what
    `mtx_timedlock` and `cnd_timedwait` ask for: an absolute time, not
    a wait.

    Args:
        ms: How far ahead, in milliseconds.

    Returns:
        The deadline as a `timespec`.
    """
    var stamp = unsafe_alloc[timespec](1)
    _ = clock_gettime(CLOCK_REALTIME, stamp)
    var when = stamp.unsafe_offset(0)[]
    when.tv_nsec += c_long(ms) * 1000000
    when.tv_sec += when.tv_nsec // 1000000000
    when.tv_nsec = when.tv_nsec % 1000000000
    stamp.unsafe_free()
    return when


def clock_seconds() -> Int:
    """The wall clock in whole seconds, for deadlines that only have to
    say whether twenty of them have gone by.

    Returns:
        `CLOCK_REALTIME` as seconds.
    """
    var stamp = unsafe_alloc[timespec](1)
    _ = clock_gettime(CLOCK_REALTIME, stamp)
    var seconds = Int(stamp.unsafe_offset(0)[].tv_sec)
    stamp.unsafe_free()
    return seconds


def watch_the_child(pid: Int32, what: String) raises:
    """Waits four seconds for a forked child and reads its ending.

    The exercises this runs alongside are ones where a call that goes
    wrong does not answer wrongly but stops answering -- a lock taken
    twice by the same thread asks to wait for itself. In the child that
    is survivable; the parent kills it and says so, which turns a stop
    answering into something the suite can catch.

    Args:
        pid: The child to wait for.
        what: What to call it in the failure message.
    """
    var status = unsafe_alloc[Int32](1)
    var done = False
    for i in range(400):
        if waitpid(pid, status, WNOHANG) == pid:
            done = True
            break
        _ = usleep(10000)
    if not done:
        _ = kill(pid, SIGKILL)
        _ = waitpid(pid, status, 0)
        status.unsafe_free()
        assert_true(False, what + " stopped answering and had to be killed")
    assert_true(WIFEXITED(status.unsafe_offset(0)[]), what + " ended by itself")
    assert_equal(
        WEXITSTATUS(status.unsafe_offset(0)[]), 0, "and ended saying it passed"
    )
    status.unsafe_free()


def the_mutex_exercise() raises:
    """A mutex made plain locks, refuses a second take, and lets go; one
    made timed is the only kind whose timed take can answer
    `thrd_timedout`, and it does while somebody else holds it.

    Every answer on the way is checked, because a lock that answered
    success without taking would pass a test that only looked at the
    end state -- and the try that comes back `thrd_busy` is the one
    claim here that could not be true of a lock nobody was holding.
    """
    var plain = unsafe_alloc[mtx_t](1)
    assert_equal(
        mtx_init(plain, mtx_plain), thrd_success, "a plain mutex is made"
    )
    assert_equal(mtx_lock(plain), thrd_success, "and taken")
    assert_equal(
        mtx_trylock(plain),
        thrd_busy,
        "a second take says busy rather than waiting",
    )
    assert_equal(mtx_unlock(plain), thrd_success, "and letting go says so")
    assert_equal(
        mtx_trylock(plain),
        thrd_success,
        "a free mutex is taken without waiting",
    )
    assert_equal(mtx_unlock(plain), thrd_success, "and let go again")
    _ = mtx_destroy(plain)
    plain.unsafe_free()

    var timed = unsafe_alloc[mtx_t](1)
    assert_equal(
        mtx_init(timed, mtx_timed), thrd_success, "a timed mutex is made"
    )
    assert_equal(mtx_lock(timed), thrd_success, "and held")
    var deadline = unsafe_alloc[timespec](1)
    deadline.unsafe_offset(0)[] = ms_from_now(50)
    assert_equal(
        mtx_timedlock(timed, deadline),
        thrd_timedout,
        "a held timed mutex answers timeout rather than waiting",
    )
    assert_equal(mtx_unlock(timed), thrd_success, "let go")
    assert_equal(
        mtx_timedlock(timed, deadline),
        thrd_success,
        "a free one is taken before the deadline",
    )
    assert_equal(mtx_unlock(timed), thrd_success, "and let go")
    _ = mtx_destroy(timed)
    deadline.unsafe_free()
    timed.unsafe_free()


def one_handshake(wake: def(c_ptr[cnd_t]) thin -> Int32, which: String) raises:
    """One waiter, one condition variable, one wake.

    Both directions are proven, in an order that cannot race. This side
    holds the mutex when the waiter is started; the waiter raises its
    flag and asks for the mutex while it is still held -- so its ask can
    only be answered by a wait, and what it answered comes back in the
    record. Then this side waits on the condition variable, which is
    what lets go of the mutex and lets the waiter in; the waiter sets
    its second flag and signals, waking this side out of its timed
    wait. The atomic half of the wait is the proof the wake cannot be
    lost: this side cannot come back holding the mutex until the waiter
    has let go of it, and letting go and sleeping are one step, so the
    wake sent from inside the lock reaches a waiter that is already
    asleep. A signal that arrives before anybody waits is a signal
    lost, and this order is what makes losing one impossible.

    Args:
        wake: What is to do the waking, which is `cnd_signal` once and
            `cnd_broadcast` once.
        which: What to call the wake in the failure message.
    """
    var room = unsafe_alloc[UInt8](104)
    for i in range(104):
        room.unsafe_offset(i)[] = 0
    var mtx = room.unsafe_bitcast[mtx_t]()
    var cnd = room.unsafe_offset(48).unsafe_bitcast[cnd_t]()
    var flag = room.unsafe_offset(96).unsafe_bitcast[Int32]()
    assert_equal(
        mtx_init(mtx, mtx_plain), thrd_success, "the pair's mutex is made"
    )
    assert_equal(cnd_init(cnd), thrd_success, "and its condition variable")
    assert_equal(mtx_lock(mtx), thrd_success, "this side takes it first")

    var id = unsafe_alloc[thrd_t](1)
    var waiter: def(c_ptr[c_void]) thin -> Int32 = probe_waiter
    assert_equal(
        thrd_create(id, waiter, room.unsafe_bitcast[c_void]()),
        thrd_success,
        "the waiter is started",
    )

    var until = clock_seconds() + 20
    while flag.unsafe_offset(0)[] == 0:
        assert_true(
            clock_seconds() < until, "the waiter never got as far as asking"
        )
        _ = thrd_yield()

    var deadline = unsafe_alloc[timespec](1)
    deadline.unsafe_offset(0)[] = ms_from_now(THE_PATIENCE_MS)
    assert_equal(
        cnd_timedwait(cnd, mtx, deadline),
        thrd_success,
        "the waiter's signal came before the deadline",
    )
    assert_equal(
        flag.unsafe_offset(0)[],
        2,
        "the flag it signals about is the one it raised",
    )
    assert_equal(wake(cnd), thrd_success, "and its sleep is woken by " + which)
    assert_equal(mtx_unlock(mtx), thrd_success, "so this side lets go")

    var answer = unsafe_alloc[Int32](1)
    assert_equal(
        thrd_join(id.unsafe_offset(0)[], answer),
        thrd_success,
        "the waiter is joined",
    )
    assert_equal(answer.unsafe_offset(0)[], 7, "with what it answered")
    assert_equal(
        room.unsafe_offset(100).unsafe_bitcast[Int32]().unsafe_offset(0)[],
        thrd_success,
        "the take it made against a held mutex waited and said success",
    )
    assert_equal(
        flag.unsafe_offset(0)[],
        0,
        "and it took the flag back down under the lock",
    )
    assert_equal(
        cnd_broadcast(cnd),
        thrd_success,
        "a broadcast to nobody still answers success",
    )

    _ = cnd_destroy(cnd)
    _ = mtx_destroy(mtx)
    answer.unsafe_free()
    deadline.unsafe_free()
    id.unsafe_free()
    room.unsafe_free()


def the_handshake_exercise() raises:
    """Two handshakes, one woken by a single signal and one by a
    broadcast to everybody, which is every way a condition variable can
    be woken.
    """
    one_handshake(cnd_signal, "the one signal")
    one_handshake(cnd_broadcast, "the broadcast")


def test_a_thread_answers_whether_it_worked() raises:
    """A thread is started, waited for, and asked who it was.

    Five claims, none of which one thread could have satisfied on its
    own: a byte it was told to write is there, the ID written beside it
    belongs to some other thread but `thrd_equal` says this thread is
    itself, the join read back the number the start routine answered,
    and the create and the join both said `thrd_success`.

    The block is only read after the join, which is what makes reading
    it without a lock honest: the thread that wrote it has ended, and
    the join is what says so.
    """
    comptime if not CompilationTarget.is_macos():
        var block = unsafe_alloc[UInt8](16)
        for i in range(16):
            block.unsafe_offset(i)[] = 0
        var id = unsafe_alloc[thrd_t](1)
        var start: def(c_ptr[c_void]) thin -> Int32 = probe_run
        assert_equal(
            thrd_create(id, start, block.unsafe_bitcast[c_void]()),
            thrd_success,
            "a thread is started",
        )
        var answer = unsafe_alloc[Int32](1)
        assert_equal(
            thrd_join(id.unsafe_offset(0)[], answer),
            thrd_success,
            "and waited for",
        )
        assert_equal(
            answer.unsafe_offset(0)[],
            42,
            "it answered what its routine returned",
        )
        assert_equal(
            Int(block.unsafe_offset(8)[]),
            0x5A,
            "the byte it was told to write is there",
        )
        assert_true(
            Int(thrd_equal(thrd_current(), thrd_current())) != 0,
            "this thread is itself",
        )
        assert_equal(
            Int(
                thrd_equal(
                    thrd_current(),
                    block.unsafe_bitcast[thrd_t]().unsafe_offset(0)[],
                )
            ),
            0,
            "and the ID it wrote is not this thread's",
        )
        answer.unsafe_free()
        id.unsafe_free()
        block.unsafe_free()


def test_a_thread_that_ends_through_thrd_exit() raises:
    """A thread that leaves by way of `thrd_exit` joins like one that
    returns, and the number the join reads is the one that call was
    given rather than what the routine returned.

    The routine is written to return 7 either way, so the value arriving
    says nothing about which path it took; what says so is that nothing
    was left on the stack for it to return through.
    """
    comptime if not CompilationTarget.is_macos():
        var id = unsafe_alloc[thrd_t](1)
        var start: def(c_ptr[c_void]) thin -> Int32 = probe_leaves_early
        assert_equal(
            thrd_create(id, start, null_ptr[c_void]()),
            thrd_success,
            "a thread that will leave early is started",
        )
        var answer = unsafe_alloc[Int32](1)
        assert_equal(
            thrd_join(id.unsafe_offset(0)[], answer),
            thrd_success,
            "and it joins like any other",
        )
        assert_equal(
            answer.unsafe_offset(0)[], 9, "with what thrd_exit was given"
        )
        answer.unsafe_free()
        id.unsafe_free()


def test_a_thread_nobody_joins_is_detached() raises:
    """A thread detached says so, and nobody waits for it.

    The thread is started with nothing to do, detached, and left to
    finish on its own; what is checked is that the library accepted the
    parting, which is the one thing about detaching that can be asked
    without waiting for a thread that is no longer anybody's.
    """
    comptime if not CompilationTarget.is_macos():
        var id = unsafe_alloc[thrd_t](1)
        var start: def(c_ptr[c_void]) thin -> Int32 = probe_detached
        assert_equal(
            thrd_create(id, start, null_ptr[c_void]()),
            thrd_success,
            "a thread is started",
        )
        assert_equal(
            thrd_detach(id.unsafe_offset(0)[]),
            thrd_success,
            "and is detached rather than joined",
        )
        id.unsafe_free()


def test_sleeping_takes_the_time_asked() raises:
    """A yield is offered and answered, and a sleep of five milliseconds
    lasts at least four of them.

    The lower bound is what can be claimed: the clock is read before
    and after on the same monotonic clock, and how much more than four
    milliseconds it took is the scheduler's business.
    """
    comptime if not CompilationTarget.is_macos():
        _ = thrd_yield()

        var before = unsafe_alloc[timespec](1)
        var after = unsafe_alloc[timespec](1)
        assert_equal(
            clock_gettime(CLOCK_MONOTONIC, before), 0, "the clock is read"
        )
        var duration = unsafe_alloc[timespec](1)
        duration.unsafe_offset(0)[] = timespec(0, 5000000)
        var left = unsafe_alloc[timespec](1)
        assert_equal(
            thrd_sleep(duration, left),
            0,
            "the whole sleep passed",
        )
        assert_equal(
            clock_gettime(CLOCK_MONOTONIC, after),
            0,
            "and the clock is read again",
        )
        var passed = Int(
            after.unsafe_offset(0)[].tv_sec - before.unsafe_offset(0)[].tv_sec
        )
        passed = passed * 1000000000
        passed += Int(
            after.unsafe_offset(0)[].tv_nsec - before.unsafe_offset(0)[].tv_nsec
        )
        assert_true(passed >= 4000000, "five milliseconds lasted at least four")
        before.unsafe_free()
        after.unsafe_free()
        left.unsafe_free()
        duration.unsafe_free()


def test_a_mutex_locks_and_times_out() raises:
    """The mutex exercise, run in a forked child and waited for under a
    deadline.

    The child is the point: a mutex that goes wrong here does not
    answer wrongly but stops answering -- a lock taken twice by the
    same thread asks to wait for itself -- and a suite that ran that in
    its own process would hang rather than fail. In the child a hang is
    four seconds of waiting and a kill, which the parent reports the
    way it reports any other broken answer.
    """
    comptime if not CompilationTarget.is_macos():
        var pid = fork()
        assert_true(pid >= 0, "a child is forked to run the exercise in")
        if pid == 0:
            the_mutex_exercise()
            _ = _Exit(0)
        watch_the_child(pid, "the mutex exercise")


def test_call_once_runs_it_exactly_once() raises:
    """`call_once` runs the function the first time it is asked and
    never the second.

    The function takes no argument and reaches nothing it captured, so
    what it runs through is a file descriptor: the test parks the write
    end of a pipe at slot 20, the function writes one byte there, and
    the test asks for two and gets one. Asking for two is what makes
    one the whole answer -- had it run twice, both bytes would be there
    to read.
    """
    comptime if not CompilationTarget.is_macos():
        var pair = unsafe_alloc[Int32](2)
        assert_equal(pipe(pair), 0, "a pipe is made")
        assert_equal(
            dup2(pair.unsafe_offset(1)[], 20),
            20,
            "its write end is parked at slot 20",
        )
        _ = close(pair.unsafe_offset(1)[])

        var flag_room = unsafe_alloc[once_flag](1)
        flag_room.unsafe_offset(0)[] = once_flag()
        var once_fn: def() thin -> None = the_first_one
        _ = call_once(flag_room, once_fn)
        _ = call_once(flag_room, once_fn)

        var bytes = unsafe_alloc[UInt8](2)
        assert_equal(
            Int(read(pair.unsafe_offset(0)[], bytes, 2)),
            1,
            "one run, and one byte is all there is",
        )
        _ = close(pair.unsafe_offset(0)[])
        _ = close(20)
        bytes.unsafe_free()
        flag_room.unsafe_free()
        pair.unsafe_free()


def test_a_condition_variable_wakes_its_waiter() raises:
    """The condition variable handshake, run in a forked child and
    waited for under a deadline, for the same reason the mutex exercise
    is: a wake that goes missing here does not answer wrongly but stops
    answering, and a child that stops answering is four seconds and a
    kill rather than a suite that never comes back.
    """
    comptime if not CompilationTarget.is_macos():
        var pid = fork()
        assert_true(pid >= 0, "a child is forked to run the handshake in")
        if pid == 0:
            the_handshake_exercise()
            _ = _Exit(0)
        watch_the_child(pid, "the condition variable exercise")


def test_a_slot_is_one_per_thread() raises:
    """A thread-local slot answers this thread what this thread put in
    it, and another thread's put is invisible from here.

    The second user sets a pointer the first one does not know and
    ends; the slot is read here after the join, when the other thread
    can no longer be writing, and what it finds is still what was put
    here first.
    """
    comptime if not CompilationTarget.is_macos():
        var key = unsafe_alloc[tss_t](1)
        assert_equal(
            tss_create(key, no_dtor),
            thrd_success,
            "a slot is made, with a destructor that does nothing",
        )

        var mine = unsafe_alloc[UInt8](1)
        mine.unsafe_offset(0)[] = 0x11
        assert_true(
            is_null(tss_get(key.unsafe_offset(0)[])),
            "nothing has been put in it yet",
        )
        assert_equal(
            tss_set(key.unsafe_offset(0)[], mine.unsafe_bitcast[c_void]()),
            thrd_success,
            "this thread puts a pointer in",
        )
        assert_equal(
            Int(tss_get(key.unsafe_offset(0)[])),
            Int(mine.unsafe_bitcast[c_void]()),
            "and reads that one back",
        )

        var other = unsafe_alloc[UInt8](1)
        other.unsafe_offset(0)[] = 0x22
        var notes = unsafe_alloc[UInt8](16)
        for i in range(16):
            notes.unsafe_offset(i)[] = 0
        notes.unsafe_bitcast[tss_t]().unsafe_offset(0)[] = key.unsafe_offset(
            0
        )[]
        notes.unsafe_offset(8).unsafe_bitcast[c_ptr[UInt8]]().unsafe_offset(
            0
        )[] = other
        var id = unsafe_alloc[thrd_t](1)
        var second: def(c_ptr[c_void]) thin -> Int32 = probe_tss
        assert_equal(
            thrd_create(id, second, notes.unsafe_bitcast[c_void]()),
            thrd_success,
            "a second thread puts its own in",
        )
        var answer = unsafe_alloc[Int32](1)
        assert_equal(
            thrd_join(id.unsafe_offset(0)[], answer),
            thrd_success,
            "and is joined",
        )
        assert_equal(
            Int(tss_get(key.unsafe_offset(0)[])),
            Int(mine.unsafe_bitcast[c_void]()),
            "what it put is not what this thread reads",
        )
        _ = tss_delete(key.unsafe_offset(0)[])
        answer.unsafe_free()
        id.unsafe_free()
        notes.unsafe_free()
        other.unsafe_free()
        mine.unsafe_free()
        key.unsafe_free()


def main() raises:
    test_a_thread_answers_whether_it_worked()
    test_a_thread_that_ends_through_thrd_exit()
    test_a_thread_nobody_joins_is_detached()
    test_sleeping_takes_the_time_asked()
    test_a_mutex_locks_and_times_out()
    test_call_once_runs_it_exactly_once()
    test_a_condition_variable_wakes_its_waiter()
    test_a_slot_is_one_per_thread()
    print("test_threads: ok")
