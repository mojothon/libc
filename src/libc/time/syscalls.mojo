# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
fn time() -> Int64:
    """C library <time.h> function `time`.

    Reference:
        https://man7.org/linux/man-pages/man2/time.2.html

    Prototype:
        time_t time(time_t *_Nullable tloc)

    Description:
        Returns the current time value in seconds since the UNIX Epoch (00:00:00 January 1, 1970, Coordinated Universal Time (UTC) (also known as Greenwich Mean Time or GMT).

    Return Value:
        The current calendar time in seconds since 00:00:00 January 1, 1970, UTC.
    """
    return external_call["time", Int64]()
