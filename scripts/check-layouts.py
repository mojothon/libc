"""Check every struct this package declares against what C says it is.

A struct here either mirrors a C struct field for field, or it is a block
of bytes big enough to hold whatever arrangement C has for it. Either way
it carries numbers: how wide it is, where it has to start in memory. Get
one wrong and nothing fails here — libc writes past the end of it, or
writes `st_ino` where the layout expects something else, and what comes
back is a number nobody recognises as wrong.

`tests/test_layout.mojo` asserts some of this for some structs, which is
assumed coverage of the ones somebody thought about. This asks instead.

Size and alignment are reachable from Mojo without constructing anything,
so nothing here depends on a struct having a no-argument constructor or
exported fields. Field offsets are not reachable at all: the pointer this
module is written against has no `address_of`, and while `Pointer` does,
asking it for the address of a member asks for a member pointer, which
Mojo does not have.

Which leaves two kinds of struct here, and one of them can be asked about
its offsets after all. A struct held as bytes has no members for C's
`offsetof` to be compared against, but it does have a number per member —
the one its accessors read and write at — and that number is a claim
about C made in exactly the terms C answers in. Those are listed in
`OFFSETS` and checked one by one. The rest declare their members in
order and let Mojo lay them out, which agrees with C when the order does
and says nothing about anything else, so they are counted rather than
checked.
"""

import importlib.util
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "src" / "libc").rglob("*.mojo"))

CC = ["cc"]
DEFINES = ["-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-D_DARWIN_C_SOURCE"]

STRUCT = re.compile(r"^struct (\w+)(?:\([^)]*\))?:\n((?:[ \t].*\n|\n)*)", re.M)
FIELD = re.compile(r"^\s+var (\w+)\s*:\s*(.+)$", re.M)


def mojo() -> list[str]:
    """How to run the compiler, whether this runs inside pixi or not."""
    if shutil.which("mojo"):
        return ["mojo"]
    # Under `pixi run` it is on the path already. Reached any other way it
    # is not, and reaching into `.pixi/envs` for the binary is not enough:
    # called directly like that it cannot find `print`, because what makes
    # the standard library visible to it is the environment pixi sets up.
    if shutil.which("pixi"):
        return ["pixi", "run", "mojo"]
    raise SystemExit("neither mojo nor pixi was found")


def sibling(name: str):
    """Load another script here, whose name has a hyphen in it."""
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), ROOT / "scripts" / f"{name}.py"
    )
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


# `check-constants.py` already worked out which headers have to be included
# and which of them exist here; asking again would be a second list to keep.
CHECK_CONSTANTS = sibling("check-constants")

# Only the ones C spells differently. Everything else here is named after
# the C struct it stands for, which is the point of it. The list itself
# is kept in `check-prototypes`, which `check-constants` and this file
# both load and which cannot load either of them back.
CHECK_PROTOTYPES = sibling("check-prototypes")
SPELLED_DIFFERENTLY = CHECK_PROTOTYPES.SPELLED_DIFFERENTLY

# And the ones with nothing to compare against: opaque handles C never
# finishes describing (`DIR`, `FILE` are only ever seen through a
# pointer), things this package made up, and things C spells as a typedef
# of a struct with some other name. Each is reported rather than skipped
# silently, because "not checked" is a fact about these too.
NOT_A_C_STRUCT = {
    "DIR": "an opaque handle; C never says what is inside it",
    "FILE": "an opaque handle; C never says what is inside it",
    "Locale": "this package's own handle, not a C struct",
    "CString": "this package's own handle, not a C struct",
}

