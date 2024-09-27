# errno -l  test ubuntu x86_64
alias EPERM = 1 # 不允许的操作
alias ENOENT = 2 # 没有那个文件或目录
alias ESRCH = 3 # 没有那个进程
alias EINTR = 4 # 被中断的系统调用
alias EIO = 5 # 输入/输出错误
alias ENXIO = 6 # 没有那个设备或地址
alias E2BIG = 7 # 参数列表过长
alias ENOEXEC = 8  # 可执行文件格式错误
alias EBADF = 9 # 错误的文件描述符
alias ECHILD = 10 # 没有子进程
alias EAGAIN = 11 # 资源暂时不可用
alias ENOMEM = 12 # 无法分配内存
alias EACCES = 13 # 权限不够
alias EFAULT = 14 # 错误的地址
alias ENOTBLK = 15 # 需要块设备
alias EBUSY = 16 # 设备或资源忙
alias EEXIST = 17 # 文件已存在
alias EXDEV = 18 # 无效的跨设备链接
alias ENODEV = 19 # 没有那个设备
alias ENOTDIR = 20 # 不是目录
alias EISDIR = 21 # 是一个目录
alias EINVAL = 22 # 无效的参数
alias ENFILE = 23 # 系统中打开的文件过多
alias EMFILE = 24 # 打开的文件过多
alias ENOTTY = 25 # 对设备不适当的 ioctl 操作
alias ETXTBSY = 26 # 文本文件忙
alias EFBIG = 27 # 文件过大
alias ENOSPC = 28 # 设备上没有空间
alias ESPIPE = 29 # 非法 seek 操作
alias EROFS = 30 # 只读文件系统
alias EMLINK = 31 # 过多的链接
alias EPIPE = 32 # 断开的管道
alias EDOM = 33 # 数值参数超出定义域
alias ERANGE = 34 # 数值结果超出值域
alias EDEADLK = 35 # 已避免资源死锁
alias ENAMETOOLONG = 36 # 文件名过长
alias ENOLCK = 37 # 没有可用的锁
alias ENOSYS = 38 # 函数未实现
alias ENOTEMPTY = 39 # 目录非空
alias ELOOP = 40 # 符号链接的层数过多
alias EWOULDBLOCK = 11 # 资源暂时不可用
alias ENOMSG = 42 # 没有所需类型的消息
alias EIDRM = 43 # 标识符已删除
alias ECHRNG = 44 # 通道编号超出范围
alias EL2NSYNC = 45 # 级别 2 尚未同步
alias EL3HLT = 46 # 级别 3 已关闭
alias EL3RST = 47 # 级别 3 已重置
alias ELNRNG = 48 # 链接数超出范围
alias EUNATCH = 49 # 未加载协议驱动程序
alias ENOCSI = 50 # 没有可用的 CSI 结构
alias EL2HLT = 51 # 级别 2 己关闭
alias EBADE = 52 # 无效的交换
alias EBADR = 53 # 无效的请求描述符
alias EXFULL = 54 # 交换满
alias ENOANO = 55 # 没有 anode
alias EBADRQC = 56 # 无效的请求码
alias EBADSLT = 57 # 无效的 slot
alias EDEADLOCK = 35 # 已避免资源死锁
alias EBFONT = 59 # 错误的字体文件格式
alias ENOSTR = 60 # 设备不是流
alias ENODATA = 61 # 没有可用的数据
alias ETIME = 62 # 计时器过期
alias ENOSR = 63 # 流资源不足
alias ENONET = 64 # 机器不在网络中
alias ENOPKG = 65 # 包未安装
alias EREMOTE = 66 # 对象是远程的
alias ENOLINK = 67 # 链接已被切断
alias EADV = 68 # 通知错误
alias ESRMNT = 69 # Srmount 错误
alias ECOMM = 70 # 发送时出现通讯错误
alias EPROTO = 71 # 协议错误
alias EMULTIHOP = 72 # 试图多跳
alias EDOTDOT = 73 # RFS 特定错误
alias EBADMSG = 74 # 错误的消息
alias EOVERFLOW = 75 # 对已定义的数据类型来说值过大
alias ENOTUNIQ = 76 # 网络上的名称不是唯一的
alias EBADFD = 77 # 文件描述符处于错误状态
alias EREMCHG = 78 # 远程地址已改变
alias ELIBACC = 79 # 无法访问必需的共享库
alias ELIBBAD = 80 # 访问已损坏的共享库
alias ELIBSCN = 81 # a.out 中的 .lib 节已毁坏
alias ELIBMAX = 82 # 试图与过多的共享库相链接
alias ELIBEXEC = 83 # 无法直接执行共享库
alias EILSEQ = 84 # 无效或不完整的多字节字符或宽字符
alias ERESTART = 85 # 被中断的系统调用应当重新启动
alias ESTRPIPE = 86 # 流管道错误
alias EUSERS = 87 # 用户过多
alias ENOTSOCK = 88 # 对非套接字进行套接字操作
alias EDESTADDRREQ = 89 # 需要目标地址
alias EMSGSIZE = 90 # 消息过长
alias EPROTOTYPE = 91 # 用于套接字的协议类型错误
alias ENOPROTOOPT = 92 # 不可用的协议
alias EPROTONOSUPPORT = 93 # 不支持的协议
alias ESOCKTNOSUPPORT = 94 # 不支持的套接字类型
alias EOPNOTSUPP = 95 # 不支持的操作
alias EPFNOSUPPORT = 96 # 不支持的协议族
alias EAFNOSUPPORT = 97 # 协议不支持的地址族
alias EADDRINUSE = 98 # 地址已在使用
alias EADDRNOTAVAIL = 99 # 无法分配被请求的地址
alias ENETDOWN = 100 # 网络已关闭
alias ENETUNREACH = 101 # 网络不可达
alias ENETRESET = 102 # 网络连接在重置时断开
alias ECONNABORTED = 103 # 由软件导致的连接中止
alias ECONNRESET = 104 # 连接被对方重置
alias ENOBUFS = 105  # 没有可用的缓冲区空间
alias EISCONN = 106 # 传输端点已连接
alias ENOTCONN = 107 # 传输端点尚未连接
alias ESHUTDOWN = 108 # 无法在传输端点关闭以后发送
alias ETOOMANYREFS = 109 # 过多的引用：无法接合
alias ETIMEDOUT = 110 # 连接超时
alias ECONNREFUSED = 111 # 连接被拒绝
alias EHOSTDOWN = 112 # 主机已关闭
alias EHOSTUNREACH = 113 # 没有到主机的路由
alias EALREADY = 114 # 操作已经在进行
alias EINPROGRESS = 115 # 操作现在正在进行
alias ESTALE = 116 # 过旧的文件句柄
alias EUCLEAN = 117 # 结构需要清理
alias ENOTNAM = 118 # 不是 XENIX 命名类型文件
alias ENAVAIL = 119 # 没有可用的 XENIX 信号量
alias EISNAM = 120 # 是一个命名类型文件
alias EREMOTEIO = 121 # 远程 I/O 错误
alias EDQUOT = 122 # 超出磁盘配额
alias ENOMEDIUM = 123 # 找不到介质
alias EMEDIUMTYPE = 124 # 错误的介质类型
alias ECANCELED = 125 # 操作已取消
alias ENOKEY = 126 # 需要的密钥不存在
alias EKEYEXPIRED = 127 #  密钥已过期
alias EKEYREVOKED = 128 # 密钥已被撤销
alias EKEYREJECTED = 129 # 密钥被服务拒绝
alias EOWNERDEAD = 130 # 拥有者已结束
alias ENOTRECOVERABLE = 131 # 状态无法恢复
alias ERFKILL = 132 # 由于 RF-kill 而无法操作
alias EHWPOISON = 133 # 内存页有硬件错误
alias ENOTSUP = 95 # 不支持的操作