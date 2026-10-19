# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <getopt.h>.
#
# Taking a command line apart. `getopt` is in `libc.unistd`, where POSIX
# puts it; what is here is the long-option pair that glibc and Darwin
# both carry, the array that describes the long options, and the four
# globals the pair reports through -- which are data and not functions,
# so they are reached by asking `dlsym` where they sit.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr
from libc.dlfcn import RTLD_NOW, dlclose, dlerror, dlopen, dlsym
from libc.utils import char_ptr_to_string, is_null, null_ptr, string_to_char_ptr


comptime no_argument: Int32 = 0
comptime required_argument: Int32 = 1
comptime optional_argument: Int32 = 2


struct Option:
    """A C `struct option`: one long option, and what to do with it.

    Spelled with a capital because this package spells its structs that
    way -- `Stat`, `Utsname`, `Timeval` -- and C's four letters in
    lower case would not say any more than that.

    The four members sit at 0, 8, 16 and 24, which is 32 bytes, on
    both platforms: a pointer to the name, whether it takes an
    argument, where to write `val` if `flag` is not null, and what to
    hand back if it is.

    An array of these ends in one whose every member is zero, which is
    how `getopt_long` knows where the options stop.
    """

    var name: c_ptr[UInt8]
    var has_arg: Int32
    var flag: c_ptr[Int32]
    var val: Int32

    def __init__(
        out self,
        name: c_ptr[UInt8],
        has_arg: Int32,
        flag: c_ptr[Int32],
        val: Int32,
    ):
        """One long option, as C's initialisers would write it."""
        self.name = name
        self.has_arg = has_arg
        self.flag = flag
        self.val = val


def getopt_long(
    argc: c_int,
    argv: c_ptr[c_ptr[UInt8]],
    optstring: c_ptr[UInt8],
    longopts: c_ptr[Option],
    longindex: c_ptr[c_int],
) -> c_int:
    """C library <getopt.h> function `getopt_long`.

    Reference:
        https://man7.org/linux/man-pages/man3/getopt_long.3.html

    Prototype:
        int getopt_long(int argc, char *const *argv, const char
                        *optstring, const struct option *longopts,
                        int *longindex)

    Description:
        Takes the next option from `argv`, either a short one such as
        `-o out` or a long one such as `--output out` or
        `--output=out`. Each call hands back the next option it finds
        and moves its place along; it answers -1 once there are no
        more.

    Args:
        argc: How many words `argv` holds.
        argv: The words, with a null where they end. The ones that are
            not options are left at the end of it, which is what
            `optind` then points at.
        optstring: The short options that are wanted, one letter each,
            a letter followed by a colon for one that takes an
            argument and by two colons for one that may. A leading
            `+` stops the taking apart at the first word that is not
            an option; a leading `-` hands back every word in order.
        longopts: The long options that are wanted, ending in one
            whose members are all zero.
        longindex: Where the position of the long option that was
            found is written, or null if that is of no interest.

    Returns:
        The letter of a short option, `val` from the long option that
        matched, 0 where that one says to write `val` through `flag`
        instead, `?` for an option that was not asked for or an
        argument that was missing, `:` where `optstring` began with
        one and an argument was missing, or -1 when there is nothing
        left to take apart.

    Notes:
        The value of an option's argument is not handed back. It is
        left in `optarg`, which is a global, and `optarg` here reads
        it out of wherever the library keeps it.

        `?` is written to standard error for an option that was not
        asked for, unless `opterr` is 0 or `optstring` began with
        `:`; `set_opterr` says which.
    """
    return external_call[
        "getopt_long",
        c_int,
        c_int,
        c_ptr[c_ptr[UInt8]],
        c_ptr[UInt8],
        c_ptr[Option],
        c_ptr[c_int],
    ](argc, argv, optstring, longopts, longindex)


def getopt_long_only(
    argc: c_int,
    argv: c_ptr[c_ptr[UInt8]],
    optstring: c_ptr[UInt8],
    longopts: c_ptr[Option],
    longindex: c_ptr[c_int],
) -> c_int:
    """C library <getopt.h> function `getopt_long_only`.

    Reference:
        https://man7.org/linux/man-pages/man3/getopt_long.3.html

    Prototype:
        int getopt_long_only(int argc, char *const *argv, const char
                             *optstring, const struct option *longopts,
                             int *longindex)

    Description:
        The same as `getopt_long`, except that a word beginning with a
        single dash is taken for a long option as well as for a short
        one: `-output out` means the same as `--output out`. What
        begins with a single dash is tried as a long option first and
        as a short one only if it is not one of those.

    Args:
        argc: How many words `argv` holds.
        argv: The words, with a null where they end.
        optstring: The short options that are wanted.
        longopts: The long options that are wanted, ending in one whose
            members are all zero.
        longindex: Where the position of the match is written, or null.

    Returns:
        What `getopt_long` hands back.

    Notes:
        A long option that takes no argument may be given one with
        `=`: `-output=out` is the long option `output` with the
        argument `out`.
    """
    return external_call[
        "getopt_long_only",
        c_int,
        c_int,
        c_ptr[c_ptr[UInt8]],
        c_ptr[UInt8],
        c_ptr[Option],
        c_ptr[c_int],
    ](argc, argv, optstring, longopts, longindex)