# Where this package places a member itself rather than letting Mojo lay the
# struct out: one byte offset per member, used by the accessors of a struct
# held as bytes. Each is a claim about C, so each is asked of C.
#
# Written out one by one, and deliberately not derived from the names:
# nothing about `TERMIOS_CC_OFFSET` says C calls that member `c_cc`, and a
# guess that happens to land on the right answer is worth less here than a
# list somebody had to type. A constant that is renamed or dropped is
# reported as unchecked rather than skipped, so the list cannot quietly go
# stale.
OFFSETS: dict[tuple[str, str], tuple[str, str]] = {
    ("libc.aio", "AIOCB_FILDES"): ("aiocb", "aio_fildes"),
    ("libc.aio", "AIOCB_LIO_OPCODE"): ("aiocb", "aio_lio_opcode"),
    ("libc.aio", "AIOCB_REQPRIO"): ("aiocb", "aio_reqprio"),
    ("libc.aio", "AIOCB_BUF"): ("aiocb", "aio_buf"),
    ("libc.aio", "AIOCB_NBYTES"): ("aiocb", "aio_nbytes"),
    ("libc.aio", "AIOCB_OFFSET"): ("aiocb", "aio_offset"),
    ("libc.dirent", "DIRENT_INO_OFFSET"): ("dirent", "d_ino"),
    ("libc.dirent", "DIRENT_RECLEN_OFFSET"): ("dirent", "d_reclen"),
    ("libc.dirent", "DIRENT_TYPE_OFFSET"): ("dirent", "d_type"),
    ("libc.dirent", "DIRENT_NAME_OFFSET"): ("dirent", "d_name"),
    ("libc.sys.stat", "STAT_DEV_OFFSET"): ("stat", "st_dev"),
    ("libc.sys.stat", "STAT_INO_OFFSET"): ("stat", "st_ino"),
    ("libc.sys.stat", "STAT_MODE_OFFSET"): ("stat", "st_mode"),
    ("libc.sys.stat", "STAT_NLINK_OFFSET"): ("stat", "st_nlink"),
    ("libc.sys.stat", "STAT_UID_OFFSET"): ("stat", "st_uid"),
    ("libc.sys.stat", "STAT_GID_OFFSET"): ("stat", "st_gid"),
    ("libc.sys.stat", "STAT_RDEV_OFFSET"): ("stat", "st_rdev"),
    ("libc.sys.stat", "STAT_ATIME_OFFSET"): ("stat", "st_atime"),
    ("libc.sys.stat", "STAT_MTIME_OFFSET"): ("stat", "st_mtime"),
    ("libc.sys.stat", "STAT_CTIME_OFFSET"): ("stat", "st_ctime"),
    ("libc.sys.stat", "STAT_SIZE_OFFSET"): ("stat", "st_size"),
    ("libc.sys.stat", "STAT_BLOCKS_OFFSET"): ("stat", "st_blocks"),
    ("libc.sys.stat", "STAT_BLKSIZE_OFFSET"): ("stat", "st_blksize"),
    ("libc.sys.statvfs", "STATVFS_BSIZE_OFFSET"): ("statvfs", "f_bsize"),
    ("libc.sys.statvfs", "STATVFS_FRSIZE_OFFSET"): ("statvfs", "f_frsize"),
    ("libc.sys.statvfs", "STATVFS_BLOCKS_OFFSET"): ("statvfs", "f_blocks"),
    ("libc.sys.statvfs", "STATVFS_BFREE_OFFSET"): ("statvfs", "f_bfree"),
    ("libc.sys.statvfs", "STATVFS_BAVAIL_OFFSET"): ("statvfs", "f_bavail"),
    ("libc.sys.statvfs", "STATVFS_FILES_OFFSET"): ("statvfs", "f_files"),
    ("libc.sys.statvfs", "STATVFS_FFREE_OFFSET"): ("statvfs", "f_ffree"),
    ("libc.sys.statvfs", "STATVFS_FAVAIL_OFFSET"): ("statvfs", "f_favail"),
    ("libc.sys.statvfs", "STATVFS_FSID_OFFSET"): ("statvfs", "f_fsid"),
    ("libc.sys.statvfs", "STATVFS_FLAG_OFFSET"): ("statvfs", "f_flag"),
    ("libc.sys.statvfs", "STATVFS_NAMEMAX_OFFSET"): ("statvfs", "f_namemax"),
    ("libc.sys.utsname", "UTSNAME_SYSNAME_OFFSET"): ("utsname", "sysname"),
    ("libc.sys.utsname", "UTSNAME_NODENAME_OFFSET"): ("utsname", "nodename"),
    ("libc.sys.utsname", "UTSNAME_RELEASE_OFFSET"): ("utsname", "release"),
    ("libc.sys.utsname", "UTSNAME_VERSION_OFFSET"): ("utsname", "version"),
    ("libc.sys.utsname", "UTSNAME_MACHINE_OFFSET"): ("utsname", "machine"),
    ("libc.sys.utsname", "UTSNAME_DOMAINNAME_OFFSET"): ("utsname", "domainname"),
    ("libc.grp", "GROUP_NAME_OFFSET"): ("group", "gr_name"),
    ("libc.grp", "GROUP_PASSWD_OFFSET"): ("group", "gr_passwd"),
    ("libc.grp", "GROUP_GID_OFFSET"): ("group", "gr_gid"),
    ("libc.grp", "GROUP_MEM_OFFSET"): ("group", "gr_mem"),
    ("libc.pwd", "PASSWD_NAME_OFFSET"): ("passwd", "pw_name"),
    ("libc.pwd", "PASSWD_PASSWD_OFFSET"): ("passwd", "pw_passwd"),
    ("libc.pwd", "PASSWD_UID_OFFSET"): ("passwd", "pw_uid"),
    ("libc.pwd", "PASSWD_GID_OFFSET"): ("passwd", "pw_gid"),
    ("libc.pwd", "PASSWD_CHANGE_OFFSET"): ("passwd", "pw_change"),
    ("libc.pwd", "PASSWD_CLASS_OFFSET"): ("passwd", "pw_class"),
    ("libc.pwd", "PASSWD_GECOS_OFFSET"): ("passwd", "pw_gecos"),
    ("libc.pwd", "PASSWD_DIR_OFFSET"): ("passwd", "pw_dir"),
    ("libc.pwd", "PASSWD_SHELL_OFFSET"): ("passwd", "pw_shell"),
    ("libc.pwd", "PASSWD_EXPIRE_OFFSET"): ("passwd", "pw_expire"),
    ("libc.sys.socket", "SOCKADDR_LEN_OFFSET"): ("sockaddr", "sa_len"),
    ("libc.sys.socket", "SOCKADDR_FAMILY_OFFSET"): ("sockaddr", "sa_family"),
    ("libc.sys.socket", "MSGHDR_NAME_OFFSET"): ("msghdr", "msg_name"),
    ("libc.sys.socket", "MSGHDR_NAMELEN_OFFSET"): ("msghdr", "msg_namelen"),
    ("libc.sys.socket", "MSGHDR_IOV_OFFSET"): ("msghdr", "msg_iov"),
    ("libc.sys.socket", "MSGHDR_IOVLEN_OFFSET"): ("msghdr", "msg_iovlen"),
    ("libc.sys.socket", "MSGHDR_CONTROL_OFFSET"): ("msghdr", "msg_control"),
    ("libc.sys.socket", "MSGHDR_CONTROLLEN_OFFSET"): ("msghdr", "msg_controllen"),
    ("libc.sys.socket", "MSGHDR_FLAGS_OFFSET"): ("msghdr", "msg_flags"),
    ("libc.regex", "REGMATCH_SO_OFFSET"): ("regmatch_t", "rm_so"),
    ("libc.regex", "REGMATCH_EO_OFFSET"): ("regmatch_t", "rm_eo"),
    ("libc.sched", "SCHED_PARAM_PRIORITY_OFFSET"): ("sched_param", "sched_priority"),
    ("libc.signal", "STACK_SP_OFFSET"): ("stack_t", "ss_sp"),
    ("libc.signal", "STACK_FLAGS_OFFSET"): ("stack_t", "ss_flags"),
    ("libc.signal", "STACK_SIZE_OFFSET"): ("stack_t", "ss_size"),
    ("libc.signal", "SIGACTION_HANDLER_OFFSET"): ("sigaction", "sa_handler"),
    ("libc.signal", "SIGACTION_FLAGS_OFFSET"): ("sigaction", "sa_flags"),
    ("libc.signal", "SIGINFO_SIGNO_OFFSET"): ("siginfo_t", "si_signo"),
    ("libc.signal", "SIGINFO_ERRNO_OFFSET"): ("siginfo_t", "si_errno"),
    ("libc.signal", "SIGINFO_CODE_OFFSET"): ("siginfo_t", "si_code"),
    ("libc.signal", "SIGINFO_PID_OFFSET"): ("siginfo_t", "si_pid"),
    ("libc.signal", "SIGINFO_UID_OFFSET"): ("siginfo_t", "si_uid"),
    ("libc.signal", "SIGINFO_STATUS_OFFSET"): ("siginfo_t", "si_status"),
    ("libc.signal", "SIGINFO_VALUE_OFFSET"): ("siginfo_t", "si_value"),
    ("libc.glob", "GLOB_PATHC_OFFSET"): ("glob_t", "gl_pathc"),
    ("libc.glob", "GLOB_PATHV_OFFSET"): ("glob_t", "gl_pathv"),
    ("libc.glob", "GLOB_OFFS_OFFSET"): ("glob_t", "gl_offs"),
    ("libc.glob", "GLOB_FLAGS_OFFSET"): ("glob_t", "gl_flags"),
    ("libc.ifaddrs", "IFADDRS_NEXT_OFFSET"): ("ifaddrs", "ifa_next"),
    ("libc.ifaddrs", "IFADDRS_NAME_OFFSET"): ("ifaddrs", "ifa_name"),
    ("libc.ifaddrs", "IFADDRS_FLAGS_OFFSET"): ("ifaddrs", "ifa_flags"),
    ("libc.ifaddrs", "IFADDRS_ADDR_OFFSET"): ("ifaddrs", "ifa_addr"),
    ("libc.ifaddrs", "IFADDRS_NETMASK_OFFSET"): ("ifaddrs", "ifa_netmask"),
    ("libc.ifaddrs", "IFADDRS_DSTADDR_OFFSET"): ("ifaddrs", "ifa_dstaddr"),
    ("libc.ifaddrs", "IFADDRS_DATA_OFFSET"): ("ifaddrs", "ifa_data"),
    ("libc.netif", "IFNAMEINDEX_INDEX_OFFSET"): ("if_nameindex", "if_index"),
    ("libc.netif", "IFNAMEINDEX_NAME_OFFSET"): ("if_nameindex", "if_name"),
    ("libc.sys.sysinfo", "SYSINFO_UPTIME"): ("sysinfo", "uptime"),
    ("libc.sys.sysinfo", "SYSINFO_LOADS"): ("sysinfo", "loads"),
    ("libc.sys.sysinfo", "SYSINFO_TOTALRAM"): ("sysinfo", "totalram"),
    ("libc.sys.sysinfo", "SYSINFO_FREERAM"): ("sysinfo", "freeram"),
    ("libc.sys.sysinfo", "SYSINFO_SHAREDRAM"): ("sysinfo", "sharedram"),
    ("libc.sys.sysinfo", "SYSINFO_BUFFERRAM"): ("sysinfo", "bufferram"),
    ("libc.sys.sysinfo", "SYSINFO_TOTALSWAP"): ("sysinfo", "totalswap"),
    ("libc.sys.sysinfo", "SYSINFO_FREESWAP"): ("sysinfo", "freeswap"),
    ("libc.sys.sysinfo", "SYSINFO_PROCS"): ("sysinfo", "procs"),
    ("libc.sys.sysinfo", "SYSINFO_TOTALHIGH"): ("sysinfo", "totalhigh"),
    ("libc.sys.sysinfo", "SYSINFO_FREEHIGH"): ("sysinfo", "freehigh"),
    ("libc.sys.sysinfo", "SYSINFO_MEM_UNIT"): ("sysinfo", "mem_unit"),
    ("libc.sys.timer", "SIGEVENT_NOTIFY_OFFSET"): ("sigevent", "sigev_notify"),
    ("libc.termios", "TERMIOS_IFLAG_OFFSET"): ("termios", "c_iflag"),
    ("libc.termios", "TERMIOS_OFLAG_OFFSET"): ("termios", "c_oflag"),
    ("libc.termios", "TERMIOS_CFLAG_OFFSET"): ("termios", "c_cflag"),
    ("libc.termios", "TERMIOS_LFLAG_OFFSET"): ("termios", "c_lflag"),
    ("libc.termios", "TERMIOS_CC_OFFSET"): ("termios", "c_cc"),
    ("libc.termios", "TERMIOS_ISPEED_OFFSET"): ("termios", "c_ispeed"),
    ("libc.termios", "TERMIOS_OSPEED_OFFSET"): ("termios", "c_ospeed"),
    ("libc.utmpx", "UT_TYPE_OFFSET"): ("utmpx", "ut_type"),
    ("libc.utmpx", "UT_PID_OFFSET"): ("utmpx", "ut_pid"),
    ("libc.utmpx", "UT_LINE_OFFSET"): ("utmpx", "ut_line"),
    ("libc.utmpx", "UT_ID_OFFSET"): ("utmpx", "ut_id"),
    ("libc.utmpx", "UT_USER_OFFSET"): ("utmpx", "ut_user"),
    ("libc.utmpx", "UT_HOST_OFFSET"): ("utmpx", "ut_host"),
}

