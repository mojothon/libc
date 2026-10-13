# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
comptime sa_family_t = UInt16
comptime socklen_t = UInt32
comptime in_addr_t = UInt32
comptime in_port_t = UInt16
comptime in_addr = UInt32


# Address Family Constants
comptime AF_UNSPEC = 0
comptime AF_UNIX = 1
comptime AF_LOCAL = AF_UNIX
comptime AF_INET = 2
comptime AF_AX25 = 3
comptime AF_IPX = 4
comptime AF_APPLETALK = 5
comptime AF_NETROM = 6
comptime AF_BRIDGE = 7
comptime AF_ATMPVC = 8
comptime AF_X25 = 9
comptime AF_INET6 = 10
comptime AF_ROSE = 11
comptime AF_DECnet = 12
comptime AF_NETBEUI = 13
comptime AF_SECURITY = 14
comptime AF_KEY = 15
comptime AF_NETLINK = 16
comptime AF_ROUTE = AF_NETLINK
comptime AF_PACKET = 17
comptime AF_ASH = 18
comptime AF_ECONET = 19
comptime AF_ATMSVC = 20
comptime AF_RDS = 21
comptime AF_SNA = 22
comptime AF_IRDA = 23
comptime AF_PPPOX = 24
comptime AF_WANPIPE = 25
comptime AF_LLC = 26
comptime AF_CAN = 29
comptime AF_TIPC = 30
comptime AF_BLUETOOTH = 31
comptime AF_IUCV = 32
comptime AF_RXRPC = 33
comptime AF_ISDN = 34
comptime AF_PHONET = 35
comptime AF_IEEE802154 = 36
comptime AF_CAIF = 37
comptime AF_ALG = 38
comptime AF_NFC = 39
comptime AF_VSOCK = 40
comptime AF_KCM = 41
comptime AF_QIPCRTR = 42
comptime AF_MAX = 43 if CompilationTarget.is_macos() else 46

from std.sys import CompilationTarget

comptime PF_UNSPEC = AF_UNSPEC
comptime PF_UNIX = AF_UNIX
comptime PF_LOCAL = AF_LOCAL
comptime PF_INET = AF_INET
comptime PF_AX25 = AF_AX25
comptime PF_IPX = AF_IPX
comptime PF_APPLETALK = AF_APPLETALK
comptime PF_NETROM = AF_NETROM
comptime PF_BRIDGE = AF_BRIDGE
comptime PF_ATMPVC = AF_ATMPVC
comptime PF_X25 = AF_X25
comptime PF_INET6 = AF_INET6
comptime PF_ROSE = AF_ROSE
comptime PF_DECnet = AF_DECnet
comptime PF_NETBEUI = AF_NETBEUI
comptime PF_SECURITY = AF_SECURITY
comptime PF_KEY = AF_KEY
comptime PF_NETLINK = AF_NETLINK
comptime PF_ROUTE = AF_ROUTE
comptime PF_PACKET = AF_PACKET
comptime PF_ASH = AF_ASH
comptime PF_ECONET = AF_ECONET
comptime PF_ATMSVC = AF_ATMSVC
comptime PF_RDS = AF_RDS
comptime PF_SNA = AF_SNA
comptime PF_IRDA = AF_IRDA
comptime PF_PPPOX = AF_PPPOX
comptime PF_WANPIPE = AF_WANPIPE
comptime PF_LLC = AF_LLC
comptime PF_CAN = AF_CAN
comptime PF_TIPC = AF_TIPC
comptime PF_BLUETOOTH = AF_BLUETOOTH
comptime PF_IUCV = AF_IUCV
comptime PF_RXRPC = AF_RXRPC
comptime PF_ISDN = AF_ISDN
comptime PF_PHONET = AF_PHONET
comptime PF_IEEE802154 = AF_IEEE802154
comptime PF_CAIF = AF_CAIF
comptime PF_ALG = AF_ALG
comptime PF_NFC = AF_NFC
comptime PF_VSOCK = AF_VSOCK
comptime PF_KCM = AF_KCM
comptime PF_QIPCRTR = AF_QIPCRTR
comptime PF_MAX = AF_MAX

# Socket Type constants
comptime SOCK_STREAM = 1
comptime SOCK_DGRAM = 2
comptime SOCK_RAW = 3
comptime SOCK_RDM = 4
comptime SOCK_SEQPACKET = 5
comptime SOCK_DCCP = 6
comptime SOCK_PACKET = 10
# alias SOCK_CLOEXEC = O_CLOEXEC
# alias SOCK_NONBLOCK = O_NONBLOCK
comptime MSG_DONTWAIT = 64

