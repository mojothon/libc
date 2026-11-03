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


def mojo_offsets() -> tuple[dict[tuple[str, str], int], list[tuple[str, str]]]:
    """What Mojo says each of those numbers is on this platform.

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

    ask(list(OFFSETS))
    return said, missing


def c_offsets() -> tuple[dict[tuple[str, str], int], list[tuple[str, str]]]:
    """What `offsetof` says for each of them, one struct at a time.

    Every member of one struct comes out of one compilation, which keeps
    this at four builds rather than twenty-two. A member C does not have
    under that name would take the rest of its struct down with it, so a
    struct that will not build is asked again a member at a time — that
    being the likeliest way for a field to be spelled wrongly here.
    """
    said: dict[tuple[str, str], int] = {}
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
            f'    printf("_{index} %zu\\n", offsetof({kind}, {member}));'
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
            if len(parts) == 2 and parts[0].startswith("_"):
                seen[parts[0]] = int(parts[1])
        if not all(f"_{index}" in seen for index in range(len(members))):
            return False
        for index, (key, _member) in enumerate(members):
            said[key] = seen[f"_{index}"]
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
    return said, missing


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

    placed_here, unread = mojo_offsets()
    placed_by_c, unheard_of = c_offsets()
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

    stated = {
        "offsets": len(OFFSETS),
        "fielded": len(fielded),
        "bytes": len(not_listed),
        "linux_only": len(LINUX_ONLY),
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
    if disagree or offset_disagree or wrong_stated:
        return 1
    print("  nothing disagrees with C")
    return 0


if __name__ == "__main__":
    sys.exit(main())