# Constants that state how wide a C type is, rather than standing for one.
# `libc.termios` reads its flag and speed words out of a slot, and how much of
# that slot is the word is C's answer: four bytes of `unsigned int` on glibc,
# eight of `unsigned long` on Darwin. Neither is a type alias, so
# `check-constants` has no `sizeof` to ask; the type is written down here
# beside the constant, and asked the way the struct sizes are.
WIDTHS: dict[tuple[str, str], str] = {
    ("libc.termios", "TERMIOS_FLAG_BYTES"): "tcflag_t",
    ("libc.termios", "TERMIOS_SPEED_BYTES"): "speed_t",
}


# The members whose struct only one platform has. `sys/sysinfo.h` is glibc's
# and XNU has no header by that name. `struct sigevent` exists on both, but
# it is not the same struct twice: the only thing that uses it on Darwin is
# POSIX AIO, and that one begins with `sigev_notify` where glibc's begins
# with eight bytes of `sigev_value` — which is the `timer_create` struct this
# package reads, and Darwin has no timers. Asking Darwin's C about a member
# of it answers about a different struct, so it is not asked, and the member
# is counted as Linux's rather than as unchecked: a number that disagrees
# with the wrong struct is not a finding.
LINUX_ONLY: set[tuple[str, str]] = {
    ("libc.sys.sysinfo", "SYSINFO_UPTIME"),
    ("libc.sys.sysinfo", "SYSINFO_LOADS"),
    ("libc.sys.sysinfo", "SYSINFO_TOTALRAM"),
    ("libc.sys.sysinfo", "SYSINFO_FREERAM"),
    ("libc.sys.sysinfo", "SYSINFO_SHAREDRAM"),
    ("libc.sys.sysinfo", "SYSINFO_BUFFERRAM"),
    ("libc.sys.sysinfo", "SYSINFO_TOTALSWAP"),
    ("libc.sys.sysinfo", "SYSINFO_FREESWAP"),
    ("libc.sys.sysinfo", "SYSINFO_PROCS"),
    ("libc.sys.sysinfo", "SYSINFO_TOTALHIGH"),
    ("libc.sys.sysinfo", "SYSINFO_FREEHIGH"),
    ("libc.sys.sysinfo", "SYSINFO_MEM_UNIT"),
    ("libc.sys.timer", "SIGEVENT_NOTIFY_OFFSET"),
}

ON_DARWIN = sys.platform == "darwin"

# `beyond-c.md` states what the package adds up to, and it states it in a
# table rather than in a sentence because a number written into a paragraph
# is a number that goes stale quietly. Each row is recognised by the phrase
# in its first cell and compared with what was counted here, so the two
# cannot drift apart without one of them failing.
STATED_ROWS: dict[str, str] = {
    "by hand": "offsets",
    "in order": "fielded",
    "only a size": "bytes",
    "only Linux": "linux_only",
    "a fixed room": "rooms",
}


def stated_counts(counts: dict[str, int]) -> list[str]:
    """Where `docs/beyond-c.md` and what was counted here disagree.

    A row that is gone counts as a disagreement too: the point of the table
    is that it keeps saying these things, so a paragraph that stops saying
    one of them is the drift this is watching for.
    """
    wrong = []
    found = set()
    text = (ROOT / "docs" / "beyond-c.md").read_text()
    for line in text.splitlines():
        row = re.fullmatch(r"\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|", line)
        if row is None:
            continue
        cell, said = row.group(1), int(row.group(2))
        for phrase, key in STATED_ROWS.items():
            if phrase not in cell:
                continue
            found.add(key)
            if said != counts[key]:
                wrong.append(f"{cell}: says {said}, and it is {counts[key]}")
            break
    for phrase, key in STATED_ROWS.items():
        if key not in found:
            wrong.append(f"no longer says how many {phrase}")
    return wrong


def module_of(path: Path) -> str:
    """The name this file is imported by."""
    relative = path.relative_to(ROOT / "src").with_suffix("")
    return ".".join(relative.parts[:-1] if relative.name == "syscalls" else relative.parts)


