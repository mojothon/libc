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
        isalpha_l,
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
        isspace_l,
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
        readdir_r,
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
        flock,
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
        preadv,
        printf,
        pwrite,
        pwritev,
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


def bring_in_libc_getopt():
    from libc.getopt import (
        Option,
        getopt_long,
        getopt_long_only,
        no_argument,
        optarg,
        opterr,
        optind,
        optopt,
        optional_argument,
        required_argument,
        set_opterr,
        set_optind,
    )


def bring_in_libc_termios():
    from libc.termios import (
        B0,
        B110,
        B115200,
        B1200,
        B134,
        B150,
        B1800,
        B19200,
        B200,
        B230400,
        B2400,
        B300,
        B38400,
        B4800,
        B50,
        B57600,
        B600,
        B75,
        B9600,
        NCCS,
        TCIFLUSH,
        TCIOFLUSH,
        TCOFLUSH,
        TCSADRAIN,
        TCSAFLUSH,
        TCSANOW,
        TCOOFF,
        TCOON,
        TCIOFF,
        TCION,
        Termios,
        cfgetispeed,
        cfgetospeed,
        cfmakeraw,
        cfsetspeed,
        cfsetispeed,
        cfsetospeed,
        tcdrain,
        tcflow,
        tcflush,
        tcgetattr,
        tcgetsid,
        tcsendbreak,
        tcsetattr,
    )


def bring_in_libc_mutex():
    from libc.pthread import (
        PTHREAD_MUTEX_DEFAULT,
        PTHREAD_MUTEX_ERRORCHECK,
        PTHREAD_MUTEX_NORMAL,
        PTHREAD_MUTEX_RECURSIVE,
        PTHREAD_PRIO_INHERIT,
        PTHREAD_PRIO_NONE,
        PTHREAD_PRIO_PROTECT,
        PTHREAD_PROCESS_PRIVATE,
        PTHREAD_PROCESS_SHARED,
        pthread_kill,
        pthread_mutex_destroy,
        pthread_mutex_getprioceiling,
        pthread_mutex_init,
        pthread_mutex_lock,
        pthread_mutex_setprioceiling,
        pthread_mutex_t,
        pthread_mutex_trylock,
        pthread_mutex_unlock,
        pthread_mutexattr_destroy,
        pthread_mutexattr_getprioceiling,
        pthread_mutexattr_getprotocol,
        pthread_mutexattr_getpshared,
        pthread_mutexattr_gettype,
        pthread_mutexattr_init,
        pthread_mutexattr_setprioceiling,
        pthread_mutexattr_setprotocol,
        pthread_mutexattr_setpshared,
        pthread_mutexattr_settype,
        pthread_mutexattr_t,
        pthread_sigmask,
    )


def bring_in_libc_sync():
    from libc.pthread import (
        pthread_cond_broadcast,
        pthread_cond_destroy,
        pthread_cond_init,
        pthread_cond_signal,
        pthread_cond_t,
        pthread_cond_timedwait,
        pthread_cond_wait,
        pthread_condattr_destroy,
        pthread_condattr_getpshared,
        pthread_condattr_init,
        pthread_condattr_setpshared,
        pthread_rwlock_destroy,
        pthread_rwlock_init,
        pthread_rwlock_rdlock,
        pthread_rwlock_t,
        pthread_rwlock_tryrdlock,
        pthread_rwlock_trywrlock,
        pthread_rwlock_unlock,
        pthread_rwlock_wrlock,
        pthread_rwlockattr_destroy,
        pthread_rwlockattr_getpshared,
        pthread_rwlockattr_init,
        pthread_rwlockattr_setpshared,
        pthread_rwlockattr_t,
    )


