"""Import every public name in every sub-package.

Nothing is called. The point is to make the linker resolve every
symbol each binding asks for, which is what a caller gets when it
imports a package and what the JIT does at materialization time.
A name a platform does not export fails here, in a test, rather
than in whatever a caller was doing when it imported us.
"""


def bring_in_libc_complex():
    from libc.complex import (
        cabs,
        cabsf,
        cacos,
        cacosf,
        cacosh,
        cacoshf,
        carg,
        cargf,
        casin,
        casinf,
        casinh,
        casinhf,
        catan,
        catanf,
        catanh,
        catanhf,
        ccos,
        ccosf,
        ccosh,
        ccoshf,
        cdouble,
        cexp,
        cexpf,
        cfloat,
        cimag,
        cimagf,
        clog,
        clogf,
        conj,
        conjf,
        cpow,
        cpowf,
        cproj,
        cprojf,
        creal,
        crealf,
        csin,
        csinf,
        csinh,
        csinhf,
        csqrt,
        csqrtf,
        ctan,
        ctanf,
        ctanh,
        ctanhf,
    )


def bring_in_libc_ctype():
    from libc.ctype import (
        isalnum,
        isalnum_l,
        isalpha,
        isascii,
        isascii_l,
        isblank,
        isblank_l,
        iscntrl,
        iscntrl_l,
        isdigit,
        isdigit_l,
        isgraph,
        isgraph_l,
        islower,
        islower_l,
        isprint,
        isprint_l,
        ispunct,
        ispunct_l,
        isspace,
        isupper,
        isupper_l,
        isxdigit,
        isxdigit_l,
        toascii,
        tolower,
        tolower_l,
        toupper,
        toupper_l,
    )


def bring_in_libc_dirent():
    from libc.dirent import (
        DIR,
        DIRENT_BYTES,
        DIRENT_NAME_OFFSET,
        DIRENT_RECLEN_OFFSET,
        DIRENT_SLOTS,
        DIRENT_TYPE_OFFSET,
        alphasort,
        closedir,
        dirent,
        dirfd,
        fdopendir,
        opendir,
        readdir,
        rewinddir,
        scandir,
        seekdir,
        telldir,
    )


def bring_in_libc_dlfcn():
    from libc.dlfcn import (
        RTLD_GLOBAL,
        RTLD_LAZY,
        RTLD_NOW,
        dlclose,
        dlerror,
        dlopen,
        dlsym,
    )


def bring_in_libc_errno():
    from libc.errno import (
        check,
        errno_message,
        errno_name,
        get_errno,
        set_errno,
    )


def bring_in_libc_fcntl():
    from libc.fcntl import (
        FD_CLOEXEC,
        F_DUPFD,
        F_GETFD,
        F_GETFL,
        F_GETLK,
        F_GETOWN,
        F_LOCK,
        F_RDLCK,
        F_SETFD,
        F_SETFL,
        F_SETLK,
        F_SETLKW,
        F_SETOWN,
        F_TEST,
        F_TLOCK,
        F_ULOCK,
        F_UNLCK,
        F_WRLCK,
        LOCK_EX,
        LOCK_NB,
        LOCK_SH,
        LOCK_UN,
        O_ACCMODE,
        O_APPEND,
        O_CLOEXEC,
        O_CREAT,
        O_DIRECT,
        O_DIRECTORY,
        O_DSYNC,
        O_EXCL,
        O_NOATIME,
        O_NOCTTY,
        O_NOFOLLOW,
        O_NONBLOCK,
        O_PATH,
        O_RDONLY,
        O_RDWR,
        O_SYNC,
        O_TMPFILE,
        O_TRUNC,
        O_WRONLY,
        creat,
        fcntl,
        lockf,
        open,
        openat,
    )


def bring_in_libc_fenv():
    from libc.fenv import (
        FE_ALL_EXCEPT,
        FE_DIVBYZERO,
        FE_DOWNWARD,
        FE_INEXACT,
        FE_INVALID,
        FE_OVERFLOW,
        FE_TONEAREST,
        FE_TOWARDZERO,
        FE_UNDERFLOW,
        FE_UPWARD,
        feclearexcept,
        fedisableexcept,
        feenableexcept,
        fegetenv,
        fegetexcept,
        fegetexceptflag,
        fegetround,
        feholdexcept,
        fenv_t,
        feraiseexcept,
        fesetenv,
        fesetexceptflag,
        fesetround,
        fetestexcept,
        feupdateenv,
        fexcept_t,
    )