# A constant named for the member it places, and a member read at a number
# that is not one. The first is how `OFFSETS` is kept complete; the second
# is the shape of the mistake the list exists to prevent, caught wherever it
# is made rather than where somebody remembered to register it.
PLACED = re.compile(r"^comptime (\w*_OFFSET)\b", re.M)
READ_AT = re.compile(
    r"self\._(?:byte|u16|u32|u64)\((\d+)\)"
    r"|self\._set_(?:byte|u16|u32|u64|at)\((\d+),"
)


def placed_by_hand() -> dict[tuple[str, str], str]:
    """Every constant in src that places a member by hand, and where it is.

    The list above is what gets asked; this is what exists to be asked. A
    constant that places a member and is not up there would never be put to
    `offsetof`, and nothing outside this function would say so: the report
    over `OFFSETS` catches a name that was renamed or dropped, which is the
    list going stale, and not one that was added, which is it going
    incomplete.
    """
    found: dict[tuple[str, str], str] = {}
    for path in SOURCES:
        module = module_of(path)
        for match in PLACED.finditer(path.read_text()):
            found[(module, match.group(1))] = str(path.relative_to(ROOT))
    return found


def read_at_a_literal() -> list[str]:
    """Places where a member is read or written at a number written in the call.

    `self._u64(0)` is an offset claimed inline, where no list can see it and
    no `offsetof` can be compared with it. Naming it costs a line and puts
    the claim where the rest of them are. Both directions, because a setter
    at a literal offset is not in `write_widths` to be counted either, and
    would otherwise be the one place a member is placed without anyone
    knowing how many there are.
    """
    found = []
    for path in SOURCES:
        for number, line in enumerate(path.read_text().split("\n"), 1):
            match = READ_AT.search(line)
            if match is None:
                continue
            did = "reads" if match.group(1) is not None else "writes"
            at = match.group(1) if match.group(1) is not None else match.group(2)
            found.append(
                f"{module_of(path)} {did} at {at}"
                f"  ({path.relative_to(ROOT)}:{number})"
            )
    return found


# An offset says where a member starts; it does not say how wide what sits
# there is. An accessor answers that too, in the reader it uses:
# `_u32(STAT_MODE_OFFSET)` takes four bytes, `_u64(STAT_DEV_OFFSET)` eight.
# Reading four bytes of an eight-byte member truncates it, and reading eight
# of a four-byte one carries the member beside it into the answer — both are
# numbers that look plausible and are not the member. `offsetof` cannot see
# either mistake, and neither can `sizeof`: both are right whichever width the
# accessor reads at. So the width the source reads is compared with the width
# C says, which is the last claim the hand-placed members make.
READERS = {
    "byte": 1,
    "u8": 1,
    "i8": 1,
    "u16": 2,
    "i16": 2,
    "u32": 4,
    "i32": 4,
    "u64": 8,
    "i64": 8,
    "member": 8,
    "ptr_at": 8,
}

# Readers that hand back text rather than a number: how far they read is where
# the NUL is, and `sizeof` of a `char[65]` is not the answer to any question
# they ask. `_at` is a whole slot in `socket` and text in `utsname`, so a
# reader returning `String` is recognised by that rather than by its name.
TEXT_READERS = {"text", "text_at", "string"}

# Readers whose width is not in their name and is a checked number already:
# `_flag` and `_speed` read `TERMIOS_FLAG_BYTES` and `TERMIOS_SPEED_BYTES`
# wide, and `WIDTHS` is where those are put to `sizeof`.
WIDTHS_FROM_CONSTANT = {"flag", "speed"}

READ = re.compile(r"self\.(_\w+)\((\w+_OFFSET)\)")
# A read of a whole slot is often a read of half of one: `pw_uid` takes the
# slot holding both ids and masks off the top, `pw_gid` takes the same slot
# and shifts the bottom away. What is left after the mask or the shift is the
# member, so the width is what the mask leaves rather than what the reader
# took. Longest first: `0xFFFF` is a prefix of `0xFFFFFFFF`.
MASKS = (("0xFFFFFFFF", 4), ("0xFFFF", 2), ("0xFF", 1))
SHIFT = re.compile(r">>\s*(\d+)")


def kept_of(line: str, reader_width: int) -> tuple[int, int, bool]:
    """How much of what this reader took the member is, and which bytes.

    `self._member(PASSWD_UID_OFFSET) & 0xFFFFFFFF` reads eight bytes and
    keeps the low four; `>> 32` keeps the high four. Either way the accessor
    is claiming four bytes at that offset, and the second number says which
    four — a slot read that keeps the wrong half gives a number that is the
    right size and the wrong value, which is what `gl_flags` did for three
    releases.

    The third says whether the half was chosen in the call at all: a `_u32`
    reader takes its four bytes from wherever the offset falls inside the
    slot, so there is no choice there for this to disagree with.
    """
    width = reader_width
    kept_from = 0
    by_hand = False
    for token, kept in MASKS:
        if token in line:
            width = min(width, kept)
            by_hand = reader_width == 8
            break
    shifted = SHIFT.search(line)
    if shifted is not None and int(shifted.group(1)) % 8 == 0:
        dropped = int(shifted.group(1)) // 8
        if 0 < dropped < 8:
            width = min(width, 8 - dropped)
            kept_from = dropped
            by_hand = reader_width == 8
    return width, kept_from, by_hand
GUARDED = "comptime if CompilationTarget.is_macos():"

# Members an accessor deliberately takes less of than C holds. Each one is a
# claim somebody made on purpose, and the number beside it is what makes it
# checkable rather than forgotten: `sizeof` disagreeing with a constant in
# here is a failure, so the exemption cannot outlive the member it is about.
NARROWER_ON_PURPOSE: dict[tuple[str, str, str], str] = {
    ("libc.signal", "SIGINFO_VALUE_OFFSET", "si_value"): (
        "`si_value` is the `sival_int` half of a union it shares with "
        "`sival_ptr`, so four bytes of eight is the member it names"
    ),
}


def readers(path: Path) -> dict[str, int | None]:
    """How wide each reader in this file takes, and None for the text ones."""
    widths: dict[str, int | None] = {}
    for match in re.finditer(
        r"^    def (_\w+)\((?:[^)]*)\n?(?:[^)]*)\)\s*(?:raises\s*)?->\s*"
        r"([\w\[\], ]+):",
        path.read_text(),
        re.M,
    ):
        name, result = match.group(1), match.group(2).strip()
        if name in TEXT_READERS or result == "String":
            widths[name] = None
            continue
        stem = name[1:]
        if stem.startswith("set_"):
            stem = stem[4:]
        if stem in WIDTHS_FROM_CONSTANT:
            continue
        if stem in READERS:
            widths[name] = READERS[stem]
    return widths