# Where the library keeps the four pieces of state that `getopt_long`
# reports through. They are global variables rather than functions, so
# there is no calling them: `dlsym` is asked where each one sits and the
# value is read out of that address.
def _address_of_the_state_named(name: c_ptr[UInt8]) raises -> c_ptr[UInt8]:
    """The address of one of the globals `getopt_long` reports through.

    Args:
        name: The C name for it -- one of `optarg`, `optind`, `optopt`,
            `opterr`.

    Returns:
        Where it sits.

    Raises:
        Error: When the handle is not given or `dlsym` will not say,
            which is what `dlerror` is there to explain.

    Notes:
        The handle is taken and handed back on each call. `dlopen`
        counts how many times it has been asked for a program that is
        already here, and a binding that let the count climb would be
        leaking it. The address stays good after the handle is handed
        back: the library these four live in does not go away.
    """
    var handle = dlopen(null_ptr[UInt8](), Int32(RTLD_NOW))
    if is_null(handle):
        raise Error("dlopen would not give a handle on the main program")

    var found = dlsym(handle, name)
    var complaint = String("")
    if is_null(found):
        var said = dlerror()
        if not is_null(said):
            complaint = (
                String("dlsym would not say where ")
                + char_ptr_to_string(name)
                + " is: "
                + char_ptr_to_string(said)
            )
        else:
            complaint = (
                String("dlsym would not say where ")
                + char_ptr_to_string(name)
                + " is"
            )
    _ = dlclose(handle)

    if is_null(found):
        raise Error(complaint)
    return found


def optarg() raises -> c_ptr[UInt8]:
    """The argument of the option `getopt_long` just handed back.

    Not a function in C but a `char *` the library writes, which is why
    there is nothing to call: this asks `dlsym` where it sits and reads
    the pointer out of that address.

    Returns:
        The argument as a C string, or null for an option that takes
        none.

    Raises:
        Error: When `dlsym` will not say where `optarg` is.

    Notes:
        Points into `argv`, or into a place the library keeps, and
        stays put only until the next call. Copy it if you mean to
        keep it.
    """
    return (
        _address_of_the_state_named(string_to_char_ptr("optarg"))
        .unsafe_bitcast[c_ptr[UInt8]]()
        .unsafe_offset(0)[]
    )


def optind() raises -> c_int:
    """Where in `argv` the next call is to look.

    Not a function in C but an `int` the library keeps, reached the
    same way as `optarg`.

    Returns:
        The place, counting from 1.

    Raises:
        Error: When `dlsym` will not say where `optind` is.

    Notes:
        Set it to 1 to start over from the beginning, which on
        Darwin is what `optreset` is for and here is `set_optind`.
    """
    return (
        _address_of_the_state_named(string_to_char_ptr("optind"))
        .unsafe_bitcast[c_int]()
        .unsafe_offset(0)[]
    )


def optopt() raises -> c_int:
    """The letter of the option that was not understood.

    Not a function in C but an `int` the library writes, reached the
    same way as `optarg`.

    Returns:
        The letter, when the last call handed back `?`.

    Raises:
        Error: When `dlsym` will not say where `optopt` is.
    """
    return (
        _address_of_the_state_named(string_to_char_ptr("optopt"))
        .unsafe_bitcast[c_int]()
        .unsafe_offset(0)[]
    )


def opterr() raises -> c_int:
    """Whether complaining is switched on.

    Not a function in C but an `int` the library reads, reached the
    same way as `optarg`.

    Returns:
        Not 0 when it is, which is how it starts out.

    Raises:
        Error: When `dlsym` will not say where `opterr` is.

    Notes:
        `set_opterr` with 0 keeps the library from writing anything
        about options it was not told to expect.
    """
    return (
        _address_of_the_state_named(string_to_char_ptr("opterr"))
        .unsafe_bitcast[c_int]()
        .unsafe_offset(0)[]
    )


def set_optind(place: c_int) raises:
    """Puts the place the next call is to look at.

    Args:
        place: Where, counting from 1. 1 starts over.

    Raises:
        Error: When `dlsym` will not say where `optind` is.

    Notes:
        This is the one way to parse a second command line, and the
        only one there is on glibc: the `optreset` that Darwin has is
        not part of POSIX and glibc does not carry it.
    """
    _address_of_the_state_named(string_to_char_ptr("optind")).unsafe_bitcast[
        c_int
    ]().unsafe_offset(0)[] = place


def set_opterr(complaining: c_int) raises:
    """Switches the complaining on or off.

    Args:
        complaining: 0 to keep quiet about an option that was not
        asked for, anything else to go on complaining.

    Raises:
        Error: When `dlsym` will not say where `opterr` is.

    Notes:
        The complaining goes to standard error, which is not a thing
        a binding should quieten without being asked.
    """
    _address_of_the_state_named(string_to_char_ptr("opterr")).unsafe_bitcast[
        c_int
    ]().unsafe_offset(0)[] = complaining