def bring_in_libc_file():
    from libc.file import (
        FILE,
        clearerr,
        close,
        creat,
        dprintf,
        fclose,
        fcntl,
        fdopen,
        feof,
        ferror,
        fflush,
        fgetc,
        fgets,
        fmemopen,
        fopen,
        fputc,
        fputs,
        fread,
        freopen,
        fscanf,
        fseek,
        fseeko,
        ftell,
        ftello,
        getdelim,
        getline,
        ioctl,
        lseek,
        open,
        openat,
        pread,
        printf,
        pwrite,
        read,
        rewind,
        scanf,
        snprintf,
        sprintf,
        sscanf,
        write,
    )


def bring_in_libc_float():
    from libc.float import (
        DBL_DIG,
        DBL_EPSILON,
        DBL_MANT_DIG,
        DBL_MAX,
        DBL_MAX_10_EXP,
        DBL_MAX_EXP,
        DBL_MIN,
        DBL_MIN_10_EXP,
        DBL_MIN_EXP,
        DECIMAL_DIG,
        FLT_DIG,
        FLT_EPSILON,
        FLT_EVAL_METHOD,
        FLT_MANT_DIG,
        FLT_MAX,
        FLT_MAX_10_EXP,
        FLT_MAX_EXP,
        FLT_MIN,
        FLT_MIN_10_EXP,
        FLT_MIN_EXP,
        FLT_RADIX,
        FLT_ROUNDS,
        FLT_TRUE_MIN,
        LDBL_DIG,
        LDBL_EPSILON,
        LDBL_MANT_DIG,
        LDBL_MAX_10_EXP,
        LDBL_MAX_EXP,
        LDBL_MIN_10_EXP,
        LDBL_MIN_EXP,
    )


def bring_in_libc_fnmatch():
    from libc.fnmatch import (
        fnmatch,
    )


def bring_in_libc_glob():
    from libc.glob import (
        glob,
        glob_t,
        globfree,
    )


def bring_in_libc_grp():
    from libc.grp import (
        endgrent,
        getgrent,
        getgrgid,
        getgrnam,
        group,
        setgrent,
    )


def bring_in_libc_iconv():
    from libc.iconv import (
        iconv,
        iconv_close,
        iconv_open,
        iconv_t,
    )


def bring_in_libc_inttypes():
    from libc.inttypes import (
        imaxabs,
        imaxdiv,
        imaxdiv_t,
        strtoimax,
        strtoumax,
        wcstoimax,
        wcstoumax,
    )


def bring_in_libc_libgen():
    from libc.libgen import (
        basename,
        dirname,
    )


def bring_in_libc_locale():
    from libc.locale import (
        LC_ALL,
        LC_COLLATE,
        LC_CTYPE,
        LC_MESSAGES,
        LC_MONETARY,
        LC_NUMERIC,
        LC_TIME,
        Locale,
        duplocale,
        freelocale,
        lconv,
        locale_t,
        localeconv,
        newlocale,
        setlocale,
        uselocale,
    )


def bring_in_libc_logging():
    from libc.logging import (
        LOG_MASK,
        LOG_UPTO,
        closelog,
        openlog,
        setlogmask,
        syslog,
    )


def bring_in_libc_math():
    from libc.math import (
        abs,
        acos,
        acosf,
        acosh,
        acoshf,
        asin,
        asinf,
        asinh,
        asinhf,
        atan,
        atan2,
        atan2f,
        atanf,
        atanh,
        atanhf,
        cbrt,
        cbrtf,
        ceil,
        ceilf,
        copysign,
        copysignf,
        cos,
        cosf,
        cosh,
        coshf,
        div_t,
        erf,
        erff,
        exp,
        expf,
        expm1,
        expm1f,
        fabs,
        fabsf,
        fdim,
        fdimf,
        floor,
        floorf,
        fma,
        fmaf,
        fmax,
        fmaxf,
        fmin,
        fminf,
        fmod,
        fmodf,
        frexp,
        frexpf,
        gamma,
        gammaf,
        hypot,
        hypotf,
        ilogb,
        ilogbf,
        imaxabs,
        imaxdiv,
        imaxdiv_t,
        labs,
        ldexp,
        ldexpf,
        ldiv,
        ldiv_t,
        lgamma,
        lgamma_r,
        lgammaf,
        lgammaf_r,
        llabs,
        lldiv,
        lldiv_t,
        log,
        log10,
        log10f,
        log1p,
        log1pf,
        log2,
        log2f,
        logb,
        logbf,
        logf,
        modf,
        modff,
        nan,
        nanf,
        nearbyint,
        nearbyintf,
        nextafter,
        nextafterf,
        pow,
        powf,
        remainder,
        remainderf,
        remquo,
        remquof,
        rint,
        rintf,
        round,
        roundf,
        scalbln,
        scalblnf,
        scalbn,
        scalbnf,
        sin,
        sinf,
        sinh,
        sinhf,
        sqrt,
        sqrtf,
        tan,
        tanf,
        tanh,
        tanhf,
        tgamma,
        tgammaf,
        trunc,
        truncf,
    )


