# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr
from libc.locale import Locale, locale_t


# Every one of these is an `nl_item`, and not one of them is the same
# number on the two platforms. The schemes are different, not just the
# values: glibc packs the locale category into the high bits, so `ABDAY_1`
# is 131072 and `RADIXCHAR` is 65536, while XNU numbers the items flat
# from 0, `CODESET` being 0 and `CRNCYSTR` 56. Nor does either order
# them the same way: glibc puts the abbreviated day names before the full
# ones and XNU puts them after, so `DAY_1` and `ABDAY_1` are the other
# way round on the two.
#
# These are the fifty-five both platforms name. `YESSTR` and `NOSTR` are
# XNU's as well but glibc keeps them behind `_GNU_SOURCE` and marks them
# obsolete, and `D_MD_ORDER` is a FreeBSD extension XNU took and glibc
# never had; none of the three is here.
comptime CODESET: Int32 = 0 if CompilationTarget.is_macos() else 14
comptime D_T_FMT: Int32 = 1 if CompilationTarget.is_macos() else 131112
comptime D_FMT: Int32 = 2 if CompilationTarget.is_macos() else 131113
comptime T_FMT: Int32 = 3 if CompilationTarget.is_macos() else 131114
comptime T_FMT_AMPM: Int32 = 4 if CompilationTarget.is_macos() else 131115
comptime AM_STR: Int32 = 5 if CompilationTarget.is_macos() else 131110
comptime PM_STR: Int32 = 6 if CompilationTarget.is_macos() else 131111

# `DAY_1` is Sunday and `DAY_7` Saturday; `ABDAY_*` are the same seven
# abbreviated. Which of the two comes first is one of the things the
# platforms disagree about.
comptime DAY_1: Int32 = 7 if CompilationTarget.is_macos() else 131079
comptime DAY_2: Int32 = 8 if CompilationTarget.is_macos() else 131080
comptime DAY_3: Int32 = 9 if CompilationTarget.is_macos() else 131081
comptime DAY_4: Int32 = 10 if CompilationTarget.is_macos() else 131082
comptime DAY_5: Int32 = 11 if CompilationTarget.is_macos() else 131083
comptime DAY_6: Int32 = 12 if CompilationTarget.is_macos() else 131084
comptime DAY_7: Int32 = 13 if CompilationTarget.is_macos() else 131085
comptime ABDAY_1: Int32 = 14 if CompilationTarget.is_macos() else 131072
comptime ABDAY_2: Int32 = 15 if CompilationTarget.is_macos() else 131073
comptime ABDAY_3: Int32 = 16 if CompilationTarget.is_macos() else 131074
comptime ABDAY_4: Int32 = 17 if CompilationTarget.is_macos() else 131075
comptime ABDAY_5: Int32 = 18 if CompilationTarget.is_macos() else 131076
comptime ABDAY_6: Int32 = 19 if CompilationTarget.is_macos() else 131077
comptime ABDAY_7: Int32 = 20 if CompilationTarget.is_macos() else 131078

# `MON_1` is January, and the abbreviated twelve follow the full ones on
# XNU and precede nothing on glibc, whose month names come after its day
# names and before its abbreviations.
comptime MON_1: Int32 = 21 if CompilationTarget.is_macos() else 131098
comptime MON_2: Int32 = 22 if CompilationTarget.is_macos() else 131099
comptime MON_3: Int32 = 23 if CompilationTarget.is_macos() else 131100
comptime MON_4: Int32 = 24 if CompilationTarget.is_macos() else 131101
comptime MON_5: Int32 = 25 if CompilationTarget.is_macos() else 131102
comptime MON_6: Int32 = 26 if CompilationTarget.is_macos() else 131103
comptime MON_7: Int32 = 27 if CompilationTarget.is_macos() else 131104
comptime MON_8: Int32 = 28 if CompilationTarget.is_macos() else 131105
comptime MON_9: Int32 = 29 if CompilationTarget.is_macos() else 131106
comptime MON_10: Int32 = 30 if CompilationTarget.is_macos() else 131107
comptime MON_11: Int32 = 31 if CompilationTarget.is_macos() else 131108
comptime MON_12: Int32 = 32 if CompilationTarget.is_macos() else 131109
comptime ABMON_1: Int32 = 33 if CompilationTarget.is_macos() else 131086
comptime ABMON_2: Int32 = 34 if CompilationTarget.is_macos() else 131087
comptime ABMON_3: Int32 = 35 if CompilationTarget.is_macos() else 131088
comptime ABMON_4: Int32 = 36 if CompilationTarget.is_macos() else 131089
comptime ABMON_5: Int32 = 37 if CompilationTarget.is_macos() else 131090
comptime ABMON_6: Int32 = 38 if CompilationTarget.is_macos() else 131091
comptime ABMON_7: Int32 = 39 if CompilationTarget.is_macos() else 131092
comptime ABMON_8: Int32 = 40 if CompilationTarget.is_macos() else 131093
comptime ABMON_9: Int32 = 41 if CompilationTarget.is_macos() else 131094
comptime ABMON_10: Int32 = 42 if CompilationTarget.is_macos() else 131095
comptime ABMON_11: Int32 = 43 if CompilationTarget.is_macos() else 131096
comptime ABMON_12: Int32 = 44 if CompilationTarget.is_macos() else 131097

