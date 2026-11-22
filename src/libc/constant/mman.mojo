from std.sys import CompilationTarget

comptime PROT_NONE = 0
comptime PROT_READ = 1
comptime PROT_WRITE = 2
comptime PROT_EXEC = 4

comptime MAP_FILE = 0
comptime MAP_SHARED = 1
comptime MAP_PRIVATE = 2
comptime MAP_FIXED = 16
# Both spell it both ways; they differ in how much memory they ask for
# being anonymous: 32 on glibc, 4096 on Darwin, where it is `MAP_ANON`
# that came first and `MAP_ANONYMOUS` is the alias.
comptime MAP_ANONYMOUS: Int32 = 4096 if CompilationTarget.is_macos() else 32
comptime MAP_ANON: Int32 = 4096 if CompilationTarget.is_macos() else 32

comptime MS_ASYNC = 1
comptime MS_INVALIDATE = 2
# Not the same number on the two: 4 on glibc and 16 on Darwin, which is
# what makes a sync written as a literal wait on one and write on the
# other.
comptime MS_SYNC: Int32 = 16 if CompilationTarget.is_macos() else 4

comptime MADV_NORMAL = 0
comptime MADV_RANDOM = 1
comptime MADV_SEQUENTIAL = 2
comptime MADV_WILLNEED = 3
comptime MADV_DONTNEED = 4
comptime MADV_FREE: Int32 = 5 if CompilationTarget.is_macos() else 8

comptime POSIX_MADV_NORMAL = 0
comptime POSIX_MADV_RANDOM = 1
comptime POSIX_MADV_SEQUENTIAL = 2
comptime POSIX_MADV_WILLNEED = 3
comptime POSIX_MADV_DONTNEED = 4

comptime MCL_CURRENT = 1
comptime MCL_FUTURE = 2
# The advice the Linux kernel takes and Darwin does not: the bits
# about forking and dumping and huge pages and KSM are the Linux
# kernel's own ideas, and the numbers are what its headers say.
# The numbers are written without a platform conditional -- the
# other platform's headers have no name of these at all, so the
# check that asks C there finds nothing to disagree with.
comptime MADV_REMOVE: Int32 = 9
comptime MADV_DONTFORK: Int32 = 10
comptime MADV_DOFORK: Int32 = 11
comptime MADV_MERGEABLE: Int32 = 12
comptime MADV_UNMERGEABLE: Int32 = 13
comptime MADV_HUGEPAGE: Int32 = 14
comptime MADV_NOHUGEPAGE: Int32 = 15
comptime MADV_DONTDUMP: Int32 = 16
comptime MADV_DODUMP: Int32 = 17
comptime MADV_WIPEONFORK: Int32 = 18
comptime MADV_KEEPONFORK: Int32 = 19
comptime MADV_COLD: Int32 = 20
comptime MADV_PAGEOUT: Int32 = 21
comptime MADV_POPULATE_READ: Int32 = 22
comptime MADV_POPULATE_WRITE: Int32 = 23