def bring_in_libc_netdb():
    from libc.netdb import (
        addrinfo,
        freeaddrinfo,
        gai_strerror,
        getaddrinfo,
        getnameinfo,
    )


def bring_in_libc_network():
    from libc.network import (
        htonl,
        htons,
        ntohl,
        ntohs,
    )


def bring_in_libc_poll():
    from libc.poll import (
        POLLERR,
        POLLHUP,
        POLLIN,
        POLLNVAL,
        POLLOUT,
        POLLPRI,
        POLLRDBAND,
        POLLRDNORM,
        POLLWRBAND,
        POLLWRNORM,
        POLL_TIMEOUT_INFINITE,
        poll,
        pollfd,
        ppoll,
    )


def bring_in_libc_pthread():
    from libc.pthread import (
        pthread_atfork,
        pthread_attr_destroy,
        pthread_attr_getdetachstate,
        pthread_attr_getguardsize,
        pthread_attr_getstack,
        pthread_attr_getstacksize,
        pthread_attr_init,
        pthread_attr_setdetachstate,
        pthread_attr_setguardsize,
        pthread_attr_setstack,
        pthread_attr_setstacksize,
        pthread_attr_t,
        pthread_condattr_destroy,
        pthread_condattr_t,
    )


def bring_in_libc_pwd():
    from libc.pwd import (
        endpwent,
        getpwent,
        getpwnam,
        getpwuid,
        passwd,
        setpwent,
    )


def bring_in_libc_regex():
    from libc.regex import (
        regcomp,
        regerror,
        regex_t,
        regexec,
        regfree,
        regmatch_t,
    )


def bring_in_libc_sched():
    from libc.sched import (
        SCHED_FIFO,
        SCHED_OTHER,
        SCHED_RR,
        sched_get_priority_max,
        sched_get_priority_min,
        sched_getaffinity,
        sched_getcpucount,
        sched_getparam,
        sched_getscheduler,
        sched_param,
        sched_rr_get_interval,
        sched_setaffinity,
        sched_setparam,
        sched_setscheduler,
        sched_yield,
        timespec,
    )


def bring_in_libc_search():
    from libc.search import (
        ENTER,
        ENTRY,
        FIND,
        hcreate,
        hdestroy,
        hsearch,
        insque,
        qelem,
        remque,
    )


def bring_in_libc_setjmp():
    from libc.setjmp import (
        longjmp,
        setjmp,
    )


def bring_in_libc_signal():
    from libc.signal import (
        SIGABRT,
        SIGALRM,
        SIGBUS,
        SIGCHLD,
        SIGCONT,
        SIGFPE,
        SIGHUP,
        SIGILL,
        SIGINT,
        SIGKILL,
        SIGPIPE,
        SIGQUIT,
        SIGSEGV,
        SIGSTKSZ,
        SIGSTOP,
        SIGTERM,
        SIGTRAP,
        SIGTSTP,
        SIGUSR1,
        SIGUSR2,
        SIG_BLOCK,
        SIG_DFL,
        SIG_ERR,
        SIG_IGN,
        SIG_SETMASK,
        SIG_UNBLOCK,
        craise,
        kill,
        sigaction,
        sigaddset,
        sigaltstack,
        sigdelset,
        sigemptyset,
        sigfillset,
        sigismember,
        signal,
        sigpending,
        sigprocmask,
        sigsuspend,
        sigwait,
    )


def bring_in_libc_stdio():
    from libc.stdio import (
        BUFSIZ,
        IOFBF,
        IOLBF,
        IONBF,
        fileno,
        flockfile,
        fputc,
        ftrylockfile,
        funlockfile,
        fwrite,
        getc,
        getchar,
        getw,
        pclose,
        perror,
        popen,
        putc,
        putchar,
        puts,
        putw,
        remove,
        rename,
        renameat,
        setbuf,
        setvbuf,
        tmpfile,
        tmpnam,
        ungetc,
    )