comptime ERA: Int32 = 45 if CompilationTarget.is_macos() else 131116
comptime ERA_D_FMT: Int32 = 46 if CompilationTarget.is_macos() else 131118
comptime ERA_D_T_FMT: Int32 = 47 if CompilationTarget.is_macos() else 131120
comptime ERA_T_FMT: Int32 = 48 if CompilationTarget.is_macos() else 131121
comptime ALT_DIGITS: Int32 = 49 if CompilationTarget.is_macos() else 131119
comptime RADIXCHAR: Int32 = 50 if CompilationTarget.is_macos() else 65536
comptime THOUSEP: Int32 = 51 if CompilationTarget.is_macos() else 65537
comptime YESEXPR: Int32 = 52 if CompilationTarget.is_macos() else 327680
comptime NOEXPR: Int32 = 53 if CompilationTarget.is_macos() else 327681
comptime CRNCYSTR: Int32 = 56 if CompilationTarget.is_macos() else 262159


# The two constants `nl_types.h` keeps for the catalog calls below, and
# the rare pair that is the same number on both platforms: `NL_SETD` is 1
# on glibc and 1 on XNU, `NL_CAT_LOCALE` is 1 on both. The first says
# which set of messages a default message belongs to, and the second is
# the flag that tells `catopen` to look the catalog up in the locale the
# process is in rather than in `LANG` read straight from the environment.
comptime NL_SETD: Int32 = 1
comptime NL_CAT_LOCALE: Int32 = 1


struct Catalog:
    """An opaque C message catalog, the thing a `nl_catd` points at.

    Empty on purpose: the catalog file's own format is the library's
    business, and it is not even the same format on the two platforms —
    glibc reads the `.mo` files `msgfmt` writes, XNU reads a format of its
    own, and neither reads the other's. All that crosses the boundary is
    the pointer, and only `catgets` and `catclose` take it back.

    The one value worth knowing is the one that means no catalog: both
    platforms answer a failed `catopen` with the all-ones pointer, and
    both `catgets` and `catclose` check for it rather than following it.
    """

    pass


comptime nl_catd = c_ptr[Catalog]


def nl_langinfo(item: Int32) -> c_ptr[UInt8]:
    """C library <langinfo.h> function `nl_langinfo`.

    Reference:
        https://man7.org/linux/man-pages/man3/nl_langinfo.3.html

    Description:
        Asks the current locale how it spells one of the things a locale
        decides: the names of the days and months, how it writes a date
        and a time, what it puts between the whole and the fractional
        part of a number, what its currency looks like, and which
        character set its text is in. `strftime` and `localeconv` answer
        the same questions in their own ways; this is the one that hands
        back a string for whatever is asked.

        Nothing here sets the locale: what comes back is the C locale's
        answer until something calls `setlocale`, and the C locale's
        answers are the ones POSIX fixes — `Sun`, `Sunday`, `January`,
        `%H:%M:%S`, and `.` for the decimal point.

    Args:
        item: Which thing to ask for, as one of the `nl_item` constants
            above. Ask for them by name: the two platforms number them
            differently in every single case, and not even in the same
            order.

    Returns:
        What the locale says, NUL terminated, in storage libc owns: the
        next call may overwrite it and nothing here frees it. An item
        nobody defines is answered with the empty string, which is the
        one answer that is not a locale's opinion — it is how this says
        "no such item" rather than by failing.

    Notes:
        Fn signature:
        `char *nl_langinfo(nl_item item)`.

        `ERA`, `ERA_D_FMT`, `ERA_D_T_FMT`, `ERA_T_FMT` and `ALT_DIGITS`
        are empty in most locales, the C one included: they are for the
        Japanese era names and for digit shapes other than the usual
        ten, and a locale that has none says so with an empty string.

        `CRNCYSTR` carries a `-` when the currency symbol goes after the
        amount and a `+` when it goes before, so the symbol itself is
        the answer without its first character, and the C locale's is a
        lone `-`.
    """
    return external_call["nl_langinfo", c_ptr[UInt8], Int32](item)