def bring_in_libc_grp():
    from libc.grp import (
        endgrent,
        getgrent,
        getgrgid,
        getgrgid_r,
        getgrnam,
        getgrnam_r,
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


def bring_in_libc_ifaddrs():
    from libc.ifaddrs import (
        IFF_BROADCAST,
        IFF_LOOPBACK,
        IFF_POINTOPOINT,
        IFF_RUNNING,
        IFF_UP,
        freeifaddrs,
        getifaddrs,
        ifaddrs,
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


def bring_in_libc_langinfo():
    from libc.langinfo import (
        ABDAY_1,
        ABMON_1,
        AM_STR,
        CODESET,
        DAY_1,
        D_FMT,
        D_T_FMT,
        MON_1,
        NOEXPR,
        PM_STR,
        RADIXCHAR,
        T_FMT,
        NL_CAT_LOCALE,
        NL_SETD,
        THOUSEP,
        YESEXPR,
        catclose,
        catgets,
        catopen,
        nl_langinfo,
        nl_langinfo_l,
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
        lgamma,
        lgamma_r,
        lgammaf,
        lgammaf_r,
        llabs,
        llrint,
        llrintf,
        llround,
        llroundf,
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
        lrint,
        lrintf,
        lround,
        lroundf,
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
        endhostent,
        endprotoent,
        endservent,
        freeaddrinfo,
        gai_strerror,
        getaddrinfo,
        gethostbyaddr,
        gethostbyname,
        gethostbyname2,
        gethostent,
        getnameinfo,
        getprotobyname,
        getprotobynumber,
        getservbyname,
        getservbyport,
        herror,
        hostent,
        hstrerror,
        protoent,
        servent,
        sethostent,
        setprotoent,
        setservent,
    )


def bring_in_libc_netif():
    from libc.netif import (
        IF_NAMESIZE,
        IfNameindex,
        if_freenameindex,
        if_indextoname,
        if_nameindex,
        if_nametoindex,
    )


def bring_in_libc_network():
    from libc.network import (
        htonl,
        htons,
        in_addr,
        inet_addr,
        inet_aton,
        inet_lnaof,
        inet_makeaddr,
        inet_netof,
        inet_network,
        inet_ntoa,
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
        PTHREAD_CANCEL_ASYNCHRONOUS,
        PTHREAD_CANCEL_DEFERRED,
        PTHREAD_CANCEL_DISABLE,
        PTHREAD_CANCEL_ENABLE,
        PTHREAD_CREATE_DETACHED,
        PTHREAD_CREATE_JOINABLE,
        PTHREAD_EXPLICIT_SCHED,
        PTHREAD_INHERIT_SCHED,
        PTHREAD_PRIO_INHERIT,
        PTHREAD_PRIO_NONE,
        PTHREAD_PRIO_PROTECT,
        PTHREAD_PROCESS_PRIVATE,
        PTHREAD_PROCESS_SHARED,
        PTHREAD_SCOPE_SYSTEM,
        pthread_atfork,
        pthread_attr_destroy,
        pthread_attr_getdetachstate,
        pthread_attr_getguardsize,
        pthread_attr_getinheritsched,
        pthread_attr_getscope,
        pthread_attr_getschedparam,
        pthread_attr_getschedpolicy,
        pthread_attr_getstack,
        pthread_attr_getstacksize,
        pthread_attr_init,
        pthread_attr_setdetachstate,
        pthread_attr_setguardsize,
        pthread_attr_setinheritsched,
        pthread_attr_setscope,
        pthread_attr_setschedparam,
        pthread_attr_setschedpolicy,
        pthread_attr_setstack,
        pthread_attr_setstacksize,
        pthread_attr_t,
        pthread_cancel,
        pthread_condattr_destroy,
        pthread_condattr_t,
        pthread_detach,
        pthread_equal,
        pthread_getspecific,
        pthread_key_create,
        pthread_key_delete,
        pthread_key_t,
        pthread_self,
        pthread_setcancelstate,
        pthread_setcanceltype,
        pthread_setspecific,
        pthread_t,
        pthread_testcancel,
    )


def bring_in_libc_pwd():
    from libc.pwd import (
        endpwent,
        getpwent,
        getpwnam,
        getpwnam_r,
        getpwuid,
        getpwuid_r,
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


def bring_in_libc_semaphore():
    from libc.semaphore import (
        Semaphore,
        sem_close,
        sem_open,
        sem_post,
        sem_trywait,
        sem_unlink,
        sem_wait,
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
        killpg,
        psignal,
        sigaction,
        sigaddset,
        sigaltstack,
        sigdelset,
        sigemptyset,
        sigfillset,
        siginterrupt,
        sigismember,
        signal,
        sigpending,
        sigprocmask,
        sigsuspend,
        sigwait,
    )


def bring_in_libc_spawn():
    from libc.spawn import (
        POSIX_SPAWN_RESETIDS,
        POSIX_SPAWN_SETSCHEDPARAM,
        POSIX_SPAWN_SETSCHEDULER,
        POSIX_SPAWN_SETSIGDEF,
        POSIX_SPAWN_SETSIGMASK,
        POSIX_SPAWN_SETPGROUP,
        posix_spawn,
        posix_spawn_file_actions_addclose,
        posix_spawn_file_actions_addopen,
        posix_spawn_file_actions_adddup2,
        posix_spawn_file_actions_destroy,
        posix_spawn_file_actions_init,
        posix_spawn_file_actions_t,
        posix_spawnattr_destroy,
        posix_spawnattr_getflags,
        posix_spawnattr_getpgroup,
        posix_spawnattr_init,
        posix_spawnattr_setflags,
        posix_spawnattr_setpgroup,
        posix_spawnattr_setsigmask,
        posix_spawnattr_setsigdefault,
        posix_spawnattr_t,
        posix_spawnp,
    )


def bring_in_libc_stdio():
    from libc.stdio import (
        BUFSIZ,
        IOFBF,
        IOLBF,
        IONBF,
        clearerr_unlocked,
        ctermid,
        feof_unlocked,
        ferror_unlocked,
        fgetpos,
        fileno,
        fileno_unlocked,
        flockfile,
        fpos_t,
        fputc,
        fsetpos,
        ftrylockfile,
        funlockfile,
        fwrite,
        getc,
        getc_unlocked,
        getchar,
        getchar_unlocked,
        getw,
        open_memstream,
        pclose,
        perror,
        popen,
        putc,
        putc_unlocked,
        putchar,
        putchar_unlocked,
        puts,
        putw,
        remove,
        rename,
        renameat,
        setbuf,
        setbuffer,
        setlinebuf,
        setvbuf,
        tempnam,
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
        a64l,
        abort,
        aligned_alloc,
        atof,
        atoi,
        atol,
        atoll,
        calloc,
        div,
        div_t,
        drand48,
        erand48,
        exit,
        free,
        getenv,
        getloadavg,
        getsubopt,
        initstate,
        jrand48,
        l64a,
        lcong48,
        ldiv,
        ldiv_t,
        lldiv,
        lldiv_t,
        lrand48,
        malloc,
        mblen,
        mbtowc,
        mkdtemp,
        mkstemp,
        mktemp,
        mrand48,
        nrand48,
        posix_memalign,
        putenv,
        rand,
        rand_r,
        random,
        realloc,
        realpath,
        rpmatch,
        secure_getenv,
        seed48,
        setenv,
        setstate,
        srand,
        srand48,
        srandom,
        strtod,
        strtof,
        strtol,
        strtoll,
        strtoq,
        strtoul,
        strtoull,
        strtouq,
        system,
        unsetenv,
        valloc,
        wctomb,
    )


def bring_in_libc_string():
    from libc.string import (
        bcmp,
        bcopy,
        bzero,
        ffs,
        ffsl,
        ffsll,
        index,
        memccpy,
        memchr,
        memcmp,
        memcpy,
        memmem,
        memmove,
        mempcopy,
        memset,
        rindex,
        stpcpy,
        stpncpy,
        strcasecmp,
        strcasecmp_l,
        strcat,
        strchr,
        strcmp,
        strcoll,
        strcoll_l,
        strcopy,
        strcpy,
        strcspn,
        strdup,
        strerror,
        strlen,
        strncasecmp,
        strncasecmp_l,
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
        strxfrm_l,
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


def bring_in_libc_sys_ipc():
    from libc.sys.ipc import (
        IPC_CREAT,
        IPC_EXCL,
        IPC_NOWAIT,
        IPC_PRIVATE,
        IPC_RMID,
        IPC_SET,
        IPC_STAT,
        ftok,
        key_t,
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


def bring_in_libc_sys_msg():
    from libc.sys.msg import (
        MSG_NOERROR,
        msgctl,
        msgget,
        msgrcv,
        msqid_ds,
        msgsnd,
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
        getentropy,
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


def bring_in_libc_sys_sem():
    from libc.sys.sem import (
        GETVAL,
        SEM_UNDO,
        sembuf,
        semctl,
        semget,
        semop,
    )


def bring_in_libc_sys_sendfile():
    from libc.sys.sendfile import (
        sendfile,
    )


def bring_in_libc_sys_shm():
    from libc.sys.shm import (
        SHM_RDONLY,
        SHM_RND,
        shmat,
        shmctl,
        shmdt,
        shmget,
        shmid_ds,
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
        recvmsg,
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
        fstatat,
        futimens,
        futimes,
        lstat,
        lutimes,
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
        utimes,
    )

    from libc.sys.times import (
        times,
        tms,
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
        wait3,
        wait4,
        waitpid,
    )


def bring_in_libc_time():
    from libc.time import (
        CLOCKS_PER_SEC,
        CLOCK_MONOTONIC,
        CLOCK_REALTIME,
        ITIMER_PROF,
        ITIMER_REAL,
        ITIMER_VIRTUAL,
        TIME_UTC,
        adjtime,
        asctime,
        asctime_r,
        clock,
        clock_getres,
        clock_gettime,
        clock_settime,
        ctime,
        ctime_r,
        difftime,
        getitimer,
        gettimeofday,
        gmtime,
        itimerval,
        gmtime_r,
        localtime,
        localtime_r,
        mktime,
        nanosleep,
        setitimer,
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
        endusershell,
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
        getdomainname,
        getdtablesize,
        getegid,
        geteuid,
        getgid,
        getgroups,
        gethostid,
        gethostname,
        getopt,
        getpagesize,
        getpgid,
        getpgrp,
        getpid,
        getppid,
        getsid,
        gettid,
        getuid,
        getusershell,
        getwd,
        isatty,
        ttyname,
        ttyname_r,
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
        setusershell,
        sleep,
        swab,
        symlink,
        symlinkat,
        syscall,
        sysconf,
        truncate,
        ualarm,
        unlink,
        unlinkat,
        usleep,
        write,
        writev,
    )


def bring_in_libc_wchar():
    from libc.wchar import (
        WEOF,
        btowc,
        fgetwc,
        fgetws,
        fputwc,
        fputws,
        fwide,
        getwc,
        getwchar,
        iswalnum,
        iswalpha,
        iswblank,
        iswcntrl,
        iswdigit,
        iswgraph,
        iswlower,
        iswprint,
        iswpunct,
        iswspace,
        iswupper,
        iswxdigit,
        mbrlen,
        mbrtowc,
        mbsinit,
        mbsnrtowcs,
        mbsrtowcs,
        mbstate_t,
        mbstowcs,
        putwc,
        putwchar,
        towlower,
        towupper,
        ungetwc,
        wcpcpy,
        wcpncpy,
        wcrtomb,
        wcscasecmp,
        wcscasecmp_l,
        wcscat,
        wcschr,
        wcscmp,
        wcscoll,
        wcscoll_l,
        wcscpy,
        wcscspn,
        wcsdup,
        wcsftime,
        wcsftime_l,
        wcslen,
        wcsncasecmp,
        wcsncasecmp_l,
        wcsncat,
        wcsncmp,
        wcsncpy,
        wcsnrtombs,
        wcsrchr,
        wcsrtombs,
        wcsspn,
        wcsstr,
        wcstod,
        wcstod_l,
        wcstof,
        wcstof_l,
        wcstok,
        wcstol,
        wcstol_l,
        wcstoll,
        wcstoll_l,
        wcstombs,
        wcstoul,
        wcstoul_l,
        wcstoull,
        wcstoull_l,
        wcsxfrm,
        wcsxfrm_l,
        wctob,
        wmemchr,
        wmemcmp,
        wmemcpy,
        wmemmove,
        wmemset,
    )


def bring_in_libc_wordexp():
    from libc.wordexp import (
        WRDE_APPEND,
        WRDE_DOOFFS,
        WRDE_NOCMD,
        wordfree,
        wordexp,
        wordexp_t,
    )


def bring_in_libc_wctype():
    from libc.wctype import (
        towctrans,
        wctrans,
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
    bring_in_libc_getopt()
    bring_in_libc_termios()
    bring_in_libc_mutex()
    bring_in_libc_sync()
    bring_in_libc_grp()
    bring_in_libc_iconv()
    bring_in_libc_ifaddrs()
    bring_in_libc_inttypes()
    bring_in_libc_langinfo()
    bring_in_libc_libgen()
    bring_in_libc_locale()
    bring_in_libc_logging()
    bring_in_libc_math()
    bring_in_libc_netdb()
    bring_in_libc_netif()
    bring_in_libc_network()
    bring_in_libc_poll()
    bring_in_libc_pthread()
    bring_in_libc_pwd()
    bring_in_libc_regex()
    bring_in_libc_sched()
    bring_in_libc_search()
    bring_in_libc_semaphore()
    bring_in_libc_setjmp()
    bring_in_libc_signal()
    bring_in_libc_stdio()
    bring_in_libc_spawn()
    bring_in_libc_stdlib()
    bring_in_libc_string()
    bring_in_libc_sys_auxv()
    bring_in_libc_sys_epoll()
    bring_in_libc_sys_ipc()
    bring_in_libc_sys_mman()
    bring_in_libc_sys_msg()
    bring_in_libc_sys_prctl()
    bring_in_libc_sys_random()
    bring_in_libc_sys_resource()
    bring_in_libc_sys_select()
    bring_in_libc_sys_sem()
    bring_in_libc_sys_sendfile()
    bring_in_libc_sys_shm()
    bring_in_libc_sys_socket()
    bring_in_libc_sys_stat()
    bring_in_libc_sys_statvfs()
    bring_in_libc_sys_utsname()
    bring_in_libc_sys_wait()
    bring_in_libc_time()
    bring_in_libc_unistd()
    bring_in_libc_wchar()
    bring_in_libc_wordexp()
    bring_in_libc_wctype()
    print("test_import_all: ok")