def bring_in_libc_stdlib():
    from libc.stdlib import (
        HUGE_VAL,
        HUGE_VALF,
        LONG_MAX,
        LONG_MIN,
        PATH_MAX,
        RAND_MAX,
        ULLONG_MAX,
        ULONG_MAX,
        abort,
        aligned_alloc,
        atof,
        atoi,
        atol,
        atoll,
        calloc,
        exit,
        free,
        getenv,
        getsubopt,
        initstate,
        malloc,
        mkdtemp,
        mkstemp,
        posix_memalign,
        putenv,
        rand,
        rand_r,
        random,
        realloc,
        realpath,
        secure_getenv,
        setenv,
        setstate,
        srand,
        srandom,
        strtod,
        strtof,
        strtol,
        strtoll,
        strtoul,
        strtoull,
        system,
        unsetenv,
    )


def bring_in_libc_string():
    from libc.string import (
        ffs,
        ffsl,
        ffsll,
        memchr,
        memcmp,
        memcpy,
        memmem,
        memmove,
        mempcopy,
        memset,
        stpcpy,
        stpncpy,
        strcasecmp,
        strcat,
        strchr,
        strcmp,
        strcoll,
        strcopy,
        strcpy,
        strcspn,
        strdup,
        strerror,
        strlen,
        strncasecmp,
        strncat,
        strncmp,
        strncopy,
        strncpy,
        strndup,
        strnlen,
        strpbrk,
        strrchr,
        strsep,
        strsignal,
        strspn,
        strstr,
        strtok,
        strtok_r,
        strxfrm,
    )


def bring_in_libc_sys_auxv():
    from libc.sys.auxv import (
        AT_NULL,
        AT_PAGESZ,
        getauxval,
    )


def bring_in_libc_sys_epoll():
    from libc.sys.epoll import (
        epoll_create,
        epoll_create1,
        epoll_ctl,
        epoll_event,
        epoll_pwait,
        epoll_pwait2,
        epoll_wait,
        timespec,
    )


def bring_in_libc_sys_mman():
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
        munmap,
        posix_madvise,
        remap_file_pages,
        shm_open,
        shm_unlink,
    )


def bring_in_libc_sys_prctl():
    from libc.sys.prctl import (
        PR_GET_DUMPABLE,
        PR_GET_NAME,
        PR_GET_PDEATHSIG,
        PR_GET_SECCOMP,
        PR_GET_SECUREBITS,
        PR_GET_TIMERSLACK,
        PR_GET_TIMING,
        PR_GET_TSC,
        PR_GET_UNALIGN,
        PR_SET_DUMPABLE,
        PR_SET_NAME,
        PR_SET_PDEATHSIG,
        PR_SET_SECCOMP,
        PR_SET_SECUREBITS,
        PR_SET_TIMERSLACK,
        PR_SET_TIMING,
        PR_SET_TSC,
        PR_SET_UNALIGN,
        prctl,
    )


def bring_in_libc_sys_random():
    from libc.sys.random import (
        GRND_INSECURE,
        getrandom,
    )


def bring_in_libc_sys_resource():
    from libc.sys.resource import (
        PRIO_PGRP,
        PRIO_PROCESS,
        PRIO_USER,
        RLIMIT_AS,
        RLIMIT_NOFILE,
        RUSAGE_CHILDREN,
        RUSAGE_SELF,
        Rlimit,
        getpriority,
        getrlimit,
        getrusage,
        nice,
        prlimit,
        setpriority,
        setrlimit,
    )


def bring_in_libc_sys_select():
    from libc.sys.select import (
        FD_CLR,
        FD_ISSET,
        FD_SET,
        FD_SETSIZE,
        FD_ZERO,
        Timeval,
        fd_set,
        pselect,
        select,
    )


def bring_in_libc_sys_sendfile():
    from libc.sys.sendfile import (
        sendfile,
    )


def bring_in_libc_sys_socket():
    from libc.sys.socket import (
        SOCK_CLOEXEC,
        SOCK_NONBLOCK,
        accept,
        accept4,
        bind,
        close,
        connect,
        getpeername,
        getsockname,
        getsockopt,
        iovec,
        listen,
        msghdr,
        recv,
        recvfrom,
        send,
        sendmsg,
        sendto,
        setsockopt,
        shutdown,
        socket,
        socketaddr,
        socketpair,
    )


def bring_in_libc_sys_stat():
    from libc.sys.stat import (
        Stat,
        chmod,
        fchmod,
        fchmodat,
        fstat,
        futimens,
        lstat,
        mkdir,
        mkdirat,
        mkfifo,
        mknod,
        mknodat,
        stat,
        timespec,
        timeval,
        umask,
        utimbuf,
        utime,
        utimensat,
    )


def bring_in_libc_sys_statvfs():
    from libc.sys.statvfs import (
        Statvfs,
        fstatvfs,
        statvfs,
    )