def read_widths() -> tuple[
    dict[tuple[str, str, str], dict[str, set[tuple[int, int, bool]]]],
    dict[tuple[str, str, str], str],
]:
    """How wide each accessor reads its member, per platform, and where it is.

    One entry per accessor rather than per member, because the claim being
    read is the accessor's: `si_value` takes four bytes of the eight that
    `si_value`'s union occupies and `si_ptr`, once it exists, takes the
    eight — and a member with one accessor right and one wrong is a member
    with an accessor wrong, not a member that agrees.

    A reader inside `comptime if CompilationTarget.is_macos():` is the Darwin
    width and the `else:` one below it is the other platform's, so the widths
    are kept apart: on either platform only its own are compared, which is
    what lets `st_dev` be eight bytes here and four there without either being
    a mistake.
    """
    found: dict[tuple[str, str, str], dict[str, set[tuple[int, int, bool]]]] = {}
    places: dict[tuple[str, str, str], str] = {}
    DECLARED = re.compile(r"^    def (\w+)")
    for path in SOURCES:
        module = module_of(path)
        widths = readers(path)
        if not widths:
            continue
        guard: str | None = None
        accessor: str | None = None
        for number, line in enumerate(path.read_text().split("\n"), 1):
            if GUARDED in line:
                guard = "macos"
                continue
            stripped = line.strip()
            if guard == "macos" and stripped == "else:":
                guard = "linux"
                continue
            if guard is not None and (
                line.startswith("    def ")
                or (stripped and not line.startswith("        "))
            ):
                guard = None
            named = DECLARED.match(line)
            if named is not None:
                accessor = named.group(1)
                continue
            match = READ.search(line)
            if match is None or accessor is None:
                continue
            width = widths.get(match.group(1), None)
            if width is None:
                continue
            kept, kept_from, by_hand = kept_of(line, width)
            key = (module, match.group(2), accessor)
            per = found.setdefault(key, {"linux": set(), "macos": set()})
            for platform in (("linux", "macos") if guard is None else (guard,)):
                per[platform].add((kept, kept_from, by_hand))
                places.setdefault(
                    key, f"{path.relative_to(ROOT)}:{number}"
                )
    return found, places


# And the same claim made in the other direction: a setter puts a value into a
# member and the width it writes has to be the member's width, for the same
# reason. It is the one that hides best — a member written four bytes wide
# reads back correctly for every value that fits in four, because the high
# half is the zero it was already initialised to.
WRITERS = {"_set_byte": 1, "_set_u16": 2, "_set_u32": 4, "_set_u64": 8, "_set_at": 8}
WRITE = re.compile(r"self\.(_set_(?:byte|u16|u32|u64|at))\((\w+_OFFSET),")


def write_widths() -> tuple[
    dict[tuple[str, str, str], dict[str, set[int]]],
    dict[tuple[str, str, str], str],
]:
    """How wide each setter writes its member, per platform, and where it is.

    The same shape as `read_widths` and for the same reason: a setter inside
    `comptime if CompilationTarget.is_macos():` is writing the Darwin member,
    and only that platform's width is compared with a Darwin `sizeof`.
    """
    found: dict[tuple[str, str, str], dict[str, set[int]]] = {}
    places: dict[tuple[str, str, str], str] = {}
    DECLARED = re.compile(r"^    def (\w+)")
    for path in SOURCES:
        module = module_of(path)
        guard: str | None = None
        accessor: str | None = None
        for number, line in enumerate(path.read_text().split("\n"), 1):
            if GUARDED in line:
                guard = "macos"
                continue
            stripped = line.strip()
            if guard == "macos" and stripped == "else:":
                guard = "linux"
                continue
            if guard is not None and (
                line.startswith("    def ")
                or (stripped and not line.startswith("        "))
            ):
                guard = None
            named = DECLARED.match(line)
            if named is not None:
                accessor = named.group(1)
                continue
            match = WRITE.search(line)
            if match is None or accessor is None:
                continue
            width = WRITERS.get(match.group(1))
            if width is None:
                continue
            key = (module, match.group(2), accessor)
            per = found.setdefault(key, {"linux": set(), "macos": set()})
            for platform in (("linux", "macos") if guard is None else (guard,)):
                per[platform].add(width)
                places.setdefault(key, f"{path.relative_to(ROOT)}:{number}")
    return found, places


# A room this package gives itself for one of those members: `_string` reads
# at most that many bytes of it and `_set_string` writes at most that many, so
# the number is a claim about how wide the member is, in the same terms the
# accessor's reader claims a width in. It is the claim here whose being wrong
# costs the most: a room larger than the member is a write past the end of it.
ROOMED = re.compile(r"self\.(_set_string|_string)\((\w+_OFFSET),\s*(\w+)")


def rooms() -> dict[tuple[str, str, str], str]:
    """Every `(module, offset, room)` a string accessor is given, and where.

    Keyed by all three because the offset is what ties the room to a member:
    the offset is asked of `offsetof` already, so the room beside it is
    compared with `sizeof` of the member that offset names.
    """
    found: dict[tuple[str, str, str], str] = {}
    for path in SOURCES:
        module = module_of(path)
        for number, line in enumerate(path.read_text().split("\n"), 1):
            match = ROOMED.search(line)
            if match is None:
                continue
            found.setdefault(
                (module, match.group(2), match.group(3)),
                f"{path.relative_to(ROOT)}:{number}",
            )
    return found


def structs() -> list[tuple[str, str, str, list[str]]]:
    """Every struct: (label, module, what C calls it, fields it names)."""
    found = []
    for path in SOURCES:
        module = module_of(path)
        for m in STRUCT.finditer(path.read_text()):
            name = m.group(1)
            fields = [f for f, _ in FIELD.findall(m.group(2))]
            found.append((f"{module}.{name}", module, name, fields))
    # Declared in more than one module — `timespec` four times over — and
    # each one is a separate claim about the same C struct, so all are asked.
    return found


def c_name(name: str) -> str | None:
    return SPELLED_DIFFERENTLY.get(name, name)