# Protocol constants. Unlike the ones above, which each platform chose for
# itself, these are the numbers assigned to the protocols themselves, so
# whichever of the two this is compiled on it is the same 6 and 17.
comptime IPPROTO_IP = 0
comptime IPPROTO_ICMP = 1
comptime IPPROTO_IGMP = 2
comptime IPPROTO_TCP = 6
comptime IPPROTO_UDP = 17
comptime IPPROTO_IPV6 = 41
comptime IPPROTO_RAW = 255
comptime IPPROTO_ICMPV6 = 58


# Address Information
comptime AI_PASSIVE = 1
comptime AI_CANONNAME = 2
comptime AI_NUMERICHOST = 4
comptime AI_V4MAPPED = 8
comptime AI_ALL = 16
comptime AI_ADDRCONFIG = 32
comptime AI_IDN = 64

comptime INET_ADDRSTRLEN = 16
comptime INET6_ADDRSTRLEN = 46

comptime SHUT_RD = 0
comptime SHUT_WR = 1
comptime SHUT_RDWR = 2


comptime SOL_SOCKET = 1

comptime SO_DEBUG = 1
comptime SO_REUSEADDR = 2
comptime SO_TYPE = 3
comptime SO_ERROR = 4
comptime SO_DONTROUTE = 5
comptime SO_BROADCAST = 6
comptime SO_SNDBUF = 7
comptime SO_RCVBUF = 8
comptime SO_KEEPALIVE = 9
comptime SO_OOBINLINE = 10
comptime SO_NO_CHECK = 11
comptime SO_PRIORITY = 12
comptime SO_LINGER = 13
comptime SO_BSDCOMPAT = 14
comptime SO_REUSEPORT = 15
comptime SO_PASSCRED = 16
comptime SO_PEERCRED = 17
comptime SO_RCVLOWAT = 18
comptime SO_SNDLOWAT = 19
comptime SO_RCVTIMEO = 20
comptime SO_SNDTIMEO = 21
# alias SO_RCVTIMEO_OLD = 20
# alias SO_SNDTIMEO_OLD = 21
comptime SO_SECURITY_AUTHENTICATION = 22
comptime SO_SECURITY_ENCRYPTION_TRANSPORT = 23
comptime SO_SECURITY_ENCRYPTION_NETWORK = 24
comptime SO_BINDTODEVICE = 25
comptime SO_ATTACH_FILTER = 26
comptime SO_DETACH_FILTER = 27
comptime SO_GET_FILTER = SO_ATTACH_FILTER
comptime SO_PEERNAME = 28
comptime SO_TIMESTAMP = 29
# alias SO_TIMESTAMP_OLD = 29
comptime SO_ACCEPTCONN = 30
comptime SO_PEERSEC = 31
comptime SO_SNDBUFFORCE = 32
comptime SO_RCVBUFFORCE = 33
comptime SO_PASSSEC = 34
comptime SO_TIMESTAMPNS = 35
# alias SO_TIMESTAMPNS_OLD = 35
comptime SO_MARK = 36
comptime SO_TIMESTAMPING = 37
# alias SO_TIMESTAMPING_OLD = 37
comptime SO_PROTOCOL = 38
comptime SO_DOMAIN = 39
comptime SO_RXQ_OVFL = 40
comptime SO_WIFI_STATUS = 41
comptime SCM_WIFI_STATUS = SO_WIFI_STATUS
comptime SO_PEEK_OFF = 42
comptime SO_NOFCS = 43
comptime SO_LOCK_FILTER = 44
comptime SO_SELECT_ERR_QUEUE = 45
comptime SO_BUSY_POLL = 46
comptime SO_MAX_PACING_RATE = 47
comptime SO_BPF_EXTENSIONS = 48
comptime SO_INCOMING_CPU = 49
comptime SO_ATTACH_BPF = 50
comptime SO_DETACH_BPF = SO_DETACH_FILTER
comptime SO_ATTACH_REUSEPORT_CBPF = 51
comptime SO_ATTACH_REUSEPORT_EBPF = 52
comptime SO_CNX_ADVICE = 53
comptime SCM_TIMESTAMPING_OPT_STATS = 54
comptime SO_MEMINFO = 55
comptime SO_INCOMING_NAPI_ID = 56
comptime SO_COOKIE = 57
comptime SCM_TIMESTAMPING_PKTINFO = 58
comptime SO_PEERGROUPS = 59
comptime SO_ZEROCOPY = 60
comptime SO_TXTIME = 61
comptime SCM_TXTIME = SO_TXTIME
comptime SO_BINDTOIFINDEX = 62
comptime SO_TIMESTAMP_NEW = 63
comptime SO_TIMESTAMPNS_NEW = 64
comptime SO_TIMESTAMPING_NEW = 65
comptime SO_RCVTIMEO_NEW = 66
comptime SO_SNDTIMEO_NEW = 67
comptime SO_DETACH_REUSEPORT_BPF = 68