def bring_in_libc_sys_utsname():
    from libc.sys.utsname import (
        Utsname,
        uname,
    )


def bring_in_libc_sys_wait():
    from libc.sys.wait import (
        WCONTINUED,
        WCOREDUMP,
        WEXITSTATUS,
        WIFEXITED,
        WIFSIGNALED,
        WIFSTOPPED,
        WNOHANG,
        WSTOPSIG,
        WTERMSIG,
        WUNTRACED,
        rusage,
        wait,
        wait4,
        waitpid,
    )


def bring_in_libc_time():
    from libc.time import (
        CLOCKS_PER_SEC,
        CLOCK_MONOTONIC,
        CLOCK_REALTIME,
        TIME_UTC,
        asctime,
        asctime_r,
        clock,
        clock_getres,
        clock_gettime,
        clock_settime,
        ctime,
        ctime_r,
        difftime,
        gettimeofday,
        gmtime,
        gmtime_r,
        localtime,
        localtime_r,
        mktime,
        nanosleep,
        strftime,
        strptime,
        time,
        timegm,
        timelocal,
        timespec,
        timespec_get,
        tm,
        tzset,
    )


def bring_in_libc_unistd():
    from libc.unistd import (
        SC_PAGESIZE,
        SYS_getpid,
        access,
        alarm,
        chdir,
        chown,
        close,
        dup,
        dup2,
        dup3,
        execv,
        execve,
        execvp,
        fchdir,
        fchown,
        fchownat,
        fork,
        fpathconf,
        fsync,
        ftruncate,
        getcwd,
        getegid,
        geteuid,
        getgid,
        getopt,
        getpagesize,
        getpgid,
        getpid,
        getppid,
        getsid,
        gettid,
        getuid,
        isatty,
        lchown,
        link,
        linkat,
        lseek,
        nice,
        pause,
        pipe,
        pread,
        pwrite,
        read,
        readlink,
        readlinkat,
        readv,
        rmdir,
        setegid,
        seteuid,
        setgid,
        setpgid,
        setsid,
        setuid,
        sleep,
        swab,
        symlink,
        symlinkat,
        syscall,
        sysconf,
        truncate,
        unlink,
        unlinkat,
        usleep,
        write,
        writev,
    )


def bring_in_libc_wchar():
    from libc.wchar import (
        btowc,
        iswalnum,
        iswalpha,
        iswdigit,
        iswlower,
        iswspace,
        iswupper,
        mbrlen,
        mbrtowc,
        mbstate_t,
        mbstowcs,
        towlower,
        towupper,
        wcrtomb,
        wcscat,
        wcschr,
        wcscmp,
        wcscpy,
        wcscspn,
        wcslen,
        wcsncmp,
        wcsncpy,
        wcsrchr,
        wcsspn,
        wcsstr,
        wcstombs,
        wctob,
    )


def main() raises:
    bring_in_libc_complex()
    bring_in_libc_ctype()
    bring_in_libc_dirent()
    bring_in_libc_dlfcn()
    bring_in_libc_errno()
    bring_in_libc_fcntl()
    bring_in_libc_fenv()
    bring_in_libc_file()
    bring_in_libc_float()
    bring_in_libc_fnmatch()
    bring_in_libc_glob()
    bring_in_libc_grp()
    bring_in_libc_iconv()
    bring_in_libc_inttypes()
    bring_in_libc_libgen()
    bring_in_libc_locale()
    bring_in_libc_logging()
    bring_in_libc_math()
    bring_in_libc_netdb()
    bring_in_libc_network()
    bring_in_libc_poll()
    bring_in_libc_pthread()
    bring_in_libc_pwd()
    bring_in_libc_regex()
    bring_in_libc_sched()
    bring_in_libc_search()
    bring_in_libc_setjmp()
    bring_in_libc_signal()
    bring_in_libc_stdio()
    bring_in_libc_stdlib()
    bring_in_libc_string()
    bring_in_libc_sys_auxv()
    bring_in_libc_sys_epoll()
    bring_in_libc_sys_mman()
    bring_in_libc_sys_prctl()
    bring_in_libc_sys_random()
    bring_in_libc_sys_resource()
    bring_in_libc_sys_select()
    bring_in_libc_sys_sendfile()
    bring_in_libc_sys_socket()
    bring_in_libc_sys_stat()
    bring_in_libc_sys_statvfs()
    bring_in_libc_sys_utsname()
    bring_in_libc_sys_wait()
    bring_in_libc_time()
    bring_in_libc_unistd()
    bring_in_libc_wchar()
    print("test_import_all: ok")