def nl_langinfo_l(item: Int32, locale: locale_t) -> c_ptr[UInt8]:
    """C library <langinfo.h> function `nl_langinfo_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/nl_langinfo.3.html

    Description:
        `nl_langinfo` asked of a locale object instead of the one the
        process is in. Nothing is switched and nothing is changed: the
        answer comes out of the `locale_t` that was handed over, so two
        locales can be asked one after the other without either of them
        being the process's, and a thread's own locale is left alone.

        The C locale's answers are the ones POSIX fixes, which makes them
        the ones to test against: a dot between the whole and the
        fractional part of a number, and nothing between the thousands.

    Args:
        item: Which thing to ask for, one of the `nl_item` constants
            above, by name — the two platforms number every one of them
            differently.
        locale: The locale object to ask, as made by `newlocale`.

    Returns:
        What that locale says, NUL terminated, in storage libc owns: the
        next call may overwrite it and nothing here frees it.

    Notes:
        On Darwin this is declared in `xlocale/_langinfo.h`, which
        `<langinfo.h>` pulls in only where something has asked for the
        extended locales first; the symbol is in libSystem either way.
    """
    return external_call["nl_langinfo_l", c_ptr[UInt8], Int32, locale_t](
        item, locale
    )


def catopen(name: c_ptr[UInt8], oflag: Int32) -> nl_catd:
    """C library <nl_types.h> function `catopen`.

    Reference:
        https://man7.org/linux/man-pages/man3/catopen.3.html

    Description:
        Opens a message catalog — the compiled file that holds a
        program's strings in one language — and hands back the descriptor
        that `catgets` reads messages out of and `catclose` gives back.

        The file's format is the library's own and the two libraries do
        not share one: glibc reads the `.mo` files `msgfmt` writes, XNU
        reads a format of its own. A catalog is therefore a file that
        belongs to the platform it was built for, not a portable one.

    Args:
        name: The path of the catalog, or, where it is not one, a name to
            look for along the search path the environment names, NUL
            terminated.
        oflag: `NL_CAT_LOCALE` to take the language from the locale the
            process is in, or 0 to have the library read it out of the
            environment itself.

    Returns:
        The catalog descriptor, or the all-ones pointer where there was
        no catalog to open, with `errno` saying why. Both platforms
        answer a failure this way, and both `catgets` and `catclose` look
        for it before they follow the pointer.

    Notes:
        Nothing here says what a program does with a catalog it could not
        open, which is the reason `catgets` takes a string of its own: a
        program that has one to fall back on never has to know whether
        the catalog was there.

        The search path is `NLSPATH`, and the language read out of the
        environment is `LANG` — which is the whole difference between the
        two flags, and a reason to prefer `NL_CAT_LOCALE`: a thread that
        has set its own locale with `uselocale` is not in `LANG`, and only
        the flag can see what it did.
    """
    return external_call["catopen", nl_catd, c_ptr[UInt8], Int32](name, oflag)


def catgets(
    catalog: nl_catd, set_id: Int32, msg_id: Int32, s: c_ptr[UInt8]
) -> c_ptr[UInt8]:
    """C library <nl_types.h> function `catgets`.

    Reference:
        https://man7.org/linux/man-pages/man3/catgets.3.html

    Description:
        Asks a catalog for one message: the one in message set `set_id`
        under the number `msg_id`.

        The string handed in is what makes this different from every
        other lookup here — it is not an out parameter, it is the answer
        the caller wants when the catalog has nothing. So the call always
        has something to return, and a program that passes its own
        English there needs no branch for a missing catalog, for a
        catalog with no such set, or for a message the translators have
        not reached yet.

    Args:
        catalog: A descriptor from `catopen`.
        set_id: Which set of messages to look in.
        msg_id: Which message in that set.
        s: The string to answer with where the catalog has no such
            message, NUL terminated.

    Returns:
        The message from the catalog, or `s` itself — the same pointer,
        not a copy of what it points at — in storage the catalog owns
        when it came from the catalog. Both platforms answer a descriptor
        that never opened with `s` rather than following it.

    Notes:
        What comes back from a catalog is freed by `catclose` and not by
        the caller, so it is worth copying before the descriptor goes
        back.
    """
    return external_call[
        "catgets", c_ptr[UInt8], nl_catd, Int32, Int32, c_ptr[UInt8]
    ](catalog, set_id, msg_id, s)


def catclose(catalog: nl_catd) -> Int32:
    """C library <nl_types.h> function `catclose`.

    Reference:
        https://man7.org/linux/man-pages/man3/catclose.3.html

    Description:
        Gives a catalog descriptor back, along with the messages it was
        holding.

    Args:
        catalog: A descriptor from `catopen`, opened or not.

    Returns:
        Zero where the catalog was closed, or -1 with `errno` set to
        `EBADF` where the descriptor was not one — which includes the
        all-ones pointer a failed `catopen` answers with, so closing what
        never opened is an error and not a silent success.

    Notes:
        Nothing may be read out of a catalog after this, including the
        strings `catgets` handed out of it.
    """
    return external_call["catclose", Int32, nl_catd](catalog)