def mojo_layouts(batch: list[tuple[str, str, str]]) -> tuple[dict[str, tuple[int, int]], list[str]]:
    """What Mojo says each one measures, and the ones it cannot say about.

    One program for all of them, halved when it will not build, because a
    struct that stopped being importable would otherwise sink everybody
    it was compiled with.
    """
    said: dict[str, tuple[int, int]] = {}
    refused: list[str] = []

    def program(items: list[tuple[str, str, str]]) -> str:
        imports = "\n".join(
            f"from {module} import {name} as _{index}"
            for index, (_label, module, name) in enumerate(items)
        )
        lines = "\n".join(
            f'    print("_{index}", size_of[_{index}](), align_of[_{index}]())'
            for index, (label, _module, _name) in enumerate(items)
        )
        return f"from std.sys import align_of, size_of\n{imports}\n\n\ndef main():\n{lines}\n"

    def ask(items: list[tuple[str, str, str]]) -> None:
        if not items:
            return
        source = ROOT / ".build-check" / "layout.mojo"
        source.parent.mkdir(exist_ok=True)
        source.write_text(program(items))
        ran = subprocess.run(
            [*mojo(), "run", "-I", str(ROOT / "src"), str(source)],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        if ran.returncode == 0 and ran.stdout.strip():
            seen = {}
            for line in ran.stdout.strip().splitlines():
                parts = line.split()
                if len(parts) == 3 and parts[0].startswith("_"):
                    seen[parts[0]] = (int(parts[1]), int(parts[2]))
            if all(f"_{index}" in seen for index in range(len(items))):
                for index, (label, _module, _name) in enumerate(items):
                    said[label] = seen[f"_{index}"]
                return
        if len(items) == 1:
            refused.append(items[0][0])
            return
        middle = len(items) // 2
        ask(items[:middle])
        ask(items[middle:])

    ask(batch)
    return said, refused


def c_layouts(items: list[tuple[str, str]]) -> tuple[dict[str, tuple[int, int]], list[str]]:
    """What C measures for each name given, and what it has nothing to say
    about.

    `struct X` is tried first and `X` second, since a good number of these
    — `fd_set`, `mbstate_t`, `pthread_attr_t` — are typedefs rather than
    structs with a tag, and the difference is invisible from the Mojo side.
    One compilation each, which is slower than batching and much simpler
    than deciding afterwards which of a group failed.
    """
    said: dict[str, tuple[int, int]] = {}
    refused: list[str] = []
    includes = "\n".join(f"#include <{h}>" for h in CHECK_CONSTANTS.headers())

    for label, name in items:
        for spelled in (f"struct {name}", name):
            body = (
                f'    printf("%zu %zu\\n", sizeof({spelled}), '
                f'_Alignof({spelled}));'
            )
            source = ROOT / ".build-check" / "layout.c"
            source.parent.mkdir(exist_ok=True)
            source.write_text(f"#include <stdio.h>\n{includes}\nint main(void) {{\n{body}\n    return 0;\n}}\n")
            built = subprocess.run(
                [*CC, *DEFINES, "-w", "-o", str(ROOT / ".build-check" / "layout"), str(source)],
                capture_output=True,
                text=True,
            )
            if built.returncode != 0:
                continue
            ran = subprocess.run(
                [str(ROOT / ".build-check" / "layout")], capture_output=True, text=True
            )
            size, align = ran.stdout.split()
            said[label] = (int(size), int(align))
            break
        else:
            refused.append(label)
    return said, refused


def mojo_numbers(
    keys: list[tuple[str, str]],
) -> tuple[dict[tuple[str, str], int], list[tuple[str, str]]]:
    """What Mojo says each of these numbers is on this platform.

    Read out of the compiler rather than out of the source, for the same
    reason the sizes are: the values are conditional on the platform, and
    a second reading here of `8 if ... else 4` would be a second place to
    be wrong in. Halved when it will not build, so that one constant that
    stopped being importable does not hide the other twenty-one.
    """
    said: dict[tuple[str, str], int] = {}
    missing: list[tuple[str, str]] = []

    def program(batch: list[tuple[str, str]]) -> str:
        imports = "\n".join(
            f"from {module} import {constant} as _{index}"
            for index, (module, constant) in enumerate(batch)
        )
        lines = "\n".join(
            f'    print("_{index}", _{index})' for index in range(len(batch))
        )
        return f"{imports}\n\n\ndef main():\n{lines}\n"

    def ask(batch: list[tuple[str, str]]) -> None:
        if not batch:
            return
        source = ROOT / ".build-check" / "offsets.mojo"
        source.parent.mkdir(exist_ok=True)
        source.write_text(program(batch))
        ran = subprocess.run(
            [*mojo(), "run", "-I", str(ROOT / "src"), str(source)],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        if ran.returncode == 0:
            seen = {}
            for line in ran.stdout.splitlines():
                parts = line.split()
                if len(parts) == 2 and parts[0].startswith("_"):
                    seen[parts[0]] = int(parts[1])
            if all(f"_{index}" in seen for index in range(len(batch))):
                for index, key in enumerate(batch):
                    said[key] = seen[f"_{index}"]
                return
        if len(batch) == 1:
            missing.append(batch[0])
            return
        middle = len(batch) // 2
        ask(batch[:middle])
        ask(batch[middle:])

    ask(keys)
    return said, missing


def c_offsets() -> tuple[
    dict[tuple[str, str], int],
    dict[tuple[str, str], int],
    list[tuple[str, str]],
]:
    """What `offsetof` and `sizeof` say for each of them, one struct at a time.

    Every member of one struct comes out of one compilation, which keeps
    this at four builds rather than twenty-two. A member C does not have
    under that name would take the rest of its struct down with it, so a
    struct that will not build is asked again a member at a time — that
    being the likeliest way for a field to be spelled wrongly here.

    Both numbers come back from the same build because they are asked of the
    same member: `sizeof` is how wide the member is, which is what an
    accessor reading it has to read.
    """
    said: dict[tuple[str, str], int] = {}
    sizes: dict[tuple[str, str], int] = {}
    missing: list[tuple[str, str]] = []
    includes = "\n".join(f"#include <{h}>" for h in CHECK_CONSTANTS.headers())

    by_struct: dict[str, list[tuple[tuple[str, str], str]]] = {}
    for key, (struct, member) in OFFSETS.items():
        if ON_DARWIN and key in LINUX_ONLY:
            continue
        by_struct.setdefault(struct, []).append((key, member))

    def program(
        struct: str, members: list[tuple[tuple[str, str], str]], tagged: bool
    ) -> str:
        kind = f"struct {struct}" if tagged else struct
        lines = "\n".join(
            f'    printf("_{index} %zu %zu\\n", offsetof({kind}, {member}),'
            f" sizeof((({kind} *)0)->{member}));"
            for index, (_key, member) in enumerate(members)
        )
        return (
            f"#include <stdio.h>\n#include <stddef.h>\n{includes}\n"
            f"int main(void) {{\n{lines}\n    return 0;\n}}\n"
        )

    def record(
        struct: str, members: list[tuple[tuple[str, str], str]], tagged: bool
    ) -> bool:
        """Asks C about these members, once, and keeps the answers it got."""
        source = ROOT / ".build-check" / "offsets.c"
        source.parent.mkdir(exist_ok=True)
        source.write_text(program(struct, members, tagged))
        built = subprocess.run(
            [
                *CC,
                *DEFINES,
                "-w",
                "-o",
                str(ROOT / ".build-check" / "offsets"),
                str(source),
            ],
            capture_output=True,
            text=True,
        )
        if built.returncode != 0:
            return False
        ran = subprocess.run(
            [str(ROOT / ".build-check" / "offsets")],
            capture_output=True,
            text=True,
        )
        seen = {}
        for line in ran.stdout.splitlines():
            parts = line.split()
            if len(parts) == 3 and parts[0].startswith("_"):
                seen[parts[0]] = (int(parts[1]), int(parts[2]))
        if not all(f"_{index}" in seen for index in range(len(members))):
            return False
        for index, (key, _member) in enumerate(members):
            said[key], sizes[key] = seen[f"_{index}"]
        return True

    def ask(struct: str, members: list[tuple[tuple[str, str], str]]) -> None:
        # Two spellings, because not every one of these is a struct tag:
        # `regmatch_t` is a typedef with no tag at all, and `offsetof(struct
        # regmatch_t, rm_so)` does not compile.
        for tagged in (True, False):
            if record(struct, members, tagged):
                return
        if len(members) == 1:
            missing.append(members[0][0])
            return
        middle = len(members) // 2
        ask(struct, members[:middle])
        ask(struct, members[middle:])

    for struct, members in by_struct.items():
        ask(struct, members)
    return said, sizes, missing


def main() -> int:
    declared = structs()
    comparable = []
    not_a_struct = []
    for label, module, name, fields in declared:
        if name in NOT_A_C_STRUCT:
            not_a_struct.append((label, NOT_A_C_STRUCT[name]))
            continue
        named = c_name(name)
        if named is None:
            not_a_struct.append((label, "nothing in C is called this"))
            continue
        comparable.append((label, named))

    mine, _ = mojo_layouts([(label, module, name) for label, module, name, _f in declared
                            if label not in {l for l, _ in not_a_struct}])
    theirs, absent = c_layouts(comparable)

    def verdict(
        label: str, size: tuple[int, int], c_size: tuple[int, int], fields: list[str]
    ) -> str:
        """Whether a difference is dangerous, harmless, or none at all.

        A struct with named fields is claiming to be that C struct, so its
        size has to be exact: `qelem` here is twelve bytes short of what
        `insque` writes into, which is a hole punched in whatever sits
        next to it. Most of the opaque ones are deliberately bigger than
        this machine's — a block sized for whichever platform wanted most,
        because they are only ever handed over by pointer and libc writes
        less than it was given — and being generous with bytes costs
        nothing. Being stingy costs memory belonging to somebody else.

        Alignment only has one dangerous direction. Asking for four bytes
        where C asks for eight leaves the pointer the colder half of the
        difference, and `pthread_attr_init` is free to use an instruction
        that cares. Being stricter than C is safe and only worth knowing.
        """
        size_here, align_here = size
        size_c, align_c = c_size
        if align_here % align_c != 0:
            return "under-aligned"
        if len(fields) >= 2 and size_here != size_c:
            return "wrong size"
        if size_here < size_c:
            return "too small"
        if (size_here, align_here) != (size_c, align_c):
            return "loose"
        return ""

    agree = []
    disagree = []
    loose = []
    no_mojo = []
    no_c = []

    for label, module, name, fields in declared:
        if any(label == l for l, _ in not_a_struct):
            continue
        if label not in mine:
            no_mojo.append((label, module))
            continue
        if label not in theirs:
            no_c.append(label)
            continue
        problem = verdict(label, mine[label], theirs[label], fields)
        if problem == "":
            agree.append(label)
        elif problem == "loose":
            loose.append((label, mine[label], theirs[label]))
        else:
            disagree.append((label, mine[label], theirs[label], problem))

    platform = "Darwin" if sys.platform == "darwin" else "Linux"
    print(f"Checking struct sizes against the headers on {platform}.\n")
    print(f"  {len(agree)} agree with C")
    if disagree:
        print(f"  {len(disagree)} disagree, and should not:")
        for label, mine_values, theirs_values, problem in disagree:
            size_m, align_m = mine_values
            size_c, align_c = theirs_values
            print(
                f"      {label:<28} here {size_m:>5}/{align_m}  "
                f"C says {size_c:>5}/{align_c}   {problem}"
            )
    if loose:
        print(f"  {len(loose)} larger or stricter than C needs, which costs bytes "
              f"and breaks nothing:")
        for label, mine_values, theirs_values in loose:
            size_m, align_m = mine_values
            size_c, align_c = theirs_values
            print(
                f"      {label:<28} here {size_m:>5}/{align_m}  "
                f"C says {size_c:>5}/{align_c}"
            )

    if no_mojo or no_c or not_a_struct:
        print(f"\n  {len(no_mojo) + len(no_c) + len(not_a_struct)} could not be checked:")
        for label, module in no_mojo:
            print(f"      {label:<28} Mojo will not say")
        for label in no_c:
            print(f"      {label:<28} C does not have it here")
        for label, why in not_a_struct:
            print(f"      {label:<28} {why}")

    placed_here, unread = mojo_numbers(list(OFFSETS))
    placed_by_c, member_sizes, unheard_of = c_offsets()
    offset_agree = 0
    offset_disagree = []
    offset_unchecked = []
    offset_elsewhere = []
    for key, (struct, member) in OFFSETS.items():
        module, constant = key
        if ON_DARWIN and key in LINUX_ONLY:
            offset_elsewhere.append(f"{module}.{constant} {struct}.{member}")
        elif key in unread:
            offset_unchecked.append(f"{module}.{constant} Mojo will not say")
        elif key in unheard_of:
            offset_unchecked.append(
                f"{module}.{constant} C has no {struct}.{member}"
            )
        elif placed_here[key] == placed_by_c[key]:
            offset_agree += 1
        else:
            offset_disagree.append((key, struct, member))

    print(f"\n  Field offsets, for the {len(OFFSETS)} members placed by hand:")
    print(f"      {offset_agree} agree with offsetof")
    if offset_disagree:
        print(f"      {len(offset_disagree)} disagree, and cannot:")
        for (module, constant), struct, member in offset_disagree:
            print(
                f"      {module + '.' + constant:<40} here {placed_here[(module, constant)]:>4}  "
                f"C says {placed_by_c[(module, constant)]:>4}   {struct}.{member}"
            )
    if offset_elsewhere:
        print(f"      {len(offset_elsewhere)} are Linux's alone, and are not asked here")
    if offset_unchecked:
        print(f"      {len(offset_unchecked)} could not be checked:")
        for line in offset_unchecked:
            print(f"      {line}")

    here = "macos" if ON_DARWIN else "linux"
    read_here, read_at = read_widths()
    read_agree = 0
    read_narrow = []
    read_disagree = []
    read_half = []
    for key, per in sorted(read_here.items()):
        module, constant, accessor = key
        member_key = (module, constant)
        if member_key not in member_sizes or not per[here]:
            continue
        member_width = member_sizes[member_key]
        widths = sorted({width for width, _from, _hand in per[here]})
        right_size = [read for read in per[here] if read[0] == member_width]
        if not right_size:
            if key in NARROWER_ON_PURPOSE:
                read_narrow.append((key, member_width))
            else:
                read_disagree.append((key, widths, member_width))
            continue
        inside = placed_by_c[member_key] % 8 if member_key in placed_by_c else None
        wrong_half = [
            read
            for read in right_size
            if read[2] and inside is not None and read[1] != inside
        ]
        if wrong_half:
            read_half.append((key, wrong_half[0][1], inside))
        else:
            read_agree += 1

    if read_agree or read_narrow or read_disagree or read_half:
        asked = read_agree + len(read_narrow) + len(read_disagree) + len(read_half)
        print(f"\n  Read widths, for the {asked} accessors that read a member:")
        print(f"      {read_agree} agree with sizeof")
        for (module, constant, accessor), member_width in read_narrow:
            struct, member = OFFSETS[(module, constant)]
            print(
                f"      {module + '.' + accessor:<40} reads less than"
                f" {member_width:>2}   {NARROWER_ON_PURPOSE[(module, constant, accessor)]}"
            )
        for (module, constant, accessor), kept_from, inside in read_half:
            struct, member = OFFSETS[(module, constant)]
            print(
                f"      {module + '.' + accessor:<40} keeps bytes from "
                f"{kept_from} of the slot, and {struct}.{member} starts at "
                f"{inside}"
            )
        for (module, constant, accessor), widths, member_width in read_disagree:
            struct, member = OFFSETS[(module, constant)]
            print(
                f"      {module + '.' + accessor:<40} reads "
                f"{'/'.join(str(w) for w in widths)}  sizeof({struct}.{member}) is"
                f" {member_width}   {read_at[(module, constant, accessor)]}"
            )

    wrote_here, wrote_at = write_widths()
    write_agree = 0
    write_disagree = []
    write_unchecked = []
    for key, per in sorted(wrote_here.items()):
        module, offset, accessor = key
        widths = sorted(per[here])
        if not widths:
            continue
        member_width = member_sizes.get((module, offset))
        if member_width is None:
            struct, member = OFFSETS.get((module, offset), ("", ""))
            write_unchecked.append(
                f"{module + '.' + accessor:<40} writes {offset}, and C has no"
                f" width for {struct}.{member}"
            )
        elif widths == [member_width]:
            write_agree += 1
        else:
            write_disagree.append((module, offset, accessor, widths, member_width))

    if wrote_here:
        asked = write_agree + len(write_disagree) + len(write_unchecked)
        print(f"\n  Written widths, for the {asked} setters that write a member:")
        print(f"      {write_agree} agree with sizeof")
        for module, offset, accessor, widths, member_width in write_disagree:
            struct, member = OFFSETS.get((module, offset), ("", ""))
            print(
                f"      {module + '.' + accessor:<40} writes "
                f"{'/'.join(str(w) for w in widths)}  sizeof({struct}.{member})"
                f" is {member_width}   {wrote_at[(module, offset, accessor)]}"
            )
        for line in write_unchecked:
            print(f"      {line}")

    roomed = rooms()
    room_agree = 0
    room_disagree = []
    room_unasked = []
    if roomed:
        room_here, room_unread = mojo_numbers(
            sorted({(module, room) for module, _offset, room in roomed})
        )
        for (module, offset, room), place in sorted(roomed.items()):
            struct, member = OFFSETS.get((module, offset), ("", ""))
            member_width = member_sizes.get((module, offset))
            given = room_here.get((module, room))
            if given is None:
                room_unasked.append(f"{module}.{room} Mojo will not say  ({place})")
            elif member_width is None:
                room_unasked.append(
                    f"{module}.{room} C has no width for {struct}.{member}"
                    f"  ({place})"
                )
            elif given == member_width:
                room_agree += 1
            else:
                room_disagree.append(
                    (module, room, struct, member, given, member_width, place)
                )
        asked = room_agree + len(room_disagree) + len(room_unasked)
        print(f"\n  Room given to read or write a member, for the {asked}:")
        print(f"      {room_agree} agree with sizeof")
        for module, room, struct, member, given, member_width, place in room_disagree:
            print(
                f"      {module + '.' + room:<40} says {given:>4}  "
                f"sizeof({struct}.{member}) is {member_width}   {place}"
            )
        for line in room_unasked:
            print(f"      {line}")

    wide_here, wide_unread = mojo_numbers(list(WIDTHS))
    wide_by_c, wide_absent = c_layouts(
        [(f"{module}.{name}", WIDTHS[(module, name)]) for module, name in WIDTHS]
    )
    width_disagree = []
    width_agree = 0
    for module, name in WIDTHS:
        label = f"{module}.{name}"
        if (module, name) in wide_unread or label not in wide_by_c:
            continue
        if wide_here[(module, name)] == wide_by_c[label][0]:
            width_agree += 1
        else:
            width_disagree.append(
                (label, WIDTHS[(module, name)], wide_here[(module, name)], wide_by_c[label][0])
            )

    print(f"\n  {len(WIDTHS)} constants state how wide a C type is:")
    print(f"      {width_agree} agree with sizeof")
    for label, c_type, said, actual in width_disagree:
        print(f"      {label:<40} says {said}  sizeof({c_type}) is {actual}")
    for module, name in WIDTHS:
        label = f"{module}.{name}"
        if (module, name) in wide_unread:
            print(f"      {label:<40} Mojo will not say")
        elif label in wide_absent:
            print(f"      {label:<40} C has no {WIDTHS[(module, name)]}")

    fielded = [f for _l, _m, _n, fields in declared for f in fields]
    held_as_bytes = [
        label
        for label, _module, _name, fields in declared
        if len(fields) == 1 and fields[0].startswith("_")
    ]
    covered = {module for module, _constant in OFFSETS}
    not_listed = [
        label for label in held_as_bytes if label.rsplit(".", 1)[0] not in covered
    ]
    if fielded:
        print(
            f"\n  The other {len(fielded)} members are declared in order and left to Mojo"
            f" to lay out, which is C's arrangement when the order is and says"
            f" nothing when it is not."
        )
    if not_listed:
        # Held as bytes and naming no offset: either nothing here reads a
        # member out of it, which is every one of these now, or a member is
        # read at a number that has not been written down. Either way what
        # is claimed is a size, and the size check above is what covers it.
        print(
            f"  And {len(not_listed)} structs hold their bytes in a buffer and name"
            f" no offset, which is a size rather than a layout and is checked as"
            f" one: {', '.join(not_listed[:6])}{', ...' if len(not_listed) > 6 else ''}"
        )

    unlisted = [
        (module, name, place)
        for (module, name), place in placed_by_hand().items()
        if (module, name) not in OFFSETS
    ]
    if unlisted:
        print(
            f"\n  {len(unlisted)} place a member by hand and are not in the list,"
            f" so nothing asks `offsetof` about them:"
        )
        for module, name, place in sorted(unlisted):
            print(f"      {module + '.' + name:<44} not asked  ({place})")

    unsaid = read_at_a_literal()
    if unsaid:
        print(
            f"\n  {len(unsaid)} read or write a member at a number written in"
            f" the call, where no list can see it:"
        )
        for line in unsaid:
            print(f"      {line}")

    stated = {
        "offsets": len(OFFSETS),
        "fielded": len(fielded),
        "bytes": len(not_listed),
        "linux_only": len(LINUX_ONLY),
        "rooms": len(roomed),
    }
    wrong_stated = stated_counts(stated)
    if wrong_stated:
        print("\n  docs/beyond-c.md disagrees about the counts:")
        for line in wrong_stated:
            print(f"      {line}")
    else:
        print(
            f"\n  docs/beyond-c.md says {stated['offsets']} by hand,"
            f" {stated['fielded']} in order, {stated['bytes']} a size and"
            f" {stated['linux_only']} Linux's, which is what they are"
        )

    print()
    if disagree or offset_disagree:
        print("  *** structs that disagree with C ***")
    if wrong_stated:
        print("  *** docs/beyond-c.md no longer says what is true ***")
    if unlisted:
        print("  *** constants that place a member and are not asked about ***")
    if unsaid:
        print("  *** members read or written at a number that is not named ***")
    if width_disagree:
        print("  *** constants that say the wrong width for a C type ***")
    if read_disagree or read_half:
        print("  *** members read at a width or an offset C does not agree with ***")
    if room_disagree:
        print("  *** members given a room C says they do not have ***")
    if write_disagree:
        print("  *** members written at a width C does not agree with ***")
    if (
        disagree
        or offset_disagree
        or wrong_stated
        or unlisted
        or unsaid
        or width_disagree
        or read_disagree
        or read_half
        or room_disagree
        or write_disagree
    ):
        return 1
    print("  nothing disagrees with C")
    return 0


if __name__ == "__main__":
    sys.exit(main())
