
local function syscall()

local S = {} -- exported functions

local ffi = require "ffi"
local bit = require "bit"

local arch = require("syscall-" .. ffi.arch) -- architecture specific code

S.SYS = arch.SYS -- syscalls

S.C = setmetatable({}, {__index = ffi.C})
local C = S.C

local CC = {} -- functions that might not be in C, may use syscalls

local octal = function (s) return tonumber(s, 8) end 

local t, pt, s = {}, {}, {} -- types, pointer types and sizes tables
S.t = t
S.pt = pt
S.s = s
local mt = {} -- metatables
local meth = {}

-- convenience so user need not require ffi
S.string = ffi.string
S.sizeof = ffi.sizeof
S.cast = ffi.cast
S.copy = ffi.copy
S.fill = ffi.fill
S.istype = ffi.istype

local function split(delimiter, text)
  if delimiter == "" then return {text} end
  if #text == 0 then return {} end
  local list = {}
  local pos = 1
  while true do
    local first, last = text:find(delimiter, pos)
    if first then
      list[#list + 1] = text:sub(pos, first - 1)
      pos = last + 1
    else
      list[#list + 1] = text:sub(pos)
      break
    end
  end
  return list
end

local function trim(s) -- TODO should replace underscore with space
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- metatables for constants
local function strflag(t, str) -- single value only
  if not str then return 0 end
  if type(str) ~= "string" then return str end
  if #str == 0 then return 0 end
  local s = trim(str):upper()
  local val = t[s]
  if not val then error("invalid flag: " .. s) end -- don't use this format if you don't want exceptions
  t[str] = val -- this memoizes for future use
  return val
end

mt.stringflag = {__index = strflag, __call = function(t, a) return t[a] end}

-- constants

S.STDIN_FILENO = 0
S.STDOUT_FILENO = 1
S.STDERR_FILENO = 2

-- sizes
S.PATH_MAX = 4096

-- open, fcntl
S.O_ACCMODE   = octal('0003')
S.O_RDONLY    = octal('00')
S.O_WRONLY    = octal('01')
S.O_RDWR      = octal('02')
S.O_CREAT     = octal('0100')
S.O_EXCL      = octal('0200')
S.O_NOCTTY    = octal('0400')
S.O_TRUNC     = octal('01000')
S.O_APPEND    = octal('02000')
S.O_NONBLOCK  = octal('04000')
S.O_NDELAY    = S.O_NONBLOCK
S.O_SYNC      = octal('04010000')
S.O_FSYNC     = S.O_SYNC
S.O_ASYNC     = octal('020000')
S.O_CLOEXEC   = octal('02000000')
S.O_NOATIME   = octal('01000000')
S.O_DSYNC     = octal('010000')
S.O_RSYNC     = S.O_SYNC

if ffi.abi("32bit") then S.O_LARGEFILE = octal('0100000') else S.O_LARGEFILE = 0 end

-- these are arch dependent!
if arch.oflags then arch.oflags(S)
else -- generic values from asm-generic
  S.O_DIRECTORY = octal('0200000')
  S.O_NOFOLLOW  = octal('0400000')
  S.O_DIRECT    = octal('040000')
end

-- modes
S.S_IFMT   = octal('0170000')
S.S_IFSOCK = octal('0140000')
S.S_IFLNK  = octal('0120000')
S.S_IFREG  = octal('0100000')
S.S_IFBLK  = octal('0060000')
S.S_IFDIR  = octal('0040000')
S.S_IFCHR  = octal('0020000')
S.S_IFIFO  = octal('0010000')
S.S_ISUID  = octal('0004000')
S.S_ISGID  = octal('0002000')
S.S_ISVTX  = octal('0001000')

S.S_IRWXU = octal('00700')
S.S_IRUSR = octal('00400')
S.S_IWUSR = octal('00200')
S.S_IXUSR = octal('00100')
S.S_IRWXG = octal('00070')
S.S_IRGRP = octal('00040')
S.S_IWGRP = octal('00020')
S.S_IXGRP = octal('00010')
S.S_IRWXO = octal('00007')
S.S_IROTH = octal('00004')
S.S_IWOTH = octal('00002')
S.S_IXOTH = octal('00001')

-- access
S.R_OK = 4
S.W_OK = 2
S.X_OK = 1
S.F_OK = 0

-- fcntl
S.F = setmetatable({
  DUPFD       = 0,
  GETFD       = 1,
  SETFD       = 2,
  GETFL       = 3,
  SETFL       = 4,
  GETLK       = 5,
  SETLK       = 6,
  SETLKW      = 7,
  SETOWN      = 8,
  GETOWN      = 9,
  SETSIG      = 10,
  GETSIG      = 11,
  GETLK64     = 12,
  SETLK64     = 13,
  SETLKW64    = 14,
  SETOWN_EX   = 15,
  GETOWN_EX   = 16,
  SETLEASE    = 1024,
  GETLEASE    = 1025,
  NOTIFY      = 1026,
  SETPIPE_SZ  = 1031,
  GETPIPE_SZ  = 1032,
  DUPFD_CLOEXEC = 1030,
}, mt.stringflag)

-- messy
if ffi.abi("64bit") then
  S.F.GETLK64   = S.F.GETLK
  S.F.SETLK64   = S.F.SETLK
  S.F.SETLKW64  = S.F.SETLKW
else
  S.F.GETLK     = S.F.GETLK64
  S.F.SETLK     = S.F.SETLK64
  S.F.SETLKW    = S.F.SETLKW64
end

S.FD_CLOEXEC = 1

-- note changed from F_ to FCNTL_LOCK
S.FCNTL_LOCK = {
  RDLCK = 0,
  WRLCK = 1,
  UNLCK = 2,
}

S.F_ULOCK = 0
S.F_LOCK  = 1
S.F_TLOCK = 2
S.F_TEST  = 3

--mmap
S.PROT_READ  = 0x1
S.PROT_WRITE = 0x2
S.PROT_EXEC  = 0x4
S.PROT_NONE  = 0x0
S.PROT_GROWSDOWN = 0x01000000
S.PROT_GROWSUP   = 0x02000000

-- Sharing types
S.MAP_SHARED  = 0x01
S.MAP_PRIVATE = 0x02
S.MAP_TYPE    = 0x0f
S.MAP_FIXED     = 0x10
S.MAP_FILE      = 0
S.MAP_ANONYMOUS = 0x20
S.MAP_ANON      = S.MAP_ANONYMOUS
S.MAP_32BIT     = 0x40
S.MAP_GROWSDOWN  = 0x00100
S.MAP_DENYWRITE  = 0x00800
S.MAP_EXECUTABLE = 0x01000
S.MAP_LOCKED     = 0x02000
S.MAP_NORESERVE  = 0x04000
S.MAP_POPULATE   = 0x08000
S.MAP_NONBLOCK   = 0x10000
S.MAP_STACK      = 0x20000
S.MAP_HUGETLB    = 0x40000

-- flags for `mlockall'.
S.MCL_CURRENT    = 1
S.MCL_FUTURE     = 2

-- flags for `mremap'.
S.MREMAP_MAYMOVE = 1
S.MREMAP_FIXED   = 2

-- madvise advice parameter
S.MADV = setmetatable({
  NORMAL      = 0,
  RANDOM      = 1,
  SEQUENTIAL  = 2,
  WILLNEED    = 3,
  DONTNEED    = 4,
  REMOVE      = 9,
  DONTFORK    = 10,
  DOFORK      = 11,
  MERGEABLE   = 12,
  UNMERGEABLE = 13,
  HUGEPAGE    = 14,
  NOHUGEPAGE  = 15,
  HWPOISON    = 100,
}, mt.stringflag)

-- posix fadvise
S.POSIX_FADV = setmetatable({
  NORMAL       = 0,
  RANDOM       = 1,
  SEQUENTIAL   = 2,
  WILLNEED     = 3,
  DONTNEED     = 4,
  NOREUSE      = 5,
}, mt.stringflag)

-- fallocate
S.FALLOC_FL = setmetatable({
  KEEP_SIZE  = 0x01,
  PUNCH_HOLE = 0x02,
}, mt.stringflag)

-- getpriority, setpriority flags
S.PRIO = setmetatable({
  PROCESS = 0,
  PGRP = 1,
  USER = 2,
}, mt.stringflag)

-- lseek
S.SEEK = setmetatable({
  SET = 0,
  CUR = 1,
  END = 2,
}, mt.stringflag)

-- exit
S.EXIT = setmetatable({
  SUCCESS = 0,
  FAILURE = 1,
}, mt.stringflag)

-- sigaction, note renamed SIGACT from SIG_
S.SIGACT = setmetatable({
  ERR = -1,
  DFL =  0,
  IGN =  1,
  HOLD = 2,
}, mt.stringflag)

local signals = {
"SIGHUP",
"SIGINT",
"SIGQUIT",
"SIGILL",
"SIGTRAP",
"SIGABRT",
"SIGBUS",
"SIGFPE",
"SIGKILL",
"SIGUSR1",
"SIGSEGV",
"SIGUSR2",
"SIGPIPE",
"SIGALRM",
"SIGTERM",
"SIGSTKFLT",
"SIGCHLD",
"SIGCONT",
"SIGSTOP",
"SIGTSTP",
"SIGTTIN",
"SIGTTOU",
"SIGURG",
"SIGXCPU",
"SIGXFSZ",
"SIGVTALRM",
"SIGPROF",
"SIGWINCH",
"SIGIO",
"SIGPWR",
"SIGSYS",
}

for i, v in ipairs(signals) do S[v] = i end

S.SIGIOT = 6
S.SIGUNUSED     = 31
S.SIGCLD        = S.SIGCHLD
S.SIGPOLL       = S.SIGIO

S.NSIG          = 65

-- sigprocmask note renaming of SIG_ to SIGPM
S.SIGPM = setmetatable({
  BLOCK     = 0,
  UNBLOCK   = 1,
  SETMASK   = 2,
}, mt.stringflag)

-- signalfd
S.SFD_CLOEXEC  = octal('02000000')
S.SFD_NONBLOCK = octal('04000')

-- sockets note mix of single and multiple flags
S.SOCK_STREAM    = 1
S.SOCK_DGRAM     = 2
S.SOCK_RAW       = 3
S.SOCK_RDM       = 4
S.SOCK_SEQPACKET = 5
S.SOCK_DCCP      = 6
S.SOCK_PACKET    = 10

S.SOCK_CLOEXEC  = octal('02000000')
S.SOCK_NONBLOCK = octal('04000')

-- misc socket constants
S.SCM = setmetatable({
  RIGHTS = 0x01,
  CREDENTIALS = 0x02,
}, mt.stringflag)

S.SOL_SOCKET     = 1

S.SOL_RAW        = 255
S.SOL_DECNET     = 261
S.SOL_X25        = 262
S.SOL_PACKET     = 263
S.SOL_ATM        = 264
S.SOL_AAL        = 265
S.SOL_IRDA       = 266

S.SO_DEBUG       = 1
S.SO_REUSEADDR   = 2
S.SO_TYPE        = 3
S.SO_ERROR       = 4
S.SO_DONTROUTE   = 5
S.SO_BROADCAST   = 6
S.SO_SNDBUF      = 7
S.SO_RCVBUF      = 8
S.SO_SNDBUFFORCE = 32
S.SO_RCVBUFFORCE = 33
S.SO_KEEPALIVE   = 9
S.SO_OOBINLINE   = 10
S.SO_NO_CHECK    = 11
S.SO_PRIORITY    = 12
S.SO_LINGER      = 13
S.SO_BSDCOMPAT   = 14
if arch.socketoptions then arch.socketoptions(S)
else
  S.SO_PASSCRED    = 16
  S.SO_PEERCRED    = 17
  S.SO_RCVLOWAT    = 18
  S.SO_SNDLOWAT    = 19
  S.SO_RCVTIMEO    = 20
  S.SO_SNDTIMEO    = 21
end

-- Maximum queue length specifiable by listen.
S.SOMAXCONN = 128

-- shutdown
S.SHUT = setmetatable({
  RD   = 0,
  WR   = 1,
  RDWR = 2,
}, mt.stringflag)

-- waitpid 3rd arg
S.WNOHANG       = 1
S.WUNTRACED     = 2

-- waitid
S.P = setmetatable({
  ALL  = 0,
  PID  = 1,
  PGID = 2,
}, mt.stringflag)

S.WSTOPPED      = 2
S.WEXITED       = 4
S.WCONTINUED    = 8
S.WNOWAIT       = 0x01000000

S.__WNOTHREAD    = 0x20000000
S.__WALL         = 0x40000000
S.__WCLONE       = 0x80000000
S.NOTHREAD, S.WALL, S.WCLONE = S.__WNOTHREAD, S.__WALL, S.__WCLONE

-- struct siginfo, eg waitid
local signal_reasons_gen = {}
local signal_reasons = {}

S.SI_ASYNCNL = -60
S.SI_TKILL = -6
S.SI_SIGIO = -5
S.SI_ASYNCIO = -4
S.SI_MESGQ = -3
S.SI_TIMER = -2
S.SI_QUEUE = -1
S.SI_USER = 0
S.SI_KERNEL = 0x80

for _, v in ipairs{"SI_ASYNCNL", "SI_TKILL", "SI_SIGIO", "SI_ASYNCIO", "SI_MESGQ", "SI_TIMER", "SI_QUEUE", "SI_USER", "SI_KERNEL"} do
  signal_reasons_gen[S[v]] = v
end

S.ILL_ILLOPC = 1
S.ILL_ILLOPN = 2
S.ILL_ILLADR = 3
S.ILL_ILLTRP = 4
S.ILL_PRVOPC = 5
S.ILL_PRVREG = 6
S.ILL_COPROC = 7
S.ILL_BADSTK = 8

signal_reasons[S.SIGILL] = {}
for _, v in ipairs{"ILL_ILLOPC", "ILL_ILLOPN", "ILL_ILLADR", "ILL_ILLTRP", "ILL_PRVOPC", "ILL_PRVREG", "ILL_COPROC", "ILL_BADSTK"} do
  signal_reasons[S.SIGILL][S[v]] = v
end

S.FPE_INTDIV = 1
S.FPE_INTOVF = 2
S.FPE_FLTDIV = 3
S.FPE_FLTOVF = 4
S.FPE_FLTUND = 5
S.FPE_FLTRES = 6
S.FPE_FLTINV = 7
S.FPE_FLTSUB = 8

signal_reasons[S.SIGFPE] = {}
for _, v in ipairs{"FPE_INTDIV", "FPE_INTOVF", "FPE_FLTDIV", "FPE_FLTOVF", "FPE_FLTUND", "FPE_FLTRES", "FPE_FLTINV", "FPE_FLTSUB"} do
  signal_reasons[S.SIGFPE][S[v]] = v
end

S.SEGV_MAPERR = 1
S.SEGV_ACCERR = 2

signal_reasons[S.SIGSEGV] = {}
for _, v in ipairs{"SEGV_MAPERR", "SEGV_ACCERR"} do
  signal_reasons[S.SIGSEGV][S[v]] = v
end

S.BUS_ADRALN = 1
S.BUS_ADRERR = 2
S.BUS_OBJERR = 3

signal_reasons[S.SIGBUS] = {}
for _, v in ipairs{"BUS_ADRALN", "BUS_ADRERR", "BUS_OBJERR"} do
  signal_reasons[S.SIGBUS][S[v]] = v
end

S.TRAP_BRKPT = 1
S.TRAP_TRACE = 2

signal_reasons[S.SIGTRAP] = {}
for _, v in ipairs{"TRAP_BRKPT", "TRAP_TRACE"} do
  signal_reasons[S.SIGTRAP][S[v]] = v
end

S.CLD_EXITED    = 1
S.CLD_KILLED    = 2
S.CLD_DUMPED    = 3
S.CLD_TRAPPED   = 4
S.CLD_STOPPED   = 5
S.CLD_CONTINUED = 6

signal_reasons[S.SIGCHLD] = {}
for _, v in ipairs{"CLD_EXITED", "CLD_KILLED", "CLD_DUMPED", "CLD_TRAPPED", "CLD_STOPPED", "CLD_CONTINUED"} do
  signal_reasons[S.SIGCHLD][S[v]] = v
end

S.POLL_IN  = 1
S.POLL_OUT = 2
S.POLL_MSG = 3
S.POLL_ERR = 4
S.POLL_PRI = 5
S.POLL_HUP = 6

signal_reasons[S.SIGPOLL] = {}
for _, v in ipairs{"POLL_IN", "POLL_OUT", "POLL_MSG", "POLL_ERR", "POLL_PRI", "POLL_HUP"} do
  signal_reasons[S.SIGPOLL][S[v]] = v
end

-- sigaction
S.SA_NOCLDSTOP = 0x00000001
S.SA_NOCLDWAIT = 0x00000002
S.SA_SIGINFO   = 0x00000004
S.SA_ONSTACK   = 0x08000000
S.SA_RESTART   = 0x10000000
S.SA_NODEFER   = 0x40000000
S.SA_RESETHAND = 0x80000000
S.SA_NOMASK    = S.SA_NODEFER
S.SA_ONESHOT   = S.SA_RESETHAND
S.SA_RESTORER  = 0x04000000

-- timers
S.ITIMER_REAL = 0
S.ITIMER_VIRTUAL = 1
S.ITIMER_PROF = 2

-- clocks
S.CLOCK_REALTIME = 0
S.CLOCK_MONOTONIC = 1
S.CLOCK_PROCESS_CPUTIME_ID = 2
S.CLOCK_THREAD_CPUTIME_ID = 3
S.CLOCK_MONOTONIC_RAW = 4
S.CLOCK_REALTIME_COARSE = 5
S.CLOCK_MONOTONIC_COARSE = 6

S.TIMER_ABSTIME = 1

-- adjtimex
S.ADJ_OFFSET             = 0x0001
S.ADJ_FREQUENCY          = 0x0002
S.ADJ_MAXERROR           = 0x0004
S.ADJ_ESTERROR           = 0x0008
S.ADJ_STATUS             = 0x0010
S.ADJ_TIMECONST          = 0x0020
S.ADJ_TAI                = 0x0080
S.ADJ_MICRO              = 0x1000
S.ADJ_NANO               = 0x2000
S.ADJ_TICK               = 0x4000
S.ADJ_OFFSET_SINGLESHOT  = 0x8001
S.ADJ_OFFSET_SS_READ     = 0xa001

S.STA_PLL         = 0x0001
S.STA_PPSFREQ     = 0x0002
S.STA_PPSTIME     = 0x0004
S.STA_FLL         = 0x0008
S.STA_INS         = 0x0010
S.STA_DEL         = 0x0020
S.STA_UNSYNC      = 0x0040
S.STA_FREQHOLD    = 0x0080
S.STA_PPSSIGNAL   = 0x0100
S.STA_PPSJITTER   = 0x0200
S.STA_PPSWANDER   = 0x0400
S.STA_PPSERROR    = 0x0800
S.STA_CLOCKERR    = 0x1000
S.STA_NANO        = 0x2000
S.STA_MODE        = 0x4000
S.STA_CLK         = 0x8000

S.TIME_OK         = 0
S.TIME_INS        = 1
S.TIME_DEL        = 2
S.TIME_OOP        = 3
S.TIME_WAIT       = 4
S.TIME_ERROR      = 5
S.TIME_BAD        = S.TIME_ERROR

mt.timex = {
  __index = function(timex, k)
    local prefix = "TIME_"
    if k:sub(1, #prefix) ~= prefix then k = prefix .. k:upper() end
    if S[k] then return bit.band(timex.state, S[k]) ~= 0 end
  end
}

-- xattr
S.XATTR_CREATE = 1
S.XATTR_REPLACE = 2

-- utime
S.UTIME_NOW  = bit.lshift(1, 30) - 1
S.UTIME_OMIT = bit.lshift(1, 30) - 2

-- ...at commands
S.AT_FDCWD = -100
S.AT_SYMLINK_NOFOLLOW    = 0x100
S.AT_REMOVEDIR           = 0x200
S.AT_SYMLINK_FOLLOW      = 0x400
S.AT_NO_AUTOMOUNT        = 0x800
S.AT_EACCESS             = 0x200

-- send, recv etc
S.MSG_OOB             = 0x01
S.MSG_PEEK            = 0x02
S.MSG_DONTROUTE       = 0x04
S.MSG_TRYHARD         = S.MSG_DONTROUTE
S.MSG_CTRUNC          = 0x08
S.MSG_PROXY           = 0x10
S.MSG_TRUNC           = 0x20
S.MSG_DONTWAIT        = 0x40
S.MSG_EOR             = 0x80
S.MSG_WAITALL         = 0x100
S.MSG_FIN             = 0x200
S.MSG_SYN             = 0x400
S.MSG_CONFIRM         = 0x800
S.MSG_RST             = 0x1000
S.MSG_ERRQUEUE        = 0x2000
S.MSG_NOSIGNAL        = 0x4000
S.MSG_MORE            = 0x8000
S.MSG_WAITFORONE      = 0x10000
S.MSG_CMSG_CLOEXEC    = 0x40000000

-- rlimit
S.RLIMIT_CPU = 0
S.RLIMIT_FSIZE = 1
S.RLIMIT_DATA = 2
S.RLIMIT_STACK = 3
S.RLIMIT_CORE = 4
S.RLIMIT_RSS = 5
S.RLIMIT_NPROC = 6
S.RLIMIT_NOFILE = 7
S.RLIMIT_OFILE = S.RLIMIT_NOFILE
S.RLIMIT_MEMLOCK = 8
S.RLIMIT_AS = 9
S.RLIMIT_LOCKS = 10
S.RLIMIT_SIGPENDING = 11
S.RLIMIT_MSGQUEUE = 12
S.RLIMIT_NICE = 13
S.RLIMIT_RTPRIO = 14
S.RLIMIT_RTTIME = 15

-- timerfd
S.TFD_CLOEXEC = octal("02000000")
S.TFD_NONBLOCK = octal("04000")

S.TFD_TIMER_ABSTIME = 1

-- poll
S.POLLIN          = 0x001
S.POLLPRI         = 0x002
S.POLLOUT         = 0x004
S.POLLRDNORM      = 0x040
S.POLLRDBAND      = 0x080
S.POLLWRNORM      = 0x100
S.POLLWRBAND      = 0x200
S.POLLMSG         = 0x400
S.POLLREMOVE      = 0x1000
S.POLLRDHUP       = 0x2000
S.POLLERR         = 0x008
S.POLLHUP         = 0x010
S.POLLNVAL        = 0x020

-- epoll
S.EPOLL_CLOEXEC = octal("02000000")
S.EPOLL_NONBLOCK = octal("04000")

S.EPOLLIN = 0x001
S.EPOLLPRI = 0x002
S.EPOLLOUT = 0x004
S.EPOLLRDNORM = 0x040
S.EPOLLRDBAND = 0x080
S.EPOLLWRNORM = 0x100
S.EPOLLWRBAND = 0x200
S.EPOLLMSG = 0x400
S.EPOLLERR = 0x008
S.EPOLLHUP = 0x010
S.EPOLLRDHUP = 0x2000
S.EPOLLONESHOT = bit.lshift(1, 30)
S.EPOLLET = bit.lshift(1, 30) * 2 -- 2^31 but making sure no sign issue 

mt.epoll = {
  __index = function(tab, k)
    local prefix = "EPOLL"
    if k:sub(1, #prefix) ~= prefix then k = prefix .. k:upper() end
    if S[k] then return bit.band(tab.events, S[k]) ~= 0 end
  end
}

S.EPOLL_CTL_ADD = 1
S.EPOLL_CTL_DEL = 2
S.EPOLL_CTL_MOD = 3

-- splice etc
S.SPLICE_F_MOVE         = 1
S.SPLICE_F_NONBLOCK     = 2
S.SPLICE_F_MORE         = 4
S.SPLICE_F_GIFT         = 8

-- aio - see /usr/include/linux/aio_abi.h
S.IOCB_CMD_PREAD = 0
S.IOCB_CMD_PWRITE = 1
S.IOCB_CMD_FSYNC = 2
S.IOCB_CMD_FDSYNC = 3
--S.IOCB_CMD_PREADX = 4
--S.IOCB_CMD_POLL = 5
S.IOCB_CMD_NOOP = 6
S.IOCB_CMD_PREADV = 7
S.IOCB_CMD_PWRITEV = 8

S.IOCB_FLAG_RESFD = 1

-- file types in directory
S.DT_UNKNOWN = 0
S.DT_FIFO = 1
S.DT_CHR = 2
S.DT_DIR = 4
S.DT_BLK = 6
S.DT_REG = 8
S.DT_LNK = 10
S.DT_SOCK = 12
S.DT_WHT = 14

mt.dents = {
  __index = function(tab, k)
    local prefix = "DT_"
    if k:sub(1, #prefix) ~= prefix then k = prefix .. k:upper() end
    if S[k] then return tab.type == S[k] end
  end
}

-- sync file range
S.SYNC_FILE_RANGE_WAIT_BEFORE = 1
S.SYNC_FILE_RANGE_WRITE       = 2
S.SYNC_FILE_RANGE_WAIT_AFTER  = 4

-- netlink
S.NETLINK = setmetatable({
  ROUTE         = 0,
  UNUSED        = 1,
  USERSOCK      = 2,
  FIREWALL      = 3,
  INET_DIAG     = 4,
  NFLOG         = 5,
  XFRM          = 6,
  SELINUX       = 7,
  ISCSI         = 8,
  AUDIT         = 9,
  FIB_LOOKUP    = 10,     
  CONNECTOR     = 11,
  NETFILTER     = 12,
  IP6_FW        = 13,
  DNRTMSG       = 14,
  KOBJECT_UEVENT= 15,
  GENERIC       = 16,
  SCSITRANSPORT = 18,
  ECRYPTFS      = 19,
}, mt.stringflag)

S.NLM_F_REQUEST = 1
S.NLM_F_MULTI   = 2
S.NLM_F_ACK     = 4
S.NLM_F_ECHO    = 8

S.NLM_F_ROOT    = 0x100
S.NLM_F_MATCH   = 0x200
S.NLM_F_ATOMIC  = 0x400
S.NLM_F_DUMP    = bit.bor(S.NLM_F_ROOT, S.NLM_F_MATCH)

S.NLM_F_REPLACE = 0x100
S.NLM_F_EXCL    = 0x200
S.NLM_F_CREATE  = 0x400
S.NLM_F_APPEND  = 0x800

-- generic types.
S.NLMSG_NOOP     = 0x1
S.NLMSG_ERROR    = 0x2
S.NLMSG_DONE     = 0x3
S.NLMSG_OVERRUN  = 0x4
-- routing
S.RTM_NEWLINK     = 16
S.RTM_DELLINK     = 17
S.RTM_GETLINK     = 18
S.RTM_SETLINK     = 19
S.RTM_NEWADDR     = 20
S.RTM_DELADDR     = 21
S.RTM_GETADDR     = 22
S.RTM_NEWROUTE    = 24
S.RTM_DELROUTE    = 25
S.RTM_GETROUTE    = 26
S.RTM_NEWNEIGH    = 28
S.RTM_DELNEIGH    = 29
S.RTM_GETNEIGH    = 30
S.RTM_NEWRULE     = 32
S.RTM_DELRULE     = 33
S.RTM_GETRULE     = 34
S.RTM_NEWQDISC    = 36
S.RTM_DELQDISC    = 37
S.RTM_GETQDISC    = 38
S.RTM_NEWTCLASS   = 40
S.RTM_DELTCLASS   = 41
S.RTM_GETTCLASS   = 42
S.RTM_NEWTFILTER  = 44
S.RTM_DELTFILTER  = 45
S.RTM_GETTFILTER  = 46
S.RTM_NEWACTION   = 48
S.RTM_DELACTION   = 49
S.RTM_GETACTION   = 50
S.RTM_NEWPREFIX   = 52
S.RTM_GETMULTICAST = 58
S.RTM_GETANYCAST  = 62
S.RTM_NEWNEIGHTBL = 64
S.RTM_GETNEIGHTBL = 66
S.RTM_SETNEIGHTBL = 67
S.RTM_NEWNDUSEROPT = 68
S.RTM_NEWADDRLABEL = 72
S.RTM_DELADDRLABEL = 73
S.RTM_GETADDRLABEL = 74
S.RTM_GETDCB = 78
S.RTM_SETDCB = 79

local nlmsglist = {
"NLMSG_NOOP", "NLMSG_ERROR", "NLMSG_DONE", "NLMSG_OVERRUN",
"RTM_NEWLINK", "RTM_DELLINK", "RTM_GETLINK", "RTM_SETLINK", "RTM_NEWADDR", "RTM_DELADDR", "RTM_GETADDR", "RTM_NEWROUTE", "RTM_DELROUTE", 
"RTM_GETROUTE", "RTM_NEWNEIGH", "RTM_DELNEIGH", "RTM_GETNEIGH", "RTM_NEWRULE", "RTM_DELRULE", "RTM_GETRULE", "RTM_NEWQDISC", 
"RTM_DELQDISC", "RTM_GETQDISC", "RTM_NEWTCLASS", "RTM_DELTCLASS", "RTM_GETTCLASS", "RTM_NEWTFILTER", "RTM_DELTFILTER", 
"RTM_GETTFILTER", "RTM_NEWACTION", "RTM_DELACTION", "RTM_GETACTION", "RTM_NEWPREFIX", "RTM_GETMULTICAST", "RTM_GETANYCAST", 
"RTM_NEWNEIGHTBL", "RTM_GETNEIGHTBL", "RTM_SETNEIGHTBL", "RTM_NEWNDUSEROPT", "RTM_NEWADDRLABEL", "RTM_DELADDRLABEL", "RTM_GETADDRLABEL",
"RTM_GETDCB", "RTM_SETDCB"
}
local nlmsgtypes = {} -- lookup table by value
for _, v in ipairs(nlmsglist) do
  assert(S[v], "message " .. v .. " should exist")
  nlmsgtypes[S[v]] = v
end

-- linux/if_link.h
S.IFLA_UNSPEC    = 0
S.IFLA_ADDRESS   = 1
S.IFLA_BROADCAST = 2
S.IFLA_IFNAME    = 3
S.IFLA_MTU       = 4
S.IFLA_LINK      = 5
S.IFLA_QDISC     = 6
S.IFLA_STATS     = 7
S.IFLA_COST      = 8
S.IFLA_PRIORITY  = 9
S.IFLA_MASTER    = 10
S.IFLA_WIRELESS  = 11
S.IFLA_PROTINFO  = 12
S.IFLA_TXQLEN    = 13
S.IFLA_MAP       = 14
S.IFLA_WEIGHT    = 15
S.IFLA_OPERSTATE = 16
S.IFLA_LINKMODE  = 17
S.IFLA_LINKINFO  = 18
S.IFLA_NET_NS_PID= 19
S.IFLA_IFALIAS   = 20
S.IFLA_NUM_VF    = 21
S.IFLA_VFINFO_LIST = 22
S.IFLA_STATS64   = 23
S.IFLA_VF_PORTS  = 24
S.IFLA_PORT_SELF = 25
S.IFLA_AF_SPEC   = 26
S.IFLA_GROUP     = 27
S.IFLA_NET_NS_FD = 28

S.IFLA_INET_UNSPEC = 0
S.IFLA_INET_CONF   = 1

S.IFLA_INET6_UNSPEC = 0
S.IFLA_INET6_FLAGS  = 1
S.IFLA_INET6_CONF   = 2
S.IFLA_INET6_STATS  = 3
S.IFLA_INET6_MCAST  = 4
S.IFLA_INET6_CACHEINFO  = 5
S.IFLA_INET6_ICMP6STATS = 6

S.IFLA_INFO_UNSPEC = 0
S.IFLA_INFO_KIND   = 1
S.IFLA_INFO_DATA   = 2
S.IFLA_INFO_XSTATS = 3

S.IFLA_VLAN_UNSPEC = 0
S.IFLA_VLAN_ID     = 1
S.IFLA_VLAN_FLAGS  = 2
S.IFLA_VLAN_EGRESS_QOS  = 3
S.IFLA_VLAN_INGRESS_QOS = 4

S.IFLA_VLAN_QOS_UNSPEC  = 0
S.IFLA_VLAN_QOS_MAPPING = 1

S.IFLA_MACVLAN_UNSPEC = 0
S.IFLA_MACVLAN_MODE   = 1

S.MACVLAN_MODE_PRIVATE = 1
S.MACVLAN_MODE_VEPA    = 2
S.MACVLAN_MODE_BRIDGE  = 4
S.MACVLAN_MODE_PASSTHRU = 8

S.IFLA_VF_INFO_UNSPEC = 0
S.IFLA_VF_INFO        = 1

S.IFLA_VF_UNSPEC   = 0
S.IFLA_VF_MAC      = 1
S.IFLA_VF_VLAN     = 2
S.IFLA_VF_TX_RATE  = 3
S.IFLA_VF_SPOOFCHK = 4

S.IFLA_VF_PORT_UNSPEC = 0
S.IFLA_VF_PORT        = 1

S.IFLA_PORT_UNSPEC    = 0
S.IFLA_PORT_VF        = 1
S.IFLA_PORT_PROFILE   = 2
S.IFLA_PORT_VSI_TYPE  = 3
S.IFLA_PORT_INSTANCE_UUID = 4
S.IFLA_PORT_HOST_UUID = 5
S.IFLA_PORT_REQUEST   = 6
S.IFLA_PORT_RESPONSE  = 7

S.VETH_INFO_UNSPEC = 0
S.VETH_INFO_PEER   = 1

S.PORT_PROFILE_MAX      =  40
S.PORT_UUID_MAX         =  16
S.PORT_SELF_VF          =  -1

S.PORT_REQUEST_PREASSOCIATE    = 0
S.PORT_REQUEST_PREASSOCIATE_RR = 1
S.PORT_REQUEST_ASSOCIATE       = 2
S.PORT_REQUEST_DISASSOCIATE    = 3

S.PORT_VDP_RESPONSE_SUCCESS = 0
S.PORT_VDP_RESPONSE_INVALID_FORMAT = 1
S.PORT_VDP_RESPONSE_INSUFFICIENT_RESOURCES = 2
S.PORT_VDP_RESPONSE_UNUSED_VTID = 3
S.PORT_VDP_RESPONSE_VTID_VIOLATION = 4
S.PORT_VDP_RESPONSE_VTID_VERSION_VIOALTION = 5
S.PORT_VDP_RESPONSE_OUT_OF_SYNC = 6
S.PORT_PROFILE_RESPONSE_SUCCESS = 0x100
S.PORT_PROFILE_RESPONSE_INPROGRESS = 0x101
S.PORT_PROFILE_RESPONSE_INVALID = 0x102
S.PORT_PROFILE_RESPONSE_BADSTATE = 0x103
S.PORT_PROFILE_RESPONSE_INSUFFICIENT_RESOURCES = 0x104
S.PORT_PROFILE_RESPONSE_ERROR = 0x105

-- from if_addr.h interface address types and flags
S.IFA_UNSPEC    = 0
S.IFA_ADDRESS   = 1
S.IFA_LOCAL     = 2
S.IFA_LABEL     = 3
S.IFA_BROADCAST = 4
S.IFA_ANYCAST   = 5
S.IFA_CACHEINFO = 6
S.IFA_MULTICAST = 7
S.IFA_MAX       = 7

S.IFA_F_SECONDARY   = 0x01
S.IFA_F_TEMPORARY   = S.IFA_F_SECONDARY

S.IFA_F_NODAD       = 0x02
S.IFA_F_OPTIMISTIC  = 0x04
S.IFA_F_DADFAILED   = 0x08
S.IFA_F_HOMEADDRESS = 0x10
S.IFA_F_DEPRECATED  = 0x20
S.IFA_F_TENTATIVE   = 0x40
S.IFA_F_PERMANENT   = 0x80

-- routing
S.RTN_UNSPEC      = 0
S.RTN_UNICAST     = 1
S.RTN_LOCAL       = 2
S.RTN_BROADCAST   = 3
S.RTN_ANYCAST     = 4
S.RTN_MULTICAST   = 5
S.RTN_BLACKHOLE   = 6
S.RTN_UNREACHABLE = 7
S.RTN_PROHIBIT    = 8
S.RTN_THROW       = 9
S.RTN_NAT         = 10
S.RTN_XRESOLVE    = 11

S.RTPROT_UNSPEC   = 0
S.RTPROT_REDIRECT = 1
S.RTPROT_KERNEL   = 2
S.RTPROT_BOOT     = 3
S.RTPROT_STATIC   = 4
S.RTPROT_GATED    = 8
S.RTPROT_RA       = 9
S.RTPROT_MRT      = 10
S.RTPROT_ZEBRA    = 11
S.RTPROT_BIRD     = 12
S.RTPROT_DNROUTED = 13
S.RTPROT_XORP     = 14
S.RTPROT_NTK      = 15
S.RTPROT_DHCP     = 16

S.RT_SCOPE_UNIVERSE = 0
S.RT_SCOPE_SITE = 200
S.RT_SCOPE_LINK = 253
S.RT_SCOPE_HOST = 254
S.RT_SCOPE_NOWHERE = 255

S.RTM_F_NOTIFY          = 0x100
S.RTM_F_CLONED          = 0x200
S.RTM_F_EQUALIZE        = 0x400
S.RTM_F_PREFIX          = 0x800

S.RT_TABLE_UNSPEC = 0
S.RT_TABLE_COMPAT = 252
S.RT_TABLE_DEFAULT = 253
S.RT_TABLE_MAIN = 254
S.RT_TABLE_LOCAL = 255
S.RT_TABLE_MAX = 0xFFFFFFFF

S.RTA_UNSPEC = 0
S.RTA_DST = 1
S.RTA_SRC = 2
S.RTA_IIF = 3
S.RTA_OIF = 4
S.RTA_GATEWAY = 5
S.RTA_PRIORITY = 6
S.RTA_PREFSRC = 7
S.RTA_METRICS = 8
S.RTA_MULTIPATH = 9
S.RTA_PROTOINFO = 10
S.RTA_FLOW = 11
S.RTA_CACHEINFO = 12
S.RTA_SESSION = 13
S.RTA_MP_ALGO = 14
S.RTA_TABLE = 15
S.RTA_MARK = 16

-- route flags
S.RTF_UP          = 0x0001
S.RTF_GATEWAY     = 0x0002
S.RTF_HOST        = 0x0004
S.RTF_REINSTATE   = 0x0008
S.RTF_DYNAMIC     = 0x0010
S.RTF_MODIFIED    = 0x0020
S.RTF_MTU         = 0x0040
S.RTF_MSS         = S.RTF_MTU
S.RTF_WINDOW      = 0x0080
S.RTF_IRTT        = 0x0100
S.RTF_REJECT      = 0x0200

-- ipv6 route flags
S.RTF_DEFAULT     = 0x00010000
S.RTF_ALLONLINK   = 0x00020000
S.RTF_ADDRCONF    = 0x00040000
S.RTF_PREFIX_RT   = 0x00080000
S.RTF_ANYCAST     = 0x00100000
S.RTF_NONEXTHOP   = 0x00200000
S.RTF_EXPIRES     = 0x00400000
S.RTF_ROUTEINFO   = 0x00800000
S.RTF_CACHE       = 0x01000000
S.RTF_FLOW        = 0x02000000
S.RTF_POLICY      = 0x04000000
--#define RTF_PREF(pref)  ((pref) << 27)
--#define RTF_PREF_MASK   0x18000000
S.RTF_LOCAL       = 0x80000000

-- interface flags
S.IFF_UP         = 0x1
S.IFF_BROADCAST  = 0x2
S.IFF_DEBUG      = 0x4
S.IFF_LOOPBACK   = 0x8
S.IFF_POINTOPOINT= 0x10
S.IFF_NOTRAILERS = 0x20
S.IFF_RUNNING    = 0x40
S.IFF_NOARP      = 0x80
S.IFF_PROMISC    = 0x100
S.IFF_ALLMULTI   = 0x200
S.IFF_MASTER     = 0x400
S.IFF_SLAVE      = 0x800
S.IFF_MULTICAST  = 0x1000
S.IFF_PORTSEL    = 0x2000
S.IFF_AUTOMEDIA  = 0x4000
S.IFF_DYNAMIC    = 0x8000
S.IFF_LOWER_UP   = 0x10000
S.IFF_DORMANT    = 0x20000
S.IFF_ECHO       = 0x40000

S.IFF_ALL        = 0xffffffff
S.IFF_NONE       = bit.bnot(0x7ffff) -- this is a bit of a fudge as zero should work, but does not for historical reasons see net/core/rtnetlink.c

-- not sure if we need these
S.IFF_SLAVE_NEEDARP = 0x40
S.IFF_ISATAP        = 0x80
S.IFF_MASTER_ARPMON = 0x100
S.IFF_WAN_HDLC      = 0x200
S.IFF_XMIT_DST_RELEASE = 0x400
S.IFF_DONT_BRIDGE   = 0x800
S.IFF_DISABLE_NETPOLL    = 0x1000
S.IFF_MACVLAN_PORT       = 0x2000
S.IFF_BRIDGE_PORT = 0x4000
S.IFF_OVS_DATAPATH       = 0x8000
S.IFF_TX_SKB_SHARING     = 0x10000
S.IFF_UNICAST_FLT = 0x20000

S.IFF_VOLATILE = S.IFF_LOOPBACK + S.IFF_POINTOPOINT + S.IFF_BROADCAST + S.IFF_ECHO +
                 S.IFF_MASTER + S.IFF_SLAVE + S.IFF_RUNNING + S.IFF_LOWER_UP + S.IFF_DORMANT

-- netlink multicast groups
-- legacy names, which are masks.
S.RTMGRP_LINK            = 1
S.RTMGRP_NOTIFY          = 2
S.RTMGRP_NEIGH           = 4
S.RTMGRP_TC              = 8
S.RTMGRP_IPV4_IFADDR     = 0x10
S.RTMGRP_IPV4_MROUTE     = 0x20
S.RTMGRP_IPV4_ROUTE      = 0x40
S.RTMGRP_IPV4_RULE       = 0x80
S.RTMGRP_IPV6_IFADDR     = 0x100
S.RTMGRP_IPV6_MROUTE     = 0x200
S.RTMGRP_IPV6_ROUTE      = 0x400
S.RTMGRP_IPV6_IFINFO     = 0x800
S.RTMGRP_DECNET_IFADDR   = 0x1000
S.RTMGRP_DECNET_ROUTE    = 0x4000
S.RTMGRP_IPV6_PREFIX     = 0x20000
-- rtnetlink multicast groups (bit numbers not masks)
S.RTNLGRP_NONE = 0
S.RTNLGRP_LINK = 1
S.RTNLGRP_NOTIFY = 2
S.RTNLGRP_NEIGH = 3
S.RTNLGRP_TC = 4
S.RTNLGRP_IPV4_IFADDR = 5
S.RTNLGRP_IPV4_MROUTE = 6
S.RTNLGRP_IPV4_ROUTE = 7
S.RTNLGRP_IPV4_RULE = 8
S.RTNLGRP_IPV6_IFADDR = 9
S.RTNLGRP_IPV6_MROUTE = 10
S.RTNLGRP_IPV6_ROUTE = 11
S.RTNLGRP_IPV6_IFINFO = 12
S.RTNLGRP_DECNET_IFADDR = 13
S.RTNLGRP_NOP2 = 14
S.RTNLGRP_DECNET_ROUTE = 15
S.RTNLGRP_DECNET_RULE = 16
S.RTNLGRP_NOP4 = 17
S.RTNLGRP_IPV6_PREFIX = 18
S.RTNLGRP_IPV6_RULE = 19
S.RTNLGRP_ND_USEROPT = 20
S.RTNLGRP_PHONET_IFADDR = 21
S.RTNLGRP_PHONET_ROUTE = 22
S.RTNLGRP_DCB = 23

-- address families
S.AF = setmetatable({
  UNSPEC     = 0,
  LOCAL      = 1,
  INET       = 2,
  AX25       = 3,
  IPX        = 4,
  APPLETALK  = 5,
  NETROM     = 6,
  BRIDGE     = 7,
  ATMPVC     = 8,
  X25        = 9,
  INET6      = 10,
  ROSE       = 11,
  DECNET     = 12,
  NETBEUI    = 13,
  SECURITY   = 14,
  KEY        = 15,
  NETLINK    = 16,
  PACKET     = 17,
  ASH        = 18,
  ECONET     = 19,
  ATMSVC     = 20,
  RDS        = 21,
  SNA        = 22,
  IRDA       = 23,
  PPPOX      = 24,
  WANPIPE    = 25,
  LLC        = 26,
  CAN        = 29,
  TIPC       = 30,
  BLUETOOTH  = 31,
  IUCV       = 32,
  RXRPC      = 33,
  ISDN       = 34,
  PHONET     = 35,
  IEEE802154 = 36,
  CAIF       = 37,
  ALG        = 38,
  NFC        = 39,
}, mt.stringflag)

S.AF.UNIX       = S.AF.LOCAL
S.AF.FILE       = S.AF.LOCAL
S.AF.ROUTE      = S.AF.NETLINK

-- arp types, which are also interface types for ifi_type
S.ARPHRD_NETROM   = 0
S.ARPHRD_ETHER    = 1
S.ARPHRD_EETHER   = 2
S.ARPHRD_AX25     = 3
S.ARPHRD_PRONET   = 4
S.ARPHRD_CHAOS    = 5
S.ARPHRD_IEEE802  = 6
S.ARPHRD_ARCNET   = 7
S.ARPHRD_APPLETLK = 8
S.ARPHRD_DLCI     = 15
S.ARPHRD_ATM      = 19
S.ARPHRD_METRICOM = 23
S.ARPHRD_IEEE1394 = 24
S.ARPHRD_EUI64    = 27
S.ARPHRD_INFINIBAND = 32
S.ARPHRD_SLIP     = 256
S.ARPHRD_CSLIP    = 257
S.ARPHRD_SLIP6    = 258
S.ARPHRD_CSLIP6   = 259
S.ARPHRD_RSRVD    = 260
S.ARPHRD_ADAPT    = 264
S.ARPHRD_ROSE     = 270
S.ARPHRD_X25      = 271
S.ARPHRD_HWX25    = 272
S.ARPHRD_CAN      = 280
S.ARPHRD_PPP      = 512
S.ARPHRD_CISCO    = 513
S.ARPHRD_HDLC     = S.ARPHRD_CISCO
S.ARPHRD_LAPB     = 516
S.ARPHRD_DDCMP    = 517
S.ARPHRD_RAWHDLC  = 518
S.ARPHRD_TUNNEL   = 768
S.ARPHRD_TUNNEL6  = 769
S.ARPHRD_FRAD     = 770
S.ARPHRD_SKIP     = 771
S.ARPHRD_LOOPBACK = 772
S.ARPHRD_LOCALTLK = 773
S.ARPHRD_FDDI     = 774
S.ARPHRD_BIF      = 775
S.ARPHRD_SIT      = 776
S.ARPHRD_IPDDP    = 777
S.ARPHRD_IPGRE    = 778
S.ARPHRD_PIMREG   = 779
S.ARPHRD_HIPPI    = 780
S.ARPHRD_ASH      = 781
S.ARPHRD_ECONET   = 782
S.ARPHRD_IRDA     = 783
S.ARPHRD_FCPP     = 784
S.ARPHRD_FCAL     = 785
S.ARPHRD_FCPL     = 786
S.ARPHRD_FCFABRIC = 787
S.ARPHRD_IEEE802_TR = 800
S.ARPHRD_IEEE80211 = 801
S.ARPHRD_IEEE80211_PRISM = 802
S.ARPHRD_IEEE80211_RADIOTAP = 803
S.ARPHRD_IEEE802154         = 804
S.ARPHRD_PHONET   = 820
S.ARPHRD_PHONET_PIPE = 821
S.ARPHRD_CAIF     = 822
S.ARPHRD_VOID     = 0xFFFF
S.ARPHRD_NONE     = 0xFFFE

-- IP
S.IPPROTO_IP = 0
S.IPPROTO_HOPOPTS = 0
S.IPPROTO_ICMP = 1
S.IPPROTO_IGMP = 2
S.IPPROTO_IPIP = 4
S.IPPROTO_TCP = 6
S.IPPROTO_EGP = 8
S.IPPROTO_PUP = 12
S.IPPROTO_UDP = 17
S.IPPROTO_IDP = 22
S.IPPROTO_TP = 29
S.IPPROTO_DCCP = 33
S.IPPROTO_IPV6 = 41
S.IPPROTO_ROUTING = 43
S.IPPROTO_FRAGMENT = 44
S.IPPROTO_RSVP = 46
S.IPPROTO_GRE = 47
S.IPPROTO_ESP = 50
S.IPPROTO_AH = 51
S.IPPROTO_ICMPV6 = 58
S.IPPROTO_NONE = 59
S.IPPROTO_DSTOPTS = 60
S.IPPROTO_MTP = 92
S.IPPROTO_ENCAP = 98
S.IPPROTO_PIM = 103
S.IPPROTO_COMP = 108
S.IPPROTO_SCTP = 132
S.IPPROTO_UDPLITE = 136
S.IPPROTO_RAW = 255

-- eventfd
S.EFD_SEMAPHORE = 1
S.EFD_CLOEXEC = octal("02000000")
S.EFD_NONBLOCK = octal("04000")

-- mount and umount
S.MS_RDONLY = 1
S.MS_NOSUID = 2
S.MS_NODEV = 4
S.MS_NOEXEC = 8
S.MS_SYNCHRONOUS = 16
S.MS_REMOUNT = 32
S.MS_MANDLOCK = 64
S.MS_DIRSYNC = 128
S.MS_NOATIME = 1024
S.MS_NODIRATIME = 2048
S.MS_BIND = 4096
S.MS_MOVE = 8192
S.MS_REC = 16384
S.MS_SILENT = 32768
S.MS_POSIXACL = bit.lshift(1, 16)
S.MS_UNBINDABLE = bit.lshift(1, 17)
S.MS_PRIVATE = bit.lshift(1, 18)
S.MS_SLAVE = bit.lshift(1, 19)
S.MS_SHARED = bit.lshift(1, 20)
S.MS_RELATIME = bit.lshift(1, 21)
S.MS_KERNMOUNT = bit.lshift(1, 22)
S.MS_I_VERSION = bit.lshift(1, 23)
S.MS_STRICTATIME = bit.lshift(1, 24)
S.MS_ACTIVE = bit.lshift(1, 30)
S.MS_NOUSER = bit.lshift(1, 31)

-- fake flags
S.MS_RO = S.MS_RDONLY -- allow use of "ro" as flag as that is what /proc/mounts uses
S.MS_RW = 0           -- allow use of "rw" as flag as appears in /proc/mounts

S.MNT_FORCE = 1
S.MNT_DETACH = 2
S.MNT_EXPIRE = 4
S.UMOUNT_NOFOLLOW = 8

-- flags to `msync'.
S.MS_ASYNC       = 1
S.MS_SYNC        = 4
S.MS_INVALIDATE  = 2

-- reboot
S.LINUX_REBOOT_CMD = setmetatable({
  RESTART      =  0x01234567,
  HALT         =  0xCDEF0123,
  CAD_ON       =  0x89ABCDEF,
  CAD_OFF      =  0x00000000,
  POWER_OFF    =  0x4321FEDC,
  RESTART2     =  0xA1B2C3D4,
  SW_SUSPEND   =  0xD000FCE2,
  KEXEC        =  0x45584543,
}, mt.stringflag)

-- clone
S.CLONE_VM      = 0x00000100
S.CLONE_FS      = 0x00000200
S.CLONE_FILES   = 0x00000400
S.CLONE_SIGHAND = 0x00000800
S.CLONE_PTRACE  = 0x00002000
S.CLONE_VFORK   = 0x00004000
S.CLONE_PARENT  = 0x00008000
S.CLONE_THREAD  = 0x00010000
S.CLONE_NEWNS   = 0x00020000
S.CLONE_SYSVSEM = 0x00040000
S.CLONE_SETTLS  = 0x00080000
S.CLONE_PARENT_SETTID  = 0x00100000
S.CLONE_CHILD_CLEARTID = 0x00200000
S.CLONE_DETACHED = 0x00400000
S.CLONE_UNTRACED = 0x00800000
S.CLONE_CHILD_SETTID = 0x01000000
S.CLONE_NEWUTS   = 0x04000000
S.CLONE_NEWIPC   = 0x08000000
S.CLONE_NEWUSER  = 0x10000000
S.CLONE_NEWPID   = 0x20000000
S.CLONE_NEWNET   = 0x40000000
S.CLONE_IO       = 0x80000000

-- inotify
-- flags
S.IN_CLOEXEC = octal("02000000")
S.IN_NONBLOCK = octal("04000")

-- events
S.IN_ACCESS        = 0x00000001
S.IN_MODIFY        = 0x00000002
S.IN_ATTRIB        = 0x00000004
S.IN_CLOSE_WRITE   = 0x00000008
S.IN_CLOSE_NOWRITE = 0x00000010
S.IN_OPEN          = 0x00000020
S.IN_MOVED_FROM    = 0x00000040
S.IN_MOVED_TO      = 0x00000080
S.IN_CREATE        = 0x00000100
S.IN_DELETE        = 0x00000200
S.IN_DELETE_SELF   = 0x00000400
S.IN_MOVE_SELF     = 0x00000800

S.IN_UNMOUNT       = 0x00002000
S.IN_Q_OVERFLOW    = 0x00004000
S.IN_IGNORED       = 0x00008000

S.IN_CLOSE         = S.IN_CLOSE_WRITE + S.IN_CLOSE_NOWRITE
S.IN_MOVE          = S.IN_MOVED_FROM + S.IN_MOVED_TO

S.IN_ONLYDIR       = 0x01000000
S.IN_DONT_FOLLOW   = 0x02000000
S.IN_EXCL_UNLINK   = 0x04000000
S.IN_MASK_ADD      = 0x20000000
S.IN_ISDIR         = 0x40000000
S.IN_ONESHOT       = 0x80000000

S.IN_ALL_EVENTS    = S.IN_ACCESS + S.IN_MODIFY + S.IN_ATTRIB + S.IN_CLOSE_WRITE
                       + S.IN_CLOSE_NOWRITE + S.IN_OPEN + S.IN_MOVED_FROM
                       + S.IN_MOVED_TO + S.IN_CREATE + S.IN_DELETE
                       + S.IN_DELETE_SELF + S.IN_MOVE_SELF

mt.inotify = {
  __index = function(tab, k)
    local prefix = "IN_"
    if k:sub(1, #prefix) ~= prefix then k = prefix .. k:upper() end
    if S[k] then return bit.band(tab.mask, S[k]) ~= 0 end
  end
}

--prctl
S.PR_SET_PDEATHSIG = 1
S.PR_GET_PDEATHSIG = 2
S.PR_GET_DUMPABLE  = 3
S.PR_SET_DUMPABLE  = 4
S.PR_GET_UNALIGN   = 5
S.PR_SET_UNALIGN   = 6
S.PR_UNALIGN_NOPRINT   = 1
S.PR_UNALIGN_SIGBUS    = 2
S.PR_GET_KEEPCAPS  = 7
S.PR_SET_KEEPCAPS  = 8
S.PR_GET_FPEMU     = 9
S.PR_SET_FPEMU     = 10
S.PR_FPEMU_NOPRINT     = 1
S.PR_FPEMU_SIGFPE      = 2
S.PR_GET_FPEXC     = 11
S.PR_SET_FPEXC     = 12
S.PR_FP_EXC_SW_ENABLE  = 0x80
S.PR_FP_EXC_DIV        = 0x010000
S.PR_FP_EXC_OVF        = 0x020000
S.PR_FP_EXC_UND        = 0x040000
S.PR_FP_EXC_RES        = 0x080000
S.PR_FP_EXC_INV        = 0x100000
S.PR_FP_EXC_DISABLED   = 0
S.PR_FP_EXC_NONRECOV   = 1
S.PR_FP_EXC_ASYNC      = 2
S.PR_FP_EXC_PRECISE    = 3
S.PR_GET_TIMING    = 13
S.PR_SET_TIMING    = 14
S.PR_TIMING_STATISTICAL= 0
S.PR_TIMING_TIMESTAMP  = 1
S.PR_SET_NAME      = 15
S.PR_GET_NAME      = 16
S.PR_GET_ENDIAN    = 19
S.PR_SET_ENDIAN    = 20
S.PR_ENDIAN_BIG         = 0
S.PR_ENDIAN_LITTLE      = 1
S.PR_ENDIAN_PPC_LITTLE  = 2
S.PR_GET_SECCOMP   = 21
S.PR_SET_SECCOMP   = 22
S.PR_CAPBSET_READ  = 23
S.PR_CAPBSET_DROP  = 24
S.PR_GET_TSC       = 25
S.PR_SET_TSC       = 26
S.PR_TSC_ENABLE         = 1
S.PR_TSC_SIGSEGV        = 2
S.PR_GET_SECUREBITS= 27
S.PR_SET_SECUREBITS= 28
S.PR_SET_TIMERSLACK= 29
S.PR_GET_TIMERSLACK= 30
S.PR_TASK_PERF_EVENTS_DISABLE=31
S.PR_TASK_PERF_EVENTS_ENABLE=32
S.PR_MCE_KILL      = 33
S.PR_MCE_KILL_CLEAR     = 0
S.PR_MCE_KILL_SET       = 1
S.PR_MCE_KILL_LATE         = 0
S.PR_MCE_KILL_EARLY        = 1
S.PR_MCE_KILL_DEFAULT      = 2
S.PR_MCE_KILL_GET  = 34
S.PR_SET_PTRACER   = 0x59616d61 -- Ubuntu extension

-- capabilities
S.CAP_CHOWN = 0
S.CAP_DAC_OVERRIDE = 1
S.CAP_DAC_READ_SEARCH = 2
S.CAP_FOWNER = 3
S.CAP_FSETID = 4
S.CAP_KILL = 5
S.CAP_SETGID = 6
S.CAP_SETUID = 7
S.CAP_SETPCAP = 8
S.CAP_LINUX_IMMUTABLE = 9
S.CAP_NET_BIND_SERVICE = 10
S.CAP_NET_BROADCAST = 11
S.CAP_NET_ADMIN = 12
S.CAP_NET_RAW = 13
S.CAP_IPC_LOCK = 14
S.CAP_IPC_OWNER = 15
S.CAP_SYS_MODULE = 16
S.CAP_SYS_RAWIO = 17
S.CAP_SYS_CHROOT = 18
S.CAP_SYS_PTRACE = 19
S.CAP_SYS_PACCT = 20
S.CAP_SYS_ADMIN = 21
S.CAP_SYS_BOOT = 22
S.CAP_SYS_NICE = 23
S.CAP_SYS_RESOURCE = 24
S.CAP_SYS_TIME = 25
S.CAP_SYS_TTY_CONFIG = 26
S.CAP_MKNOD = 27
S.CAP_LEASE = 28
S.CAP_AUDIT_WRITE = 29
S.CAP_AUDIT_CONTROL = 30
S.CAP_SETFCAP = 31
S.CAP_MAC_OVERRIDE = 32
S.CAP_MAC_ADMIN = 33
S.CAP_SYSLOG = 34
S.CAP_WAKE_ALARM = 35

-- new SECCOMP modes, now there is filter as well as strict
S.SECCOMP_MODE_DISABLED = 0
S.SECCOMP_MODE_STRICT   = 1
S.SECCOMP_MODE_FILTER   = 2

S.SECCOMP_RET_KILL      = 0x00000000
S.SECCOMP_RET_TRAP      = 0x00030000
S.SECCOMP_RET_ERRNO     = 0x00050000
S.SECCOMP_RET_TRACE     = 0x7ff00000
S.SECCOMP_RET_ALLOW     = 0x7fff0000

S.SECCOMP_RET_ACTION    = 0xffff0000 -- note unsigned 
S.SECCOMP_RET_DATA      = 0x0000ffff

-- termios
S.NCCS = 32

-- termios - c_cc characters
S.VINTR    = 0
S.VQUIT    = 1
S.VERASE   = 2
S.VKILL    = 3
S.VEOF     = 4
S.VTIME    = 5
S.VMIN     = 6
S.VSWTC    = 7
S.VSTART   = 8
S.VSTOP    = 9
S.VSUSP    = 10
S.VEOL     = 11
S.VREPRINT = 12
S.VDISCARD = 13
S.VWERASE  = 14
S.VLNEXT   = 15
S.VEOL2    = 16

-- termios - c_iflag bits
S.IGNBRK  = octal('0000001')
S.BRKINT  = octal('0000002')
S.IGNPAR  = octal('0000004')
S.PARMRK  = octal('0000010')
S.INPCK   = octal('0000020')
S.ISTRIP  = octal('0000040')
S.INLCR   = octal('0000100')
S.IGNCR   = octal('0000200')
S.ICRNL   = octal('0000400')
S.IUCLC   = octal('0001000')
S.IXON    = octal('0002000')
S.IXANY   = octal('0004000')
S.IXOFF   = octal('0010000')
S.IMAXBEL = octal('0020000')
S.IUTF8   = octal('0040000')

-- termios - c_oflag bits
S.OPOST  = octal('0000001')
S.OLCUC  = octal('0000002')
S.ONLCR  = octal('0000004')
S.OCRNL  = octal('0000010')
S.ONOCR  = octal('0000020')
S.ONLRET = octal('0000040')
S.OFILL  = octal('0000100')
S.OFDEL  = octal('0000200')
S.NLDLY  = octal('0000400')
S.NL0    = octal('0000000')
S.NL1    = octal('0000400')
S.CRDLY  = octal('0003000')
S.CR0    = octal('0000000')
S.CR1    = octal('0001000')
S.CR2    = octal('0002000')
S.CR3    = octal('0003000')
S.TABDLY = octal('0014000')
S.TAB0   = octal('0000000')
S.TAB1   = octal('0004000')
S.TAB2   = octal('0010000')
S.TAB3   = octal('0014000')
S.BSDLY  = octal('0020000')
S.BS0    = octal('0000000')
S.BS1    = octal('0020000')
S.FFDLY  = octal('0100000')
S.FF0    = octal('0000000')
S.FF1    = octal('0100000')
S.VTDLY  = octal('0040000')
S.VT0    = octal('0000000')
S.VT1    = octal('0040000')
S.XTABS  = octal('0014000')

local bits_speed_map = { }
local speed_bits_map = { }
local function defspeed(speed, bits)
  bits = octal(bits)
  bits_speed_map[bits] = speed
  speed_bits_map[speed] = bits
  S['B'..speed] = bits
end
local function bits_to_speed(bits)
  local speed = bits_speed_map[bits]
  if not speed then error("unknown speedbits: " .. bits) end
  return speed
end
local function speed_to_bits(speed)
  local bits = speed_bits_map[speed]
  if not bits then error("unknown speed: " .. speed) end
  return bits
end
-- termios - c_cflag bit meaning
S.CBAUD      = octal('0010017')
defspeed(0, '0000000') -- hang up
defspeed(50, '0000001')
defspeed(75, '0000002')
defspeed(110, '0000003')
defspeed(134, '0000004')
defspeed(150, '0000005')
defspeed(200, '0000006')
defspeed(300, '0000007')
defspeed(600, '0000010')
defspeed(1200, '0000011')
defspeed(1800, '0000012')
defspeed(2400, '0000013')
defspeed(4800, '0000014')
defspeed(9600, '0000015')
defspeed(19200, '0000016')
defspeed(38400, '0000017')
S.EXTA       = S.B19200
S.EXTB       = S.B38400
S.CSIZE      = octal('0000060')
S.CS5        = octal('0000000')
S.CS6        = octal('0000020')
S.CS7        = octal('0000040')
S.CS8        = octal('0000060')
S.CSTOPB     = octal('0000100')
S.CREAD      = octal('0000200')
S.PARENB     = octal('0000400')
S.PARODD     = octal('0001000')
S.HUPCL      = octal('0002000')
S.CLOCAL     = octal('0004000')
S.CBAUDEX    = octal('0010000')
defspeed(57600, '0010001')
defspeed(115200, '0010002')
defspeed(230400, '0010003')
defspeed(460800, '0010004')
defspeed(500000, '0010005')
defspeed(576000, '0010006')
defspeed(921600, '0010007')
defspeed(1000000, '0010010')
defspeed(1152000, '0010011')
defspeed(1500000, '0010012')
defspeed(2000000, '0010013')
defspeed(2500000, '0010014')
defspeed(3000000, '0010015')
defspeed(3500000, '0010016')
defspeed(4000000, '0010017')
S.__MAX_BAUD = S.B4000000
S.CIBAUD     = octal('002003600000') -- input baud rate (not used)
S.CMSPAR     = octal('010000000000') -- mark or space (stick) parity
S.CRTSCTS    = octal('020000000000') -- flow control

-- termios - c_lflag bits
S.ISIG    = octal('0000001')
S.ICANON  = octal('0000002')
S.XCASE   = octal('0000004')
S.ECHO    = octal('0000010')
S.ECHOE   = octal('0000020')
S.ECHOK   = octal('0000040')
S.ECHONL  = octal('0000100')
S.NOFLSH  = octal('0000200')
S.TOSTOP  = octal('0000400')
S.ECHOCTL = octal('0001000')
S.ECHOPRT = octal('0002000')
S.ECHOKE  = octal('0004000')
S.FLUSHO  = octal('0010000')
S.PENDIN  = octal('0040000')
S.IEXTEN  = octal('0100000')

-- termios - tcflow() and TCXONC use these
S.TCOOFF = 0
S.TCOON  = 1
S.TCIOFF = 2
S.TCION  = 3

-- termios - tcflush() and TCFLSH use these
S.TCIFLUSH  = 0
S.TCOFLUSH  = 1
S.TCIOFLUSH = 2

-- termios - tcsetattr uses these
S.TCSANOW   = 0
S.TCSADRAIN = 1
S.TCSAFLUSH = 2

-- TIOCM ioctls
S.TIOCM_LE  = 0x001
S.TIOCM_DTR = 0x002
S.TIOCM_RTS = 0x004
S.TIOCM_ST  = 0x008
S.TIOCM_SR  = 0x010
S.TIOCM_CTS = 0x020
S.TIOCM_CAR = 0x040
S.TIOCM_RNG = 0x080
S.TIOCM_DSR = 0x100
S.TIOCM_CD  = S.TIOCM_CAR
S.TIOCM_RI  = S.TIOCM_RNG

-- ioctls, filling in as needed
S.SIOCGIFINDEX   = 0x8933

S.SIOCBRADDBR    = 0x89a0
S.SIOCBRDELBR    = 0x89a1
S.SIOCBRADDIF    = 0x89a2
S.SIOCBRDELIF    = 0x89a3

S.TIOCMGET       = 0x5415
S.TIOCMBIS       = 0x5416
S.TIOCMBIC       = 0x5417
S.TIOCMSET       = 0x5418
S.TIOCGPTN	 = 0x80045430LL
S.TIOCSPTLCK	 = 0x40045431LL

-- sysfs values
S.SYSFS_BRIDGE_ATTR        = "bridge"
S.SYSFS_BRIDGE_FDB         = "brforward"
S.SYSFS_BRIDGE_PORT_SUBDIR = "brif"
S.SYSFS_BRIDGE_PORT_ATTR   = "brport"
S.SYSFS_BRIDGE_PORT_LINK   = "bridge"

-- sizes -- should we export?
local HOST_NAME_MAX = 64
local IFNAMSIZ      = 16
local IFHWADDRLEN   = 6

-- errors
S.E = {
  EPERM          =  1,
  ENOENT         =  2,
  ESRCH          =  3,
  EINTR          =  4,
  EIO            =  5,
  ENXIO          =  6,
  E2BIG          =  7,
  ENOEXEC        =  8,
  EBADF          =  9,
  ECHILD         = 10,
  EAGAIN         = 11,
  ENOMEM         = 12,
  EACCES         = 13,
  EFAULT         = 14,
  ENOTBLK        = 15,
  EBUSY          = 16,
  EEXIST         = 17,
  EXDEV          = 18,
  ENODEV         = 19,
  ENOTDIR        = 20,
  EISDIR         = 21,
  EINVAL         = 22,
  ENFILE         = 23,
  EMFILE         = 24,
  ENOTTY         = 25,
  ETXTBSY        = 26,
  EFBIG          = 27,
  ENOSPC         = 28,
  ESPIPE         = 29,
  EROFS          = 30,
  EMLINK         = 31,
  EPIPE          = 32,
  EDOM           = 33,
  ERANGE         = 34,
  EDEADLK        = 35,
  ENAMETOOLONG   = 36,
  ENOLCK         = 37,
  ENOSYS         = 38,
  ENOTEMPTY      = 39,
  ELOOP          = 40,
  ENOMSG         = 42,
  EIDRM          = 43,
  ECHRNG         = 44,
  EL2NSYNC       = 45,
  EL3HLT         = 46,
  EL3RST         = 47,
  ELNRNG         = 48,
  EUNATCH        = 49,
  ENOCSI         = 50,
  EL2HLT         = 51,
  EBADE          = 52,
  EBADR          = 53,
  EXFULL         = 54,
  ENOANO         = 55,
  EBADRQC        = 56,
  EBADSLT        = 57,
  EBFONT         = 59,
  ENOSTR         = 60,
  ENODATA        = 61,
  ETIME          = 62,
  ENOSR          = 63,
  ENONET         = 64,
  ENOPKG         = 65,
  EREMOTE        = 66,
  ENOLINK        = 67,
  EADV           = 68,
  ESRMNT         = 69,
  ECOMM          = 70,
  EPROTO         = 71,
  EMULTIHOP      = 72,
  EDOTDOT        = 73,
  EBADMSG        = 74,
  EOVERFLOW      = 75,
  ENOTUNIQ       = 76,
  EBADFD         = 77,
  EREMCHG        = 78,
  ELIBACC        = 79,
  ELIBBAD        = 80,
  ELIBSCN        = 81,
  ELIBMAX        = 82,
  ELIBEXEC       = 83,
  EILSEQ         = 84,
  ERESTART       = 85,
  ESTRPIPE       = 86,
  EUSERS         = 87,
  ENOTSOCK       = 88,
  EDESTADDRREQ   = 89,
  EMSGSIZE       = 90,
  EPROTOTYPE     = 91,
  ENOPROTOOPT    = 92,
  EPROTONOSUPPORT= 93,
  ESOCKTNOSUPPORT= 94,
  EOPNOTSUPP     = 95,
  EPFNOSUPPORT   = 96,
  EAFNOSUPPORT   = 97,
  EADDRINUSE     = 98,
  EADDRNOTAVAIL  = 99,
  ENETDOWN       = 100,
  ENETUNREACH    = 101,
  ENETRESET      = 102,
  ECONNABORTED   = 103,
  ECONNRESET     = 104,
  ENOBUFS        = 105,
  EISCONN        = 106,
  ENOTCONN       = 107,
  ESHUTDOWN      = 108,
  ETOOMANYREFS   = 109,
  ETIMEDOUT      = 110,
  ECONNREFUSED   = 111,
  EHOSTDOWN      = 112,
  EHOSTUNREACH   = 113,
  EINPROGRESS    = 115,
  ESTALE         = 116,
  EUCLEAN        = 117,
  ENOTNAM        = 118,
  ENAVAIL        = 119,
  EISNAM         = 120,
  EREMOTEIO      = 121,
  EDQUOT         = 122,
  ENOMEDIUM      = 123,
  EMEDIUMTYPE    = 124,
  ECANCELED      = 125,
  ENOKEY         = 126,
  EKEYEXPIRED    = 127,
  EKEYREVOKED    = 128,
  EKEYREJECTED   = 129,
  EOWNERDEAD     = 130,
  ENOTRECOVERABLE= 131,
  ERFKILL        = 132,
}

-- alternate names
S.E.EWOULDBLOCK    = S.E.EAGAIN
S.E.EDEADLOCK      = S.E.EDEADLK
S.E.ENOATTR        = S.E.ENODATA

local errsyms = {} -- reverse lookup
for k, v in pairs(S.E) do
  errsyms[v] = k
end

-- define C types
ffi.cdef[[

static const int UTSNAME_LENGTH = 65;

// typedefs for word size independent types

// 16 bit
typedef uint16_t in_port_t;

// 32 bit
typedef uint32_t mode_t;
typedef uint32_t uid_t;
typedef uint32_t gid_t;
typedef uint32_t socklen_t;
typedef uint32_t id_t;
typedef int32_t pid_t;
typedef int32_t clockid_t;
typedef int32_t daddr_t;

// 64 bit
typedef uint64_t dev_t;
typedef uint64_t loff_t;
typedef uint64_t off64_t;
typedef uint64_t rlim64_t;

// posix standards
typedef unsigned short int sa_family_t;

// typedefs which are word length
typedef unsigned long size_t;
typedef long ssize_t;
typedef long off_t;
typedef long kernel_off_t;
typedef long time_t;
typedef long blksize_t;
typedef long blkcnt_t;
typedef long clock_t;
typedef unsigned long ino_t;
typedef unsigned long nlink_t;
typedef unsigned long aio_context_t;
typedef unsigned long nfds_t;

// should be a word, but we use 32 bits as bitops are signed 32 bit in LuaJIT at the moment
typedef int32_t fd_mask;

typedef struct {
  int32_t val[1024 / (8 * sizeof (int32_t))];
} sigset_t;

typedef int mqd_t;
typedef int idtype_t; /* defined as enum */

// misc
typedef void (*sighandler_t) (int);

// structs
struct timeval {
  long    tv_sec;         /* seconds */
  long    tv_usec;        /* microseconds */
};
struct timespec {
  time_t tv_sec;        /* seconds */
  long   tv_nsec;       /* nanoseconds */
};
struct itimerspec {
  struct timespec it_interval;
  struct timespec it_value;
};
struct itimerval {
  struct timeval it_interval;
  struct timeval it_value;
};
// for uname.
struct utsname {
  char sysname[UTSNAME_LENGTH];
  char nodename[UTSNAME_LENGTH];
  char release[UTSNAME_LENGTH];
  char version[UTSNAME_LENGTH];
  char machine[UTSNAME_LENGTH];
  char domainname[UTSNAME_LENGTH]; // may not exist
};
struct iovec {
  void *iov_base;
  size_t iov_len;
};
struct pollfd {
  int fd;
  short int events;
  short int revents;
};
typedef struct { /* based on Linux/FreeBSD FD_SETSIZE = 1024, the kernel can do more, so can increase, but bad performance so dont! */
  fd_mask fds_bits[1024 / (sizeof (fd_mask) * 8)];
} fd_set;
struct ucred { /* this is Linux specific */
  pid_t pid;
  uid_t uid;
  gid_t gid;
};
struct rlimit64 {
  rlim64_t rlim_cur;
  rlim64_t rlim_max;
};
struct sysinfo { /* Linux only */
  long uptime;
  unsigned long loads[3];
  unsigned long totalram;
  unsigned long freeram;
  unsigned long sharedram;
  unsigned long bufferram;
  unsigned long totalswap;
  unsigned long freeswap;
  unsigned short procs;
  unsigned short pad;
  unsigned long totalhigh;
  unsigned long freehigh;
  unsigned int mem_unit;
  char _f[20-2*sizeof(long)-sizeof(int)];
};
struct timex {
  unsigned int modes;
  long int offset;
  long int freq;
  long int maxerror;
  long int esterror;
  int status;
  long int constant;
  long int precision;
  long int tolerance;
  struct timeval time;
  long int tick;

  long int ppsfreq;
  long int jitter;
  int shift;
  long int stabil;
  long int jitcnt;
  long int calcnt;
  long int errcnt;
  long int stbcnt;

  int tai;

  int  :32; int  :32; int  :32; int  :32;
  int  :32; int  :32; int  :32; int  :32;
  int  :32; int  :32; int  :32;
};
typedef union sigval {
  int sival_int;
  void *sival_ptr;
} sigval_t;
struct msghdr {
  void *msg_name;
  socklen_t msg_namelen;
  struct iovec *msg_iov;
  size_t msg_iovlen;
  void *msg_control;
  size_t msg_controllen;
  int msg_flags;
};
struct cmsghdr {
  size_t cmsg_len;
  int cmsg_level;
  int cmsg_type;
  //unsigned char cmsg_data[?]; /* causes issues with luaffi, pre C99 */
};
struct sockaddr {
  sa_family_t sa_family;
  char sa_data[14];
};
struct sockaddr_storage {
  sa_family_t ss_family;
  unsigned long int __ss_align;
  char __ss_padding[128 - 2 * sizeof(unsigned long int)]; /* total length 128 */
};
struct in_addr {
  uint32_t       s_addr;
};
struct in6_addr {
  unsigned char  s6_addr[16];
};
struct sockaddr_in {
  sa_family_t    sin_family;
  in_port_t      sin_port;
  struct in_addr sin_addr;
  unsigned char  sin_zero[8]; /* padding, should not vary by arch */
};
struct sockaddr_in6 {
  sa_family_t    sin6_family;
  in_port_t sin6_port;
  uint32_t sin6_flowinfo;
  struct in6_addr sin6_addr;
  uint32_t sin6_scope_id;
};
struct sockaddr_un {
  sa_family_t sun_family;
  char        sun_path[108];
};
struct sockaddr_nl {
  sa_family_t     nl_family;
  unsigned short  nl_pad;
  uint32_t        nl_pid;
  uint32_t        nl_groups;
};
struct nlmsghdr {
  uint32_t           nlmsg_len;
  uint16_t           nlmsg_type;
  uint16_t           nlmsg_flags;
  uint32_t           nlmsg_seq;
  uint32_t           nlmsg_pid;
};
struct rtgenmsg {
  unsigned char           rtgen_family;
};
struct ifinfomsg {
  unsigned char   ifi_family;
  unsigned char   __ifi_pad;
  unsigned short  ifi_type;
  int             ifi_index;
  unsigned        ifi_flags;
  unsigned        ifi_change;
};
struct rtattr {
  unsigned short  rta_len;
  unsigned short  rta_type;
};
struct nlmsgerr {
  int             error;
  struct nlmsghdr msg;
};
struct rtmsg {
  unsigned char rtm_family;
  unsigned char rtm_dst_len;
  unsigned char rtm_src_len;
  unsigned char rtm_tos;
  unsigned char rtm_table;
  unsigned char rtm_protocol;
  unsigned char rtm_scope;
  unsigned char rtm_type;
  unsigned int  rtm_flags;
};

static const int IFNAMSIZ = 16;

struct ifmap {
  unsigned long mem_start;
  unsigned long mem_end;
  unsigned short base_addr; 
  unsigned char irq;
  unsigned char dma;
  unsigned char port;
};
struct rtnl_link_stats {
  uint32_t rx_packets;
  uint32_t tx_packets;
  uint32_t rx_bytes;
  uint32_t tx_bytes;
  uint32_t rx_errors;
  uint32_t tx_errors;
  uint32_t rx_dropped;
  uint32_t tx_dropped;
  uint32_t multicast;
  uint32_t collisions;
  uint32_t rx_length_errors;
  uint32_t rx_over_errors;
  uint32_t rx_crc_errors;
  uint32_t rx_frame_errors;
  uint32_t rx_fifo_errors;
  uint32_t rx_missed_errors;
  uint32_t tx_aborted_errors;
  uint32_t tx_carrier_errors;
  uint32_t tx_fifo_errors;
  uint32_t tx_heartbeat_errors;
  uint32_t tx_window_errors;
  uint32_t rx_compressed;
  uint32_t tx_compressed;
};
typedef struct { 
  unsigned int clock_rate;
  unsigned int clock_type;
  unsigned short loopback;
} sync_serial_settings;
typedef struct { 
  unsigned int clock_rate;
  unsigned int clock_type;
  unsigned short loopback;
  unsigned int slot_map;
} te1_settings;
typedef struct {
  unsigned short encoding;
  unsigned short parity;
} raw_hdlc_proto;
typedef struct {
  unsigned int t391;
  unsigned int t392;
  unsigned int n391;
  unsigned int n392;
  unsigned int n393;
  unsigned short lmi;
  unsigned short dce;
} fr_proto;
typedef struct {
  unsigned int dlci;
} fr_proto_pvc;
typedef struct {
  unsigned int dlci;
  char master[IFNAMSIZ];
} fr_proto_pvc_info;
typedef struct {
  unsigned int interval;
  unsigned int timeout;
} cisco_proto;
struct if_settings {
  unsigned int type;
  unsigned int size;
  union {
    raw_hdlc_proto          *raw_hdlc;
    cisco_proto             *cisco;
    fr_proto                *fr;
    fr_proto_pvc            *fr_pvc;
    fr_proto_pvc_info       *fr_pvc_info;

    sync_serial_settings    *sync;
    te1_settings            *te1;
  } ifs_ifsu;
};
struct ifreq {
  union {
    char ifrn_name[IFNAMSIZ];
  } ifr_ifrn;
  union {
    struct  sockaddr ifru_addr;
    struct  sockaddr ifru_dstaddr;
    struct  sockaddr ifru_broadaddr;
    struct  sockaddr ifru_netmask;
    struct  sockaddr ifru_hwaddr;
    short   ifru_flags;
    int     ifru_ivalue;
    int     ifru_mtu;
    struct  ifmap ifru_map;
    char    ifru_slave[IFNAMSIZ];
    char    ifru_newname[IFNAMSIZ];
    void *  ifru_data;
    struct  if_settings ifru_settings;
  } ifr_ifru;
};
struct ifaddrmsg {
  uint8_t  ifa_family;
  uint8_t  ifa_prefixlen;
  uint8_t  ifa_flags;
  uint8_t  ifa_scope;
  uint32_t ifa_index;
};
struct ifa_cacheinfo {
  uint32_t ifa_prefered;
  uint32_t ifa_valid;
  uint32_t cstamp;
  uint32_t tstamp;
};
struct rta_cacheinfo {
  uint32_t rta_clntref;
  uint32_t rta_lastuse;
  uint32_t rta_expires;
  uint32_t rta_error;
  uint32_t rta_used;
  uint32_t rta_id;
  uint32_t rta_ts;
  uint32_t rta_tsage;
};
struct fdb_entry {
  uint8_t mac_addr[6];
  uint8_t port_no;
  uint8_t is_local;
  uint32_t ageing_timer_value;
  uint8_t port_hi;
  uint8_t pad0;
  uint16_t unused;
};
struct inotify_event {
  int wd;
  uint32_t mask;
  uint32_t cookie;
  uint32_t len;
  char name[?];
};
struct linux_dirent64 {
  uint64_t             d_ino;
  int64_t              d_off;
  unsigned short  d_reclen;
  unsigned char   d_type;
  char            d_name[0];
};
struct stat {  /* only used on 64 bit architectures */
  unsigned long   st_dev;
  unsigned long   st_ino;
  unsigned long   st_nlink;
  unsigned int    st_mode;
  unsigned int    st_uid;
  unsigned int    st_gid;
  unsigned int    __pad0;
  unsigned long   st_rdev;
  long            st_size;
  long            st_blksize;
  long            st_blocks;
  unsigned long   st_atime;
  unsigned long   st_atime_nsec;
  unsigned long   st_mtime;
  unsigned long   st_mtime_nsec;
  unsigned long   st_ctime;
  unsigned long   st_ctime_nsec;
  long            __unused[3];
};
struct stat64 { /* only for 32 bit architectures */
  unsigned long long      st_dev;
  unsigned char   __pad0[4];
  unsigned long   __st_ino;
  unsigned int    st_mode;
  unsigned int    st_nlink;
  unsigned long   st_uid;
  unsigned long   st_gid;
  unsigned long long      st_rdev;
  unsigned char   __pad3[4];
  long long       st_size;
  unsigned long   st_blksize;
  unsigned long long      st_blocks;
  unsigned long   st_atime;
  unsigned long   st_atime_nsec;
  unsigned long   st_mtime;
  unsigned int    st_mtime_nsec;
  unsigned long   st_ctime;
  unsigned long   st_ctime_nsec;
  unsigned long long      st_ino;
};
struct flock64 {
  short int l_type;
  short int l_whence;
  off64_t l_start;
  off64_t l_len;
  pid_t l_pid;
};
typedef union epoll_data {
  void *ptr;
  int fd;
  uint32_t u32;
  uint64_t u64;
} epoll_data_t;
struct signalfd_siginfo {
  uint32_t ssi_signo;
  int32_t ssi_errno;
  int32_t ssi_code;
  uint32_t ssi_pid;
  uint32_t ssi_uid;
  int32_t ssi_fd;
  uint32_t ssi_tid;
  uint32_t ssi_band;
  uint32_t ssi_overrun;
  uint32_t ssi_trapno;
  int32_t ssi_status;
  int32_t ssi_int;
  uint64_t ssi_ptr;
  uint64_t ssi_utime;
  uint64_t ssi_stime;
  uint64_t ssi_addr;
  uint8_t __pad[48];
};
struct io_event {
  uint64_t           data;
  uint64_t           obj;
  int64_t            res;
  int64_t            res2;
};
struct seccomp_data {
  int nr;
  uint32_t arch;
  uint64_t instruction_pointer;
  uint64_t args[6];
};
struct mq_attr {
  long mq_flags, mq_maxmsg, mq_msgsize, mq_curmsgs, __unused[4];
};

/* termios */
typedef unsigned char	cc_t;
typedef unsigned int	speed_t;
typedef unsigned int	tcflag_t;
struct termios
  {
    tcflag_t c_iflag;		/* input mode flags */
    tcflag_t c_oflag;		/* output mode flags */
    tcflag_t c_cflag;		/* control mode flags */
    tcflag_t c_lflag;		/* local mode flags */
    cc_t c_line;			/* line discipline */
    cc_t c_cc[32];		/* control characters */
    speed_t c_ispeed;		/* input speed */
    speed_t c_ospeed;		/* output speed */
  };
]]

-- sigaction is a union on x86. note luajit supports anonymous unions, which simplifies usage
-- it appears that there is no kernel sigaction in non x86 architectures? Need to check source.
-- presumably does not care, but the types are a bit of a pain.
-- temporarily just going to implement sighandler support
if arch.sigaction then arch.sigaction()
else
ffi.cdef[[
struct sigaction {
  sighandler_t sa_handler;
  unsigned long sa_flags;
  void (*sa_restorer)(void);
  sigset_t sa_mask;
};
]]
end

-- Linux struct siginfo padding depends on architecture, also statfs
if ffi.abi("64bit") then
ffi.cdef[[
static const int SI_MAX_SIZE = 128;
static const int SI_PAD_SIZE = (SI_MAX_SIZE / sizeof (int)) - 4;
typedef long statfs_word;
]]
else
ffi.cdef[[
static const int SI_MAX_SIZE = 128;
static const int SI_PAD_SIZE = (SI_MAX_SIZE / sizeof (int)) - 3;
typedef uint32_t statfs_word;
]]
end

ffi.cdef[[
typedef struct siginfo {
  int si_signo;
  int si_errno;
  int si_code;

  union {
    int _pad[SI_PAD_SIZE];

    struct {
      pid_t si_pid;
      uid_t si_uid;
    } kill;

    struct {
      int si_tid;
      int si_overrun;
      sigval_t si_sigval;
    } timer;

    struct {
      pid_t si_pid;
      uid_t si_uid;
      sigval_t si_sigval;
    } rt;

    struct {
      pid_t si_pid;
      uid_t si_uid;
      int si_status;
      clock_t si_utime;
      clock_t si_stime;
    } sigchld;

    struct {
      void *si_addr;
    } sigfault;

    struct {
      long int si_band;
       int si_fd;
    } sigpoll;
  } sifields;
} siginfo_t;

typedef struct {
  int     val[2];
} kernel_fsid_t;

struct statfs64 {
  statfs_word f_type;
  statfs_word f_bsize;
  uint64_t f_blocks;
  uint64_t f_bfree;
  uint64_t f_bavail;
  uint64_t f_files;
  uint64_t f_ffree;
  kernel_fsid_t f_fsid;
  statfs_word f_namelen;
  statfs_word f_frsize;
  statfs_word f_flags;
  statfs_word f_spare[4];
};
]]

-- epoll packed on x86_64 only (so same as x86)
if arch.epoll then arch.epoll()
else
ffi.cdef[[
struct epoll_event {
  uint32_t events;
  epoll_data_t data;
};
]]
end

-- endian dependent
if ffi.abi("le") then
ffi.cdef[[
struct iocb {
  uint64_t   aio_data;
  uint32_t   aio_key, aio_reserved1;

  uint16_t   aio_lio_opcode;
  int16_t    aio_reqprio;
  uint32_t   aio_fildes;

  uint64_t   aio_buf;
  uint64_t   aio_nbytes;
  int64_t    aio_offset;

  uint64_t   aio_reserved2;

  uint32_t   aio_flags;

  uint32_t   aio_resfd;
};
]]
else
ffi.cdef[[
struct iocb {
  uint64_t   aio_data;
  uint32_t   aio_reserved1, aio_key;

  uint16_t   aio_lio_opcode;
  int16_t    aio_reqprio;
  uint32_t   aio_fildes;

  uint64_t   aio_buf;
  uint64_t   aio_nbytes;
  int64_t    aio_offset;

  uint64_t   aio_reserved2;

  uint32_t   aio_flags;

  uint32_t   aio_resfd;
};
]]
end

-- shared code
ffi.cdef[[
int close(int fd);
int open(const char *pathname, int flags, mode_t mode);
int openat(int dirfd, const char *pathname, int flags, mode_t mode);
int creat(const char *pathname, mode_t mode);
int chdir(const char *path);
int mkdir(const char *pathname, mode_t mode);
int mkdirat(int dirfd, const char *pathname, mode_t mode);
int rmdir(const char *pathname);
int unlink(const char *pathname);
int unlinkat(int dirfd, const char *pathname, int flags);
int rename(const char *oldpath, const char *newpath);
int renameat(int olddirfd, const char *oldpath, int newdirfd, const char *newpath);
int acct(const char *filename);
int chmod(const char *path, mode_t mode);
int chown(const char *path, uid_t owner, gid_t group);
int fchown(int fd, uid_t owner, gid_t group);
int lchown(const char *path, uid_t owner, gid_t group);
int fchownat(int dirfd, const char *pathname, uid_t owner, gid_t group, int flags);
int link(const char *oldpath, const char *newpath);
int linkat(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, int flags);
int symlink(const char *oldpath, const char *newpath);
int symlinkat(const char *oldpath, int newdirfd, const char *newpath);
int chroot(const char *path);
mode_t umask(mode_t mask);
int uname(struct utsname *buf);
int sethostname(const char *name, size_t len);
int setdomainname(const char *name, size_t len);
uid_t getuid(void);
uid_t geteuid(void);
pid_t getpid(void);
pid_t getppid(void);
gid_t getgid(void);
gid_t getegid(void);
int setuid(uid_t uid);
int setgid(gid_t gid);
int seteuid(uid_t euid);
int setegid(gid_t egid);
int setreuid(uid_t ruid, uid_t euid);
int setregid(gid_t rgid, gid_t egid);
int getresuid(uid_t *ruid, uid_t *euid, uid_t *suid);
int getresgid(gid_t *rgid, gid_t *egid, gid_t *sgid);
int setresuid(uid_t ruid, uid_t euid, uid_t suid);
int setresgid(gid_t rgid, gid_t egid, gid_t sgid);
pid_t getsid(pid_t pid);
pid_t setsid(void);
int getgroups(int size, gid_t list[]);
int setgroups(size_t size, const gid_t *list);
pid_t fork(void);
int execve(const char *filename, const char *argv[], const char *envp[]);
pid_t wait(int *status);
pid_t waitpid(pid_t pid, int *status, int options);
int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options);
void _exit(int status);
int signal(int signum, int handler); /* although deprecated, just using to set SIG_ values */
int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact);
int kill(pid_t pid, int sig);
int gettimeofday(struct timeval *tv, void *tz);   /* not even defining struct timezone */
int settimeofday(const struct timeval *tv, const void *tz);
int getitimer(int which, struct itimerval *curr_value);
int setitimer(int which, const struct itimerval *new_value, struct itimerval *old_value);
time_t time(time_t *t);
int clock_getres(clockid_t clk_id, struct timespec *res);
int clock_gettime(clockid_t clk_id, struct timespec *tp);
int clock_settime(clockid_t clk_id, const struct timespec *tp);
int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *request, struct timespec *remain);
unsigned int alarm(unsigned int seconds);
int sysinfo(struct sysinfo *info);
void sync(void);
int nice(int inc);
int getpriority(int which, int who);
int setpriority(int which, int who, int prio);
int prctl(int option, unsigned long arg2, unsigned long arg3, unsigned long arg4, unsigned long arg5);
int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);
int sigpending(sigset_t *set);
int sigsuspend(const sigset_t *mask);
int signalfd(int fd, const sigset_t *mask, int flags);
int timerfd_create(int clockid, int flags);
int timerfd_settime(int fd, int flags, const struct itimerspec *new_value, struct itimerspec *old_value);
int timerfd_gettime(int fd, struct itimerspec *curr_value);
int mknod(const char *pathname, mode_t mode, dev_t dev);
int mknodat(int dirfd, const char *pathname, mode_t mode, dev_t dev);

ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
ssize_t pread64(int fd, void *buf, size_t count, loff_t offset);
ssize_t pwrite64(int fd, const void *buf, size_t count, loff_t offset);
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
// for sendto and recvfrom use void pointer not const struct sockaddr * to avoid casting
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const void *dest_addr, socklen_t addrlen);
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags, void *src_addr, socklen_t *addrlen);
ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags);
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
ssize_t recvmsg(int sockfd, struct msghdr *msg, int flags);
ssize_t readv(int fd, const struct iovec *iov, int iovcnt);
ssize_t writev(int fd, const struct iovec *iov, int iovcnt);
// ssize_t preadv(int fd, const struct iovec *iov, int iovcnt, off_t offset);
// ssize_t pwritev(int fd, const struct iovec *iov, int iovcnt, off_t offset);
ssize_t preadv64(int fd, const struct iovec *iov, int iovcnt, loff_t offset);
ssize_t pwritev64(int fd, const struct iovec *iov, int iovcnt, loff_t offset);

int getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen);
int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen);
int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
int ppoll(struct pollfd *fds, nfds_t nfds, const struct timespec *timeout_ts, const sigset_t *sigmask);
int pselect(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timespec *timeout, const sigset_t *sigmask);
ssize_t readlink(const char *path, char *buf, size_t bufsiz);
int readlinkat(int dirfd, const char *pathname, char *buf, size_t bufsiz);
off_t lseek(int fd, off_t offset, int whence); // only for 64 bit, else use _llseek

int epoll_create1(int flags);
int epoll_create(int size);
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
int epoll_pwait(int epfd, struct epoll_event *events, int maxevents, int timeout, const sigset_t *sigmask);
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
int eventfd(unsigned int initval, int flags);
ssize_t splice(int fd_in, loff_t *off_in, int fd_out, loff_t *off_out, size_t len, unsigned int flags);
ssize_t vmsplice(int fd, const struct iovec *iov, unsigned long nr_segs, unsigned int flags);
ssize_t tee(int fd_in, int fd_out, size_t len, unsigned int flags);
int reboot(int cmd);
int klogctl(int type, char *bufp, int len);
int inotify_init1(int flags);
int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
int inotify_rm_watch(int fd, uint32_t wd);
int adjtimex(struct timex *buf);
int sync_file_range(int fd, loff_t offset, loff_t count, unsigned int flags);

int dup(int oldfd);
int dup2(int oldfd, int newfd);
int dup3(int oldfd, int newfd, int flags);
int fchdir(int fd);
int fsync(int fd);
int fdatasync(int fd);
int fcntl(int fd, int cmd, void *arg); /* arg is long or pointer */
int fchmod(int fd, mode_t mode);
int fchmodat(int dirfd, const char *pathname, mode_t mode, int flags);
int truncate(const char *path, off_t length);
int ftruncate(int fd, off_t length);
int truncate64(const char *path, loff_t length);
int ftruncate64(int fd, loff_t length);
int pause(void);
int prlimit64(pid_t pid, int resource, const struct rlimit64 *new_limit, struct rlimit64 *old_limit);

int socket(int domain, int type, int protocol);
int socketpair(int domain, int type, int protocol, int sv[2]);
int bind(int sockfd, const void *addr, socklen_t addrlen); // void not struct
int listen(int sockfd, int backlog);
int connect(int sockfd, const void *addr, socklen_t addrlen);
int accept(int sockfd, void *addr, socklen_t *addrlen);
int accept4(int sockfd, void *addr, socklen_t *addrlen, int flags);
int getsockname(int sockfd, void *addr, socklen_t *addrlen);
int getpeername(int sockfd, void *addr, socklen_t *addrlen);
int shutdown(int sockfd, int how);

void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
int munmap(void *addr, size_t length);
int msync(void *addr, size_t length, int flags);
int mlock(const void *addr, size_t len);
int munlock(const void *addr, size_t len);
int mlockall(int flags);
int munlockall(void);
void *mremap(void *old_address, size_t old_size, size_t new_size, int flags, void *new_address);
int madvise(void *addr, size_t length, int advice);
int posix_fadvise(int fd, off_t offset, off_t len, int advice);
int fallocate(int fd, int mode, off_t offset, off_t len);
ssize_t readahead(int fd, off64_t offset, size_t count);

int pipe(int pipefd[2]);
int pipe2(int pipefd[2], int flags);
int mount(const char *source, const char *target, const char *filesystemtype, unsigned long mountflags, const void *data);
int umount(const char *target);
int umount2(const char *target, int flags);

int nanosleep(const struct timespec *req, struct timespec *rem);
int access(const char *pathname, int mode);
int faccessat(int dirfd, const char *pathname, int mode, int flags);
char *getcwd(char *buf, size_t size);
int statfs(const char *path, struct statfs64 *buf); /* this is statfs64 syscall, but glibc wraps */
int fstatfs(int fd, struct statfs64 *buf);          /* this too */
int futimens(int fd, const struct timespec times[2]);
int utimensat(int dirfd, const char *pathname, const struct timespec times[2], int flags);

ssize_t listxattr(const char *path, char *list, size_t size);
ssize_t llistxattr(const char *path, char *list, size_t size);
ssize_t flistxattr(int fd, char *list, size_t size);
ssize_t getxattr(const char *path, const char *name, void *value, size_t size);
ssize_t lgetxattr(const char *path, const char *name, void *value, size_t size);
ssize_t fgetxattr(int fd, const char *name, void *value, size_t size);
int setxattr(const char *path, const char *name, const void *value, size_t size, int flags);
int lsetxattr(const char *path, const char *name, const void *value, size_t size, int flags);
int fsetxattr(int fd, const char *name, const void *value, size_t size, int flags);
int removexattr(const char *path, const char *name);
int lremovexattr(const char *path, const char *name);
int fremovexattr(int fd, const char *name);

int unshare(int flags);
int setns(int fd, int nstype);
int pivot_root(const char *new_root, const char *put_old);

int syscall(int number, ...);

int ioctl(int d, int request, void *argp); /* void* easiest here */

/* TODO from here to libc functions are not implemented yet */
int tgkill(int tgid, int tid, int sig);
int brk(void *addr);
void *sbrk(intptr_t increment);
void exit_group(int status);

/* these need their types adding or fixing before can uncomment */
/*
int capget(cap_user_header_t hdrp, cap_user_data_t datap);
int capset(cap_user_header_t hdrp, const cap_user_data_t datap);
caddr_t create_module(const char *name, size_t size);
int init_module(const char *name, struct module *image);
int get_kernel_syms(struct kernel_sym *table);
int getcpu(unsigned *cpu, unsigned *node, struct getcpu_cache *tcache);
int getrusage(int who, struct rusage *usage);
int get_thread_area(struct user_desc *u_info);
long kexec_load(unsigned long entry, unsigned long nr_segments, struct kexec_segment *segments, unsigned long flags);
int lookup_dcookie(u64 cookie, char *buffer, size_t len);
int msgctl(int msqid, int cmd, struct msqid_ds *buf);
int msgget(key_t key, int msgflg);
long ptrace(enum __ptrace_request request, pid_t pid, void *addr, void *data);
int quotactl(int cmd, const char *special, int id, caddr_t addr);
int semget(key_t key, int nsems, int semflg);
int shmctl(int shmid, int cmd, struct shmid_ds *buf);
int shmget(key_t key, size_t size, int shmflg);
int timer_create(clockid_t clockid, struct sigevent *sevp, timer_t *timerid);
int timer_delete(timer_t timerid);
int timer_getoverrun(timer_t timerid);
int timer_settime(timer_t timerid, int flags, const struct itimerspec *new_value, struct itimerspec * old_value);
int timer_gettime(timer_t timerid, struct itimerspec *curr_value);
clock_t times(struct tms *buf);
int utime(const char *filename, const struct utimbuf *times);
*/
int msgsnd(int msqid, const void *msgp, size_t msgsz, int msgflg);
ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg);

int delete_module(const char *name);
int flock(int fd, int operation);
int get_mempolicy(int *mode, unsigned long *nodemask, unsigned long maxnode, unsigned long addr, unsigned long flags);
int mbind(void *addr, unsigned long len, int mode, unsigned long *nodemask, unsigned long maxnode, unsigned flags);
long migrate_pages(int pid, unsigned long maxnode, const unsigned long *old_nodes, const unsigned long *new_nodes);
int mincore(void *addr, size_t length, unsigned char *vec);
long move_pages(int pid, unsigned long count, void **pages, const int *nodes, int *status, int flags);
int mprotect(const void *addr, size_t len, int prot);
int personality(unsigned long persona);
int recvmmsg(int sockfd, struct mmsghdr *msgvec, unsigned int vlen, unsigned int flags, struct timespec *timeout);
int remap_file_pages(void *addr, size_t size, int prot, ssize_t pgoff, int flags);
int semctl(int semid, int semnum, int cmd, ...);
int semop(int semid, struct sembuf *sops, unsigned nsops);
int semtimedop(int semid, struct sembuf *sops, unsigned nsops, struct timespec *timeout);
void *shmat(int shmid, const void *shmaddr, int shmflg);
int shmdt(const void *shmaddr);
int swapon(const char *path, int swapflags);
int swapoff(const char *path);
void syncfs(int fd);
pid_t wait4(pid_t pid, int *status, int options, struct rusage *rusage);

int setpgid(pid_t pid, pid_t pgid);
pid_t getpgid(pid_t pid);
pid_t getpgrp(pid_t pid);
pid_t gettid(void);
int setfsgid(uid_t fsgid);
int setfsuid(uid_t fsuid);
long keyctl(int cmd, ...);

mqd_t mq_open(const char *name, int oflag, mode_t mode, struct mq_attr *attr);
int mq_getsetattr(mqd_t mqdes, struct mq_attr *newattr, struct mq_attr *oldattr);
ssize_t mq_timedreceive(mqd_t mqdes, char *msg_ptr, size_t msg_len, unsigned *msg_prio, const struct timespec *abs_timeout);
int mq_timedsend(mqd_t mqdes, const char *msg_ptr, size_t msg_len, unsigned msg_prio, const struct timespec *abs_timeout);
int mq_notify(mqd_t mqdes, const struct sigevent *sevp);
int mq_unlink(const char *name);

// functions from libc ie man 3 not man 2
void exit(int status);
int inet_pton(int af, const char *src, void *dst);
const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);

// functions from libc that could be exported as a convenience, used internally
char *strerror(int);
// env. dont support putenv, as does not copy which is an issue
extern char **environ;
int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
int clearenv(void);
char *getenv(const char *name);

int tcgetattr(int fd, struct termios *termios_p);
int tcsetattr(int fd, int optional_actions, const struct termios *termios_p);
int tcsendbreak(int fd, int duration);
int tcdrain(int fd);
int tcflush(int fd, int queue_selector);
int tcflow(int fd, int action);
void cfmakeraw(struct termios *termios_p);
speed_t cfgetispeed(const struct termios *termios_p);
speed_t cfgetospeed(const struct termios *termios_p);
int cfsetispeed(struct termios *termios_p, speed_t speed);
int cfsetospeed(struct termios *termios_p, speed_t speed);
int cfsetspeed(struct termios *termios_p, speed_t speed);
pid_t tcgetsid(int fd);
int vhangup(void);
]]

-- use 64 bit fileops on 32 bit always
local stattypename
if ffi.abi("64bit") then
  stattypename = "struct stat"
else
  stattypename = "struct stat64"
  C.truncate = ffi.C.truncate64
  C.ftruncate = ffi.C.ftruncate64
end

-- makes code tidier
local function istype(x, tp)
  if ffi.istype(x, tp) then return tp else return false end
end

-- functions we need for metatypes

local memo = {} -- memoize flags so faster looping

-- take a bunch of flags in a string and return a number
-- note if using with 64 bit flags will have to change to use a 64 bit number, currently assumes 32 bit, as uses bitops
-- also forcing to return an int now - TODO find any 64 bit flags we are using and fix to use new function
function S.stringflags(str, prefix) -- allows multiple comma sep flags that are ORed
  if not str then return 0 end
  if type(str) ~= "string" then return str end
  if memo[prefix] and memo[prefix][str] then return memo[prefix][str] end
  local f = 0
  local a = split(",", str)
  local ts, s, val
  for i, v in ipairs(a) do
    ts = trim(v)
    s = ts:upper()
    if s:sub(1, #prefix) ~= prefix then s = prefix .. s end -- prefix optional
    val = S[s]
    if not val then error("invalid flag: " .. v) end -- don't use this format if you don't want exceptions, better than silent ignore
    f = bit.bor(f, val) -- note this forces to signed 32 bit, ok for most flags, but might get sign extension on long
  end
  if not memo[prefix] then memo[prefix] = {} end
  memo[prefix][str] = f
  return f
end

function S.stringflag(str, prefix) -- single value only
  if not str then return 0 end
  if type(str) ~= "string" then return str end
  if #str == 0 then return 0 end
  if memo[prefix] and memo[prefix][str] then return memo[prefix][str] end
  local s = trim(str):upper()
  if s:sub(1, #prefix) ~= prefix then s = prefix .. s end -- prefix optional
  local val = S[s]
  if not val then error("invalid flag: " .. s) end -- don't use this format if you don't want exceptions, better than silent ignore
  if not memo[prefix] then memo[prefix] = {} end
  memo[prefix][str] = val
  return val
end

function S.flaglist(str, prefix, list) -- flags from a list. TODO memoize using table
  if not str then return 0 end
  if type(str) ~= "string" then return str end
  local list2 = {}
  for _, v in ipairs(list) do list2[v] = true end
  local f = 0
  local a = split(",", str)
  local ts, s, val
  for i, v in ipairs(a) do
    ts = trim(v)
    s = ts:upper()
    if s:sub(1, #prefix) ~= prefix then s = prefix .. s end -- prefix optional
    val = S[s]
    if not list2[s] or not val then error("invalid flag: " .. v) end
    f = bit.bor(f, val) -- note this forces to signed 32 bit, ok for most flags, but might get sign extension on long
  end
  return f
end

-- TODO maybe just replace these
local stringflag, stringflags, flaglist = S.stringflag, S.stringflags, S.flaglist

local function getfd(fd)
  if ffi.istype(t.fd, fd) then return fd.filenum end
  return fd
end

local function getfd_at(fd)
  if not fd then return S.AT_FDCWD end
  if type(fd) == "string" then return flaglist(fd, "AT_", {"AT_FDCWD"}) end
  return getfd(fd)
end

local function accessflags(s) -- allow "rwx"
  if not s then return 0 end
  if type(s) ~= "string" then return s end
  s = trim(s:upper())
  local flag = 0
  for i = 1, #s do
    local c = s:sub(i, i)
    if     c == 'R' then flag = bit.bor(flag, S.R_OK)
    elseif c == 'W' then flag = bit.bor(flag, S.W_OK)
    elseif c == 'X' then flag = bit.bor(flag, S.X_OK)
    else error("invalid access flag") end
  end
  return flag
end

-- useful for comparing modes etc
function S.mode(mode) return stringflags(mode, "S_") end

-- Lua type constructors corresponding to defined types
-- basic types

-- cast to pointer to a type. could generate for all types.
local function ptt(tp)
  local ptp = ffi.typeof("$ *", tp)
  return function(x) return ffi.cast(ptp, x) end
end

S.ctypes = {} -- map from C names to types. Used for tests, but might be useful otherwise

local function addtype(name, tp, mt)
  tp = tp or name
  if mt then t[name] = ffi.metatype(tp, mt) else t[name] = ffi.typeof(tp) end
  S.ctypes[tp] = t[name]
  pt[name] = ptt(t[name])
  s[name] = ffi.sizeof(t[name])
end

local metatype = addtype

local addtypes = {
  {"char"},
  {"uchar", "unsigned char"},
  {"int"},
  {"uint", "unsigned int"},
  {"uint16", "uint16_t"},
  {"int32", "int32_t"},
  {"uint32", "uint32_t"},
  {"int64", "int64_t"},
  {"uint64", "uint64_t"},
  {"long"},
  {"ulong", "unsigned long"},
  {"uintptr", "uintptr_t"},
  {"size", "size_t"},
  {"mode", "mode_t"},
  {"dev", "dev_t"},
  {"loff", "loff_t"},
  {"sa_family", "sa_family_t"},

  {"fdset", "fd_set"},

  {"msghdr", "struct msghdr"},
  {"cmsghdr", "struct cmsghdr"},
  {"ucred", "struct ucred"},
  {"sysinfo", "struct sysinfo"},
  {"epoll_event", "struct epoll_event"},
  {"nlmsghdr", "struct nlmsghdr"},
  {"rtgenmsg", "struct rtgenmsg"},
  {"rtmsg", "struct rtmsg"},
  {"ifinfomsg", "struct ifinfomsg"},
  {"ifaddrmsg", "struct ifaddrmsg"},
  {"rtattr", "struct rtattr"},
  {"rta_cacheinfo", "struct rta_cacheinfo"},
  {"nlmsgerr", "struct nlmsgerr"},
  {"timex", "struct timex"},
  {"utsname", "struct utsname"},
  {"fdb_entry", "struct fdb_entry"},
  {"signalfd_siginfo", "struct signalfd_siginfo"},
  {"iocb", "struct iocb"},
  {"sighandler", "sighandler_t"},
  {"sigaction", "struct sigaction"},
  {"clockid", "clockid_t"},
  {"io_event", "struct io_event"},
  {"seccomp_data", "struct seccomp_data"},
  {"iovec", "struct iovec"},
  {"rtnl_link_stats", "struct rtnl_link_stats"},
  {"statfs", "struct statfs64"},
  {"ifreq", "struct ifreq"},
  {"dirent", "struct linux_dirent64"},
  {"ifa_cacheinfo", "struct ifa_cacheinfo"},
  {"flock", "struct flock64"},
  {"mqattr", "struct mq_attr"},
}

for _, v in ipairs(addtypes) do addtype(v[1], v[2]) end

-- these ones not in table as not helpful with vararg or arrays
t.inotify_event = ffi.typeof("struct inotify_event")
t.epoll_events = ffi.typeof("struct epoll_event[?]") -- TODO add metatable, like pollfds
t.io_events = ffi.typeof("struct io_event[?]")
t.iocbs = ffi.typeof("struct iocb[?]")

t.iocb_ptrs = ffi.typeof("struct iocb *[?]")
t.string_array = ffi.typeof("const char *[?]")

t.ints = ffi.typeof("int[?]")
t.buffer = ffi.typeof("char[?]")

t.int1 = ffi.typeof("int[1]")
t.int64_1 = ffi.typeof("int64_t[1]")
t.uint64_1 = ffi.typeof("uint64_t[1]")
t.socklen1 = ffi.typeof("socklen_t[1]")
t.off1 = ffi.typeof("off_t[1]")
t.loff1 = ffi.typeof("loff_t[1]")
t.uid1 = ffi.typeof("uid_t[1]")
t.gid1 = ffi.typeof("gid_t[1]")
t.int2 = ffi.typeof("int[2]")
t.timespec2 = ffi.typeof("struct timespec[2]")

-- still need pointers to these
pt.inotify_event = ptt(t.inotify_event)

-- types with metatypes
metatype("error", "struct {int errno;}", {
  __tostring = function(e) return S.strerror(e.errno) end,
  __index = function(t, k)
    if k == 'sym' then return errsyms[t.errno] end
    if k == 'lsym' then return errsyms[t.errno]:sub(2):lower() end
    if S.E[k] then return S.E[k] == t.errno end
    local uk = S.E['E' .. k:upper()]
    if uk then return uk == t.errno end
  end,
  __new = function(tp, errno)
    if not errno then errno = ffi.errno() end
    return ffi.new(tp, errno)
  end
})

-- cast socket address to actual type based on family
local samap, samap2 = {}, {}

meth.sockaddr = {
  index = {
    family = function(sa) return sa.sa_family end,
  }
}

metatype("sockaddr", "struct sockaddr", {
  __index = function(sa, k) if meth.sockaddr.index[k] then return meth.sockaddr.index[k](sa) end end,
})

meth.sockaddr_storage = {
  index = {
    family = function(sa) return sa.ss_family end,
  },
  newindex = {
    family = function(sa, v) sa.ss_family = S.AF[v] end,
  }
}

-- experiment, see if we can use this as generic type, to avoid allocations.
metatype("sockaddr_storage", "struct sockaddr_storage", {
  __index = function(sa, k)
    if meth.sockaddr_storage.index[k] then return meth.sockaddr_storage.index[k](sa) end
    local st = samap2[sa.ss_family]
    if st then
      local cs = st(sa)
      return cs[k]
    end
  end,
  __newindex = function(sa, k, v)
    if meth.sockaddr_storage.newindex[k] then
      meth.sockaddr_storage.newindex[k](sa, v)
      return
    end
    local st = samap2[sa.ss_family]
    if st then
      local cs = st(sa)
      cs[k] = v
    end
  end,
  __new = function(tp, init)
    local ss = ffi.new(tp)
    local family
    if init and init.family then family = S.AF[init.family] end
    local st
    if family then
      st = samap2[family]
      ss.ss_family = family
      init.family = nil
    end
    if st then
      local cs = st(ss)
      for k, v in pairs(init) do
        cs[k] = v
      end
    end
    return ss
  end,
})

meth.sockaddr_in = {
  index = {
    family = function(sa) return sa.sin_family end,
    port = function(sa) return S.ntohs(sa.sin_port) end,
    addr = function(sa) return sa.sin_addr end,
  },
  newindex = {
    port = function(sa, v) sa.sin_port = S.htons(v) end
  }
}

metatype("sockaddr_in", "struct sockaddr_in", {
  __index = function(sa, k) if meth.sockaddr_in.index[k] then return meth.sockaddr_in.index[k](sa) end end,
  __newindex = function(sa, k, v) if meth.sockaddr_in.newindex[k] then meth.sockaddr_in.newindex[k](sa, v) end end,
  __new = function(tp, port, addr) -- TODO allow table init
    if not ffi.istype(t.in_addr, addr) then
      addr = t.in_addr(addr)
      if not addr then return end
    end
    return ffi.new(tp, S.AF.INET, S.htons(port or 0), addr)
  end
})

meth.sockaddr_in6 = {
  index = {
    family = function(sa) return sa.sin6_family end,
    port = function(sa) return S.ntohs(sa.sin6_port) end,
    addr = function(sa) return sa.sin6_addr end,
  },
  newindex = {
    port = function(sa, v) sa.sin6_port = S.htons(v) end
  }
}

metatype("sockaddr_in6", "struct sockaddr_in6", {
  __index = function(sa, k) if meth.sockaddr_in6.index[k] then return meth.sockaddr_in6.index[k](sa) end end,
  __newindex = function(sa, k, v) if meth.sockaddr_in6.newindex[k] then meth.sockaddr_in6.newindex[k](sa, v) end end,
  __new = function(tp, port, addr, flowinfo, scope_id) -- reordered initialisers. TODO allow table init
    if not ffi.istype(t.in6_addr, addr) then
      addr = t.in6_addr(addr)
      if not addr then return end
    end
    return ffi.new(tp, S.AF.INET6, S.htons(port or 0), flowinfo or 0, addr, scope_id or 0)
  end
})

meth.sockaddr_un = {
  index = {
    family = function(sa) return sa.un_family end,
  },
}

metatype("sockaddr_un", "struct sockaddr_un", {
  __index = function(sa, k) if meth.sockaddr_un.index[k] then return meth.sockaddr_un.index[k](sa) end end,
  __new = function(tp) return ffi.new(tp, S.AF.UNIX) end,
})

local nlgroupmap = { -- map from netlink socket type to group names. Note there are two forms of name though, bits and shifts.
  [S.NETLINK.ROUTE] = "RTMGRP_", -- or RTNLGRP_ and shift not mask TODO make shiftflags function
  -- add rest of these
  [S.NETLINK.SELINUX] = "SELNLGRP_",
}

meth.sockaddr_nl = {
  index = {
    family = function(sa) return sa.nl_family end,
    pid = function(sa) return sa.nl_pid end,
    groups = function(sa) return sa.nl_groups end,
  },
  newindex = {
    pid = function(sa, v) sa.nl_pid = v end,
    groups = function(sa, v) sa.nl_groups = v end,
  }
}

metatype("sockaddr_nl", "struct sockaddr_nl", {
  __index = function(sa, k) if meth.sockaddr_nl.index[k] then return meth.sockaddr_nl.index[k](sa) end end,
  __newindex = function(sa, k, v) if meth.sockaddr_nl.newindex[k] then meth.sockaddr_nl.newindex[k](sa, v) end end,
  __new = function(tp, pid, groups, nltype)
    if type(pid) == "table" then
      local tb = pid
      pid, groups, nltype = tb.nl_pid or tb.pid, tb.nl_groups or tb.groups, tb.type
    end
    if nltype and nlgroupmap[nltype] then groups = stringflags(groups, nlgroupmap[nltype]) end -- see note about shiftflags
    return ffi.new(tp, {nl_family = S.AF.NETLINK, nl_pid = pid, nl_groups = groups})
  end,
})

samap = {
  [S.AF.UNIX] = t.sockaddr_un,
  [S.AF.INET] = t.sockaddr_in,
  [S.AF.INET6] = t.sockaddr_in6,
  [S.AF.NETLINK] = t.sockaddr_nl,
}

meth.stat = {
  index = {
    dev = function(st) return tonumber(st.st_dev) end,
    ino = function(st) return tonumber(st.st_ino) end,
    mode = function(st) return st.st_mode end,
    nlink = function(st) return st.st_nlink end,
    uid = function(st) return st.st_uid end,
    gid = function(st) return st.st_gid end,
    rdev = function(st) return tonumber(st.st_rdev) end,
    size = function(st) return tonumber(st.st_size) end,
    blksize = function(st) return tonumber(st.st_blksize) end,
    blocks = function(st) return tonumber(st.st_blocks) end,
    atime = function(st) return tonumber(st.st_atime) end,
    ctime = function(st) return tonumber(st.st_ctime) end,
    mtime = function(st) return tonumber(st.st_mtime) end,
    major = function(st) return S.major(st.st_rdev) end,
    minor = function(st) return S.minor(st.st_rdev) end,
    isreg = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFREG end,
    isdir = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFDIR end,
    ischr = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFCHR end,
    isblk = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFBLK end,
    isfifo = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFIFO end,
    islnk = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFLNK end,
    issock = function(st) return bit.band(st.st_mode, S.S_IFMT) == S.S_IFSOCK end,
  }
}

metatype("stat", stattypename, { -- either struct stat on 64 bit or struct stat64 on 32 bit
  __index = function(st, k) if meth.stat.index[k] then return meth.stat.index[k](st) end end,
})

meth.siginfo = {
  index = {
    si_pid     = function(s) return s.sifields.kill.si_pid end,
    si_uid     = function(s) return s.sifields.kill.si_uid end,
    si_timerid = function(s) return s.sifields.timer.si_tid end,
    si_overrun = function(s) return s.sifields.timer.si_overrun end,
    si_status  = function(s) return s.sifields.sigchld.si_status end,
    si_utime   = function(s) return s.sifields.sigchld.si_utime end,
    si_stime   = function(s) return s.sifields.sigchld.si_stime end,
    si_value   = function(s) return s.sifields.rt.si_sigval end,
    si_int     = function(s) return s.sifields.rt.si_sigval.sival_int end,
    si_ptr     = function(s) return s.sifields.rt.si_sigval.sival_ptr end,
    si_addr    = function(s) return s.sifields.sigfault.si_addr end,
    si_band    = function(s) return s.sifields.sigpoll.si_band end,
    si_fd      = function(s) return s.sifields.sigpoll.si_fd end,
  },
  newindex = {
    si_pid     = function(s, v) s.sifields.kill.si_pid = v end,
    si_uid     = function(s, v) s.sifields.kill.si_uid = v end,
    si_timerid = function(s, v) s.sifields.timer.si_tid = v end,
    si_overrun = function(s, v) s.sifields.timer.si_overrun = v end,
    si_status  = function(s, v) s.sifields.sigchld.si_status = v end,
    si_utime   = function(s, v) s.sifields.sigchld.si_utime = v end,
    si_stime   = function(s, v) s.sifields.sigchld.si_stime = v end,
    si_value   = function(s, v) s.sifields.rt.si_sigval = v end,
    si_int     = function(s, v) s.sifields.rt.si_sigval.sival_int = v end,
    si_ptr     = function(s, v) s.sifields.rt.si_sigval.sival_ptr = v end,
    si_addr    = function(s, v) s.sifields.sigfault.si_addr = v end,
    si_band    = function(s, v) s.sifields.sigpoll.si_band = v end,
    si_fd      = function(s, v) s.sifields.sigpoll.si_fd = v end,
  }
}

metatype("siginfo", "struct siginfo", {
  __index = function(t, k) if meth.siginfo.index[k] then return meth.siginfo.index[k](t) end end,
  __newindex = function(t, k, v) if meth.siginfo.newindex[k] then meth.siginfo.newindex[k](t, v) end end,
})

metatype("macaddr", "struct {uint8_t mac_addr[6];}", {
  __tostring = function(m)
    local hex = {}
    for i = 1, 6 do
      hex[i] = string.format("%02x", m.mac_addr[i - 1])
    end
    return table.concat(hex, ":")
  end,
  __new = function(tp, str)
    local mac = ffi.new(tp)
    if str then
      for i = 1, 6 do
        local n = tonumber(str:sub(i * 3 - 2, i * 3 - 1), 16) -- TODO more checks on syntax
        mac.mac_addr[i - 1] = n
      end
    end
    return mac
  end,
})

meth.timeval = {
  index = {
    time = function(tv) return tonumber(tv.tv_sec) + tonumber(tv.tv_usec) / 1000000 end,
    sec = function(tv) return tonumber(tv.tv_sec) end,
    usec = function(tv) return tonumber(tv.tv_usec) end,
  },
  newindex = {
    time = function(tv, v)
      local i, f = math.modf(v)
      tv.tv_sec, tv.tv_usec = i, math.floor(f * 1000000)
    end,
    sec = function(tv, v) tv.tv_sec = v end,
    usec = function(tv, v) tv.tv_usec = v end,
  }
}

meth.rlimit = {
  index = {
    cur = function(r) return tonumber(r.rlim_cur) end,
    max = function(r) return tonumber(r.rlim_max) end,
  }
}

metatype("rlimit", "struct rlimit64", {
  __index = function(r, k) if meth.rlimit.index[k] then return meth.rlimit.index[k](r) end end,
})

metatype("timeval", "struct timeval", {
  __index = function(tv, k) if meth.timeval.index[k] then return meth.timeval.index[k](tv) end end,
  __newindex = function(tv, k, v) if meth.timeval.newindex[k] then meth.timeval.newindex[k](tv, v) end end,
  __new = function(tp, v)
    if not v then v = {0, 0} end
    if type(v) ~= "number" then return ffi.new(tp, v) end
    local ts = ffi.new(tp)
    ts.time = v
    return ts
  end
})

meth.timespec = {
  index = {
    time = function(tv) return tonumber(tv.tv_sec) + tonumber(tv.tv_nsec) / 1000000000 end,
    sec = function(tv) return tonumber(tv.tv_sec) end,
    nsec = function(tv) return tonumber(tv.tv_nsec) end,
  },
  newindex = {
    time = function(tv, v)
      local i, f = math.modf(v)
      tv.tv_sec, tv.tv_nsec = i, math.floor(f * 1000000000)
    end,
    sec = function(tv, v) tv.tv_sec = v end,
    nsec = function(tv, v) tv.tv_nsec = v end,
  }
}

metatype("timespec", "struct timespec", {
  __index = function(tv, k) if meth.timespec.index[k] then return meth.timespec.index[k](tv) end end,
  __newindex = function(tv, k, v) if meth.timespec.newindex[k] then meth.timespec.newindex[k](tv, v) end end,
  __new = function(tp, v)
    if not v then v = {0, 0} end
    if type(v) ~= "number" then return ffi.new(tp, v) end
    local ts = ffi.new(tp)
    ts.time = v
    return ts
  end
})

local function itnormal(v)
  if not v then v = {{0, 0}, {0, 0}} end
  if v.interval then
    v.it_interval = v.interval
    v.interval = nil
  end
  if v.value then
    v.it_value = v.value
    v.value = nil
  end
  if not v.it_interval then
    v.it_interval = v[1]
    v[1] = nil
  end
  if not v.it_value then
    v.it_value = v[2]
    v[2] = nil
  end
  return v
end

meth.itimerspec = {
  index = {
    interval = function(it) return it.it_interval end,
    value = function(it) return it.it_value end,
  }
}

metatype("itimerspec", "struct itimerspec", {
  __index = function(it, k) if meth.itimerspec.index[k] then return meth.itimerspec.index[k](it) end end,
  __new = function(tp, v)
    v = itnormal(v)
    v.it_interval = istype(t.timespec, v.it_interval) or t.timespec(v.it_interval)
    v.it_value = istype(t.timespec, v.it_value) or t.timespec(v.it_value)
    return ffi.new(tp, v)
  end
})

metatype("itimerval", "struct itimerval", {
  __index = function(it, k) if meth.itimerspec.index[k] then return meth.itimerspec.index[k](it) end end, -- can use same meth
  __new = function(tp, v)
    v = itnormal(v)
    v.it_interval = istype(t.timeval, v.it_interval) or t.timeval(v.it_interval)
    v.it_value = istype(t.timeval, v.it_value) or t.timeval(v.it_value)
    return ffi.new(tp, v)
  end
})

mt.iovecs = {
  __index = function(io, k)
    return io.iov[k - 1]
  end,
  __newindex = function(io, k, v)
    v = istype(t.iovec, v) or t.iovec(v)
    ffi.copy(io.iov[k - 1], v, s.iovec)
  end,
  __len = function(io) return io.count end,
  __new = function(tp, is)
    if type(is) == 'number' then return ffi.new(tp, is, is) end
    local count = #is
    local iov = ffi.new(tp, count, count)
    for n = 1, count do
      local i = is[n]
      if type(i) == 'string' then
        local buf = t.buffer(#i)
        ffi.copy(buf, i, #i)
        iov[n].iov_base = buf
        iov[n].iov_len = #i
      elseif type(i) == 'number' then
        iov[n].iov_base = t.buffer(i)
        iov[n].iov_len = i
      elseif ffi.istype(t.iovec, i) then
        ffi.copy(iov[n], i, s.iovec)
      elseif type(i) == 'cdata' then -- eg buffer or other structure
        iov[n].iov_base = i
        iov[n].iov_len = ffi.sizeof(i)
      else -- eg table
        iov[n] = i
      end
    end
    return iov
  end
}

t.iovecs = ffi.metatype("struct { int count; struct iovec iov[?];}", mt.iovecs) -- do not use metatype helper as variable size

metatype("pollfd", "struct pollfd", {
  __index = function(t, k)
    if k == 'fileno' then return t.fd end
    local prefix = "POLL"
    if k:sub(1, #prefix) ~= prefix then k = prefix .. k:upper() end
    return bit.band(t.revents, S[k]) ~= 0
  end
})

mt.pollfds = {
  __index = function(p, k)
    return p.pfd[k - 1]
  end,
  __newindex = function(p, k, v)
    v = istype(t.pollfd, v) or t.pollfd(v)
    ffi.copy(p.pfd[k - 1], v, s.pollfd)
  end,
  __len = function(p) return p.count end,
  __new = function(tp, ps)
    if type(ps) == 'number' then return ffi.new(tp, ps, ps) end
    local count = #ps
    local fds = ffi.new(tp, count, count)
    for n = 1, count do
      fds[n].fd = getfd(ps[n].fd)
      fds[n].events = stringflags(ps[n].events, "POLL")
      fds[n].revents = 0
    end
    return fds
  end
}

t.pollfds = ffi.metatype("struct {int count; struct pollfd pfd[?];}", mt.pollfds)

metatype("in_addr", "struct in_addr", {
  __tostring = function(a) return S.inet_ntop(S.AF.INET, a) end,
  __new = function(tp, s)
    local addr = ffi.new(tp)
    if s then addr = S.inet_pton(S.AF.INET, s, addr) end
    return addr
  end
})

metatype("in6_addr", "struct in6_addr", {
  __tostring = function(a) return S.inet_ntop(S.AF.INET6, a) end,
  __new = function(tp, s)
    local addr = ffi.new(tp)
    if s then addr = S.inet_pton(S.AF.INET6, s, addr) end
    return addr
  end
})

S.addrtype = {
  [S.AF.INET] = t.in_addr,
  [S.AF.INET6] = t.in6_addr,
}

-- signal set handlers TODO replace with metatypes
local function mksigset(str)
  if not str then return t.sigset() end
  if type(str) ~= 'string' then return str end
  local f = t.sigset()
  local a = split(",", str)
  for i, v in ipairs(a) do
    local st = trim(v:upper())
    if st:sub(1, 3) ~= "SIG" then st = "SIG" .. st end
    local sig = S[st]
    if not sig then error("invalid signal: " .. v) end -- don't use this format if you don't want exceptions, better than silent ignore
    local d = bit.rshift(sig - 1, 5) -- always 32 bits
    f.val[d] = bit.bor(f.val[d], bit.lshift(1, (sig - 1) % 32))
  end
  return f
end

local function sigismember(set, sig)
  local d = bit.rshift(sig - 1, 5) -- always 32 bits
  return bit.band(set.val[d], bit.lshift(1, (sig - 1) % 32)) ~= 0
end

local function sigemptyset(set)
  for i = 0, s.sigset / 4 - 1 do
    if set.val[i] ~= 0 then return false end
  end
  return true
end

local function sigaddset(set, sig)
  set = mksigset(set)
  local d = bit.rshift(sig - 1, 5)
  set.val[d] = bit.bor(set.val[d], bit.lshift(1, (sig - 1) % 32))
  return set
end

local function sigdelset(set, sig)
  set = mksigset(set)
  local d = bit.rshift(sig - 1, 5)
  set.val[d] = bit.band(set.val[d], bit.bnot(bit.lshift(1, (sig - 1) % 32)))
  return set
end

local function sigaddsets(set, sigs) -- allow multiple
  if type(sigs) ~= "string" then return sigaddset(set, sigs) end
  set = mksigset(set)
  local a = split(",", sigs)
  for i, v in ipairs(a) do
    local s = trim(v:upper())
    if s:sub(1, 3) ~= "SIG" then s = "SIG" .. s end
    local sig = S[s]
    if not sig then error("invalid signal: " .. v) end -- don't use this format if you don't want exceptions, better than silent ignore
    sigaddset(set, sig)
  end
  return set
end

local function sigdelsets(set, sigs) -- allow multiple
  if type(sigs) ~= "string" then return sigdelset(set, sigs) end
  set = mksigset(set)
  local a = split(",", sigs)
  for i, v in ipairs(a) do
    local s = trim(v:upper())
    if s:sub(1, 3) ~= "SIG" then s = "SIG" .. s end
    local sig = S[s]
    if not sig then error("invalid signal: " .. v) end -- don't use this format if you don't want exceptions, better than silent ignore
    sigdelset(set, sig)
  end
  return set
end

metatype("sigset", "sigset_t", {
  __index = function(set, k)
    if k == 'add' then return sigaddsets end
    if k == 'del' then return sigdelsets end
    if k == 'isemptyset' then return sigemptyset(set) end
    local prefix = "SIG"
    if k:sub(1, #prefix) ~= prefix then k = prefix .. k:upper() end
    local sig = S[k]
    if sig then return sigismember(set, sig) end
  end
})

local voidp = ffi.typeof("void *")

pt.void = function(x)
  return ffi.cast(voidp, x)
end

samap2 = {
  [S.AF.UNIX] = pt.sockaddr_un,
  [S.AF.INET] = pt.sockaddr_in,
  [S.AF.INET6] = pt.sockaddr_in6,
  [S.AF.NETLINK] = pt.sockaddr_nl,
}

-- misc

-- typed values for pointer comparison
local zeropointer = pt.void(0)
local errpointer = pt.void(-1)

local function div(a, b) return math.floor(tonumber(a) / tonumber(b)) end -- would be nicer if replaced with shifts, as only powers of 2

function S.nogc(d) ffi.gc(d, nil) end

-- return helpers. not so much needed any more, often not using

-- straight passthrough, only needed for real 64 bit quantities. Used eg for seek (file might have giant holes!)
local function ret64(ret)
  if ret == t.uint64(-1) then return nil, t.error() end
  return ret
end

local function retnum(ret) -- return Lua number where double precision ok, eg file ops etc
  ret = tonumber(ret)
  if ret == -1 then return nil, t.error() end
  return ret
end

local function retfd(ret)
  if ret == -1 then return nil, t.error() end
  return t.fd(ret)
end

-- used for no return value, return true for use of assert
local function retbool(ret)
  if ret == -1 then return nil, t.error() end
  return true
end

-- used for pointer returns, -1 is failure
local function retptr(ret)
  if ret == errpointer then return nil, t.error() end
  return ret
end

mt.wait = {
  __index = function(w, k)
    local WTERMSIG = bit.band(w.status, 0x7f)
    local EXITSTATUS = bit.rshift(bit.band(w.status, 0xff00), 8)
    local WIFEXITED = (WTERMSIG == 0)
    local tab = {
      WIFEXITED = WIFEXITED,
      WIFSTOPPED = bit.band(w.status, 0xff) == 0x7f,
      WIFSIGNALED = not WIFEXITED and bit.band(w.status, 0x7f) ~= 0x7f -- I think this is right????? TODO recheck, cleanup
    }
    if tab.WIFEXITED then tab.EXITSTATUS = EXITSTATUS end
    if tab.WIFSTOPPED then tab.WSTOPSIG = EXITSTATUS end
    if tab.WIFSIGNALED then tab.WTERMSIG = WTERMSIG end
    if tab[k] then return tab[k] end
    local uc = 'W' .. k:upper()
    if tab[uc] then return tab[uc] end
  end
}

local function retwait(ret, status)
  if ret == -1 then return nil, t.error() end
  return setmetatable({pid = ret, status = status}, mt.wait)
end

-- endian conversion
if ffi.abi("be") then -- nothing to do
  function S.htonl(b) return b end
else
  function S.htonl(b) return bit.bswap(b) end
  function S.htons(b) return bit.rshift(bit.bswap(b), 16) end
end
S.ntohl = S.htonl -- reverse is the same
S.ntohs = S.htons -- reverse is the same

-- TODO add tests
mt.sockaddr_un = {
  __index = function(un, k)
    local sa = un.addr
    if k == 'family' then return tonumber(sa.sun_family) end
    local namelen = un.addrlen - s.sun_family
    if namelen > 0 then
      if sa.sun_path[0] == 0 then
        if k == 'abstract' then return true end
        if k == 'name' then return ffi.string(rets.addr.sun_path, namelen) end -- should we also remove leading \0?
      else
        if k == 'name' then return ffi.string(rets.addr.sun_path) end
      end
    else
      if k == 'unnamed' then return true end
    end
  end
}

local function sa(addr, addrlen)
  local family = addr.family
  if family == S.AF.UNIX then -- we return Lua metatable not metatype, as need length to decode
    local sa = t.sockaddr_un()
    ffi.copy(sa, addr, addrlen)
    return setmetatable({addr = sa, addrlen = addrlen}, mt.sockaddr_un)
  end
  return addr
end

-- functions from section 3 that we use for ip addresses etc
function S.strerror(errno) return ffi.string(C.strerror(errno)) end

local INET6_ADDRSTRLEN = 46
local INET_ADDRSTRLEN = 16

function S.inet_ntop(af, src)
  af = S.AF[af]
  if af == S.AF.INET then
    local b = pt.uchar(src)
    return tonumber(b[0]) .. "." .. tonumber(b[1]) .. "." .. tonumber(b[2]) .. "." .. tonumber(b[3])
  end
  local len = INET6_ADDRSTRLEN
  local dst = t.buffer(len)
  local ret = C.inet_ntop(af, src, dst, len)
  if ret == nil then return nil, t.error() end
  return ffi.string(dst)
end

function S.inet_pton(af, src, addr)
  af = S.AF[af]
  if not addr then addr = S.addrtype[af]() end
  local ret = C.inet_pton(af, src, addr)
  if ret == -1 then return nil, t.error() end
  if ret == 0 then return nil end -- maybe return string
  return addr
end

function S.inet_aton(s)
  return S.inet_pton(S.AF.INET, s)
end

function S.inet_ntoa(addr)
  return S.inet_ntop(S.AF.INET, addr)
end

-- generic inet name to ip, also with netmask support TODO think of better name?
function S.inet_name(src, netmask)
  local addr
  if not netmask then
    local a, b = src:find("/", 1, true)
    if a then
      netmask = tonumber(src:sub(b + 1))
      src = src:sub(1, a - 1)
    end
  end
  if src:find(":", 1, true) then -- ipv6
    addr = S.inet_pton(S.AF.INET6, src)
    if not addr then return nil end
    if not netmask then netmask = 128 end
  else
    addr = S.inet_pton(S.AF.INET, src)
    if not addr then return nil end
    if not netmask then netmask = 32 end
  end
  return addr, netmask
end

t.i6432 = ffi.typeof("union {int64_t i64; int32_t i32[2];}")
t.u6432 = ffi.typeof("union {uint64_t i64; uint32_t i32[2];}")

if ffi.abi("le") then
  function S.i64(n)
    local u = t.i6432(n)
    return u.i32[1], u.i32[0]
  end
  function S.u64(n)
    local u = t.u6432(n)
    return u.i32[1], u.i32[0]
  end
else
  function S.i64(n)
    local u = t.i6432(n)
    return u.i32[0], u.i32[1]
  end
  function S.u64(n)
    local u = t.u6432(n)
    return u.i32[0], u.i32[1]
  end
end

-- these functions might not be in libc, or are buggy so provide direct syscall fallbacks
local function inlibc(f) return ffi.C[f] end

-- glibc caches pid, but this fails to work eg after clone(). Musl is fine TODO test for this?
function C.getpid()
  return C.syscall(S.SYS.getpid)
end

-- clone interface provided is not same as system one, and is less convenient
function C.clone(flags, signal, stack, ptid, tls, ctid)
  return C.syscall(S.SYS.clone, t.int(flags), pt.void(stack), pt.void(ptid), pt.void(tls), pt.void(ctid))
end

-- getdents is not provided by glibc. Musl has weak alias so not visible.
function C.getdents(fd, buf, size)
  return C.syscall(S.SYS.getdents64, t.int(fd), buf, t.uint(size))
end

-- getcwd will allocate memory, so use syscall
function C.getcwd(buf, size)
  return C.syscall(S.SYS.getcwd, pt.void(buf), t.ulong(size))
end

-- for stat we use the syscall as libc might have a different struct stat for compatibility
-- TODO see if we can avoid this, at least for reasonable libc. Musl returns the right struct.
if ffi.abi("64bit") then
  function C.stat(path, buf)
    return C.syscall(S.SYS.stat, path, pt.void(buf))
  end
  function C.lstat(path, buf)
    return C.syscall(S.SYS.lstat, path, pt.void(buf))
  end
  function C.fstat(fd, buf)
    return C.syscall(S.SYS.fstat, t.int(fd), pt.void(buf))
  end
  function C.fstatat(fd, path, buf, flags)
    return C.syscall(S.SYS.fstatat, t.int(fd), path, pt.void(buf), t.int(flags))
  end
else
  function C.stat(path, buf)
    return C.syscall(S.SYS.stat64, path, pt.void(buf))
  end
  function C.lstat(path, buf)
    return C.syscall(S.SYS.lstat64, path, pt.void(buf))
  end
  function C.fstat(fd, buf)
    return C.syscall(S.SYS.fstat64, t.int(fd), pt.void(buf))
  end
  function C.fstatat(fd, path, buf, flags)
    return C.syscall(S.SYS.fstatat64, t.int(fd), path, pt.void(buf), t.int(flags))
  end
end

-- lseek is a mess in 32 bit, use _llseek syscall to get clean result
if ffi.abi("32bit") then
  function C.lseek(fd, offset, whence)
    local result = t.loff1()
    local off1, off2 = S.u64(offset)
    local ret = C.syscall(S.SYS._llseek, t.int(fd), t.ulong(off1), t.ulong(off2), pt.void(result), t.uint(whence))
    if ret == -1 then return -1 end
    return result[0]
  end
end

-- native Linux aio not generally supported, only posix API TODO these are not working
function C.io_setup(nr_events, ctx)
  return C.syscall(S.SYS.io_setup, t.uint(nr_events), ctx)
end
function C.io_destroy(ctx)
  return C.syscall(S.SYS.io_destroy, ctx)
end
function C.io_cancel(ctx, iocb, result)
  return C.syscall(S.SYS.io_cancel, ctx, iocb, result)
end
function C.io_getevents(ctx, min, nr, events, timeout)
  return C.syscall(S.SYS.io_getevents, ctx, t.long(min), t.long(nr), events, timeout)
end
function C.io_submit(ctx, iocb, nr)
  return C.syscall(S.SYS.io_submit, ctx, t.long(nr), iocb)
end

-- note dev_t not passed as 64 bits to this syscall
function CC.mknod(pathname, mode, dev)
  return C.syscall(S.SYS.mknod, pathname, t.mode(mode), t.long(dev))
end
function CC.mknodat(fd, pathname, mode, dev)
  return C.syscall(S.SYS.mknodat, t.int(fd), pathname, t.mode(mode), t.long(dev))
end
-- pivot_root is not provided by glibc, is provided by Musl
function CC.pivot_root(new_root, put_old)
  return C.syscall(C.SYS.pivot_root, new_root, put_old)
end

--[[ if you need to split 64 bit args on 32 bit syscalls use code like this
if ffi.abi("64bit") then
  function CC.fallocate(fd, mode, offset, len)
    return C.syscall(S.SYS.fallocate, t.int(fd), t.uint(mode), t.loff(offset), t.loff(len))
  end
else -- 32 bit uses splits for 64 bit args
  function CC.fallocate(fd, mode, offset, len)
    local off2, off1 = S.u64(offset)
    local len2, len1 = S.u64(len)
    return C.syscall(S.SYS.fallocate, t.int(fd), t.uint(mode), t.uint32(off1), t.uint32(off2), t.uint32(len1), t.uint32(len2))
  end
end
]]

-- if not in libc replace

-- with glibc in -rt
if not pcall(inlibc, "clock_getres") then
  local rt = ffi.load "rt"
  C.clock_getres = rt.clock_getres
  C.clock_settime = rt.clock_settime
  C.clock_gettime = rt.clock_gettime
  C.clock_nanosleep = rt.clock_nanosleep
end

-- not in eglibc
if not pcall(inlibc, "mknod") then C.mknod = CC.mknod end
if not pcall(inlibc, "mknodat") then C.mknodat = CC.mknodat end
if not pcall(inlibc, "pivot_root") then C.pivot_root = CC.pivot_root end

-- main definitions start here
function S.open(pathname, flags, mode)
  flags = bit.bor(stringflags(flags, "O_"), S.O_LARGEFILE)
  return retfd(C.open(pathname, flags, S.mode(mode)))
end

function S.openat(dirfd, pathname, flags, mode)
  flags = bit.bor(stringflags(flags, "O_"), S.O_LARGEFILE)
  return retfd(C.openat(getfd_at(dirfd), pathname, flags, S.mode(mode)))
end

-- TODO dup3 can have a race condition (see man page) although Musl fixes, appears eglibc does not
function S.dup(oldfd, newfd, flags)
  if newfd == nil then return retfd(C.dup(getfd(oldfd))) end
  return retfd(C.dup3(getfd(oldfd), getfd(newfd), flags or 0))
end

mt.pipe = {
  __index = {
    close = function(p)
      local ok1, err1 = p[1]:close()
      local ok2, err2 = p[2]:close()
      if not ok1 then return nil, err1 end
      if not ok2 then return nil, err2 end
      return true
    end,
    read = function(p, ...) return p[1]:read(...) end,
    write = function(p, ...) return p[2]:write(...) end,
    pread = function(p, ...) return p[1]:pread(...) end,
    pwrite = function(p, ...) return p[2]:pwrite(...) end,
    nonblock = function(p)
      local ok, err = p[1]:nonblock()
      if not ok then return nil, err end
      local ok, err = p[2]:nonblock()
      if not ok then return nil, err end
      return true
    end,
    block = function(p)
      local ok, err = p[1]:block()
      if not ok then return nil, err end
      local ok, err = p[2]:block()
      if not ok then return nil, err end
      return true
    end,
    setblocking = function(p, b)
      local ok, err = p[1]:setblocking(b)
      if not ok then return nil, err end
      local ok, err = p[2]:setblocking(b)
      if not ok then return nil, err end
      return true
    end,
    -- TODO many useful methods still missing
  }
}

function S.pipe(flags)
  local fd2 = t.int2()
  local ret = C.pipe2(fd2, stringflags(flags, "O_"))
  if ret == -1 then return nil, t.error() end
  return setmetatable({t.fd(fd2[0]), t.fd(fd2[1])}, mt.pipe)
end

function S.close(fd)
  local fileno = getfd(fd)
  if fileno == -1 then return true end -- already closed
  local ret = C.close(fileno)
  if ret == -1 then
    local errno = ffi.errno()
    if ffi.istype(t.fd, fd) and errno ~= S.E.INTR then -- file will still be open if interrupted
      fd.filenum = -1 -- make sure cannot accidentally close this fd object again
    end
    return nil, t.error()
  end
  if ffi.istype(t.fd, fd) then
    fd.filenum = -1 -- make sure cannot accidentally close this fd object again
  end
  return true
end

function S.creat(pathname, mode) return retfd(C.creat(pathname, S.mode(mode))) end
function S.unlink(pathname) return retbool(C.unlink(pathname)) end
function S.unlinkat(dirfd, path, flags)
  return retbool(C.unlinkat(getfd_at(dirfd), path, flaglist(flags, "AT_", {"AT_REMOVEDIR"})))
end
function S.rename(oldpath, newpath) return retbool(C.rename(oldpath, newpath)) end
function S.renameat(olddirfd, oldpath, newdirfd, newpath)
  return retbool(C.renameat(getfd_at(olddirfd), oldpath, getfd_at(newdirfd), newpath))
end
function S.chdir(path) return retbool(C.chdir(path)) end
function S.mkdir(path, mode) return retbool(C.mkdir(path, S.mode(mode))) end
function S.mkdirat(fd, path, mode) return retbool(C.mkdirat(getfd_at(fd), path, S.mode(mode))) end
function S.rmdir(path) return retbool(C.rmdir(path)) end
function S.acct(filename) return retbool(C.acct(filename)) end
function S.chmod(path, mode) return retbool(C.chmod(path, S.mode(mode))) end
function S.link(oldpath, newpath) return retbool(C.link(oldpath, newpath)) end
function S.linkat(olddirfd, oldpath, newdirfd, newpath, flags)
  return retbool(C.linkat(getfd_at(olddirfd), oldpath, getfd_at(newdirfd), newpath, flaglist(flags, "AT_", {"AT_SYMLINK_FOLLOW"})))
end
function S.symlink(oldpath, newpath) return retbool(C.symlink(oldpath, newpath)) end
function S.symlinkat(oldpath, newdirfd, newpath) return retbool(C.symlinkat(oldpath, getfd_at(newdirfd), newpath)) end
function S.pause() return retbool(C.pause()) end

function S.chown(path, owner, group) return retbool(C.chown(path, owner or -1, group or -1)) end
function S.fchown(fd, owner, group) return retbool(C.fchown(getfd(fd), owner or -1, group or -1)) end
function S.lchown(path, owner, group) return retbool(C.lchown(path, owner or -1, group or -1)) end
function S.fchownat(dirfd, path, owner, group, flags)
  return retbool(C.fchownat(getfd_at(dirfd), path, owner or -1, group or -1, flaglist(flags, "AT_", {"AT_SYMLINK_NOFOLLOW"})))
end

function S.truncate(path, length) return retbool(C.truncate(path, length)) end
function S.ftruncate(fd, length) return retbool(C.ftruncate(getfd(fd), length)) end

function S.access(pathname, mode) return retbool(C.access(pathname, accessflags(mode))) end
function S.faccessat(dirfd, pathname, mode, flags)
  return retbool(C.faccessat(getfd_at(dirfd), pathname, accessflags(mode), flaglist(flags, "AT_", {"AT_EACCESS", "AT_SYMLINK_NOFOLLOW"})))
end

function S.readlink(path, buffer, size)
  size = size or S.PATH_MAX
  buffer = buffer or t.buffer(size)
  local ret = tonumber(C.readlink(path, buffer, size))
  if ret == -1 then return nil, t.error() end
  return ffi.string(buffer, ret)
end

function S.readlinkat(dirfd, path, buffer, size)
  size = size or S.PATH_MAX
  buffer = buffer or t.buffer(size)
  local ret = tonumber(C.readlinkat(getfd_at(dirfd), path, buffer, size))
  if ret == -1 then return nil, t.error() end
  return ffi.string(buffer, ret)
end

function S.mknod(pathname, mode, dev)
  return retbool(C.mknod(pathname, stringflags(mode, "S_"), dev or 0))
end
function S.mknodat(fd, pathname, mode, dev)
  return retbool(C.mknodat(getfd_at(fd), pathname, stringflags(mode, "S_"), dev or 0))
end

-- mkfifo is from man(3), add for convenience
function S.mkfifo(path, mode) return S.mknod(path, bit.bor(stringflags(mode, "S_"), S.S_IFIFO)) end
function S.mkfifoat(fd, path, mode) return S.mknodat(fd, path, bit.bor(stringflags(mode, "S_"), S.S_IFIFO), 0) end

local function retnume(f, ...) -- for cases where need to explicitly set and check errno, ie signed int return
  ffi.errno(0)
  local ret = f(...)
  local errno = ffi.errno()
  if errno ~= 0 then return nil, t.error() end
  return ret
end

function S.nice(inc) return retnume(C.nice, inc) end
-- NB glibc is shifting these values from what strace shows, as per man page, kernel adds 20 to make these values positive...
-- might cause issues with other C libraries in which case may shift to using system call
function S.getpriority(which, who) return retnume(C.getpriority, S.PRIO[which], who or 0) end
function S.setpriority(which, who, prio) return retnume(C.setpriority, S.PRIO[which], who or 0, prio) end

 -- we could allocate ptid, ctid, tls if required in flags instead. TODO add signal into flag parsing directly
function S.clone(flags, signal, stack, ptid, tls, ctid)
  flags = stringflags(flags, "CLONE_") + stringflag(signal, "SIG")
  return retnum(C.clone(flags, stack, ptid, tls, ctid))
end

function S.unshare(flags) return retbool(C.unshare(stringflags(flags, "CLONE_"))) end
function S.setns(fd, nstype) return retbool(C.setns(getfd(fd), stringflag(nstype, "CLONE_"))) end

function S.fork() return retnum(C.fork()) end
function S.execve(filename, argv, envp)
  local cargv = t.string_array(#argv + 1, argv)
  cargv[#argv] = nil -- LuaJIT does not zero rest of a VLA
  local cenvp = t.string_array(#envp + 1, envp)
  cenvp[#envp] = nil
  return retbool(C.execve(filename, cargv, cenvp))
end

function S.ioctl(d, request, argp)
  local ret = C.ioctl(getfd(d), request, argp)
  if ret == -1 then return nil, t.error() end
  -- some different return types may need to be handled
  return true
end

function S.reboot(cmd) return retbool(C.reboot(S.LINUX_REBOOT_CMD[cmd])) end

-- ffi metatype on dirent?
function S.getdents(fd, buf, size, noiter) -- default behaviour is to iterate over whole directory, use noiter if you have very large directories
  if not buf then
    size = size or 4096
    buf = t.buffer(size)
  end
  local d = {}
  local ret
  repeat
    ret = C.getdents(getfd(fd), buf, size)
    if ret == -1 then return nil, t.error() end
    local i = 0
    while i < ret do
      local dp = pt.dirent(buf + i)
      local dd = setmetatable({inode = tonumber(dp.d_ino), offset = tonumber(dp.d_off), type = tonumber(dp.d_type)}, mt.dents)
      d[ffi.string(dp.d_name)] = dd -- could calculate length
      i = i + dp.d_reclen
    end
  until noiter or ret == 0
  return d
end

function S.wait()
  local status = t.int1()
  return retwait(C.wait(status), status[0])
end
function S.waitpid(pid, options)
  local status = t.int1()
  return retwait(C.waitpid(pid, status, stringflags(options, "W")), status[0])
end
function S.waitid(idtype, id, options, infop) -- note order of args, as usually dont supply infop
  if not infop then infop = t.siginfo() end
  infop.si_pid = 0 -- see notes on man page
  local ret = C.waitid(S.P[idtype], id or 0, infop, stringflags(options, "W"))
  if ret == -1 then return nil, t.error() end
  return infop -- return table here?
end

function S._exit(status) C._exit(S.EXIT[status]) end
function S.exit(status) C.exit(S.EXIT[status]) end

function S.read(fd, buf, count)
  if buf then return retnum(C.read(getfd(fd), buf, count)) end -- user supplied a buffer, standard usage
  if not count then count = 4096 end
  buf = t.buffer(count)
  local ret = C.read(getfd(fd), buf, count)
  if ret == -1 then return nil, t.error() end
  return ffi.string(buf, tonumber(ret)) -- user gets a string back, can get length from #string
end

function S.write(fd, buf, count) return retnum(C.write(getfd(fd), buf, count or #buf)) end
function S.pread(fd, buf, count, offset) return retnum(C.pread64(getfd(fd), buf, count, offset)) end
function S.pwrite(fd, buf, count, offset) return retnum(C.pwrite64(getfd(fd), buf, count or #buf, offset)) end

function S.lseek(fd, offset, whence)
  return ret64(C.lseek(getfd(fd), offset or 0, S.SEEK[whence]))
end

function S.send(fd, buf, count, flags) return retnum(C.send(getfd(fd), buf, count or #buf, stringflags(flags, "MSG_"))) end
function S.sendto(fd, buf, count, flags, addr, addrlen)
  return retnum(C.sendto(getfd(fd), buf, count or #buf, stringflags(flags, "MSG_"), addr, addrlen or ffi.sizeof(addr)))
end

function S.sendmsg(fd, msg, flags)
  if not msg then -- send a single byte message, eg enough to send credentials
    local buf1 = t.buffer(1)
    local io = t.iovecs{{buf1, 1}}
    msg = t.msghdr{msg_iov = io.iov, msg_iovlen = #io}
  end
  return retbool(C.sendmsg(getfd(fd), msg, stringflags(flags, "MSG_")))
end

function S.readv(fd, iov)
  iov = istype(t.iovecs, iov) or t.iovecs(iov)
  return retnum(C.readv(getfd(fd), iov.iov, #iov))
end

function S.writev(fd, iov)
  iov = istype(t.iovecs, iov) or t.iovecs(iov)
  return retnum(C.writev(getfd(fd), iov.iov, #iov))
end

function S.preadv(fd, iov, offset)
  iov = istype(t.iovecs, iov) or t.iovecs(iov)
  return retnum(C.preadv64(getfd(fd), iov.iov, #iov, offset))
end

function S.pwritev(fd, iov, offset)
  iov = istype(t.iovecs, iov) or t.iovecs(iov)
  return retnum(C.pwritev64(getfd(fd), iov.iov, #iov, offset))
end

function S.recv(fd, buf, count, flags) return retnum(C.recv(getfd(fd), buf, count or #buf, stringflags(flags, "MSG_"))) end
function S.recvfrom(fd, buf, count, flags, ss, addrlen)
  if not ss then
    ss = t.sockaddr_storage()
    addrlen = t.socklen1(s.sockaddr_storage)
  end
  local ret = C.recvfrom(getfd(fd), buf, count, stringflags(flags, "MSG_"), ss, addrlen)
  if ret == -1 then return nil, t.error() end
  return {count = tonumber(ret), addr = sa(ss, addrlen[0])}
end

function S.setsockopt(fd, level, optname, optval, optlen)
   -- allocate buffer for user, from Lua type if know how, int and bool so far
  if not optlen and type(optval) == 'boolean' then if optval then optval = 1 else optval = 0 end end
  if not optlen and type(optval) == 'number' then
    optval = t.int1(optval)
    optlen = s.int
  end
  return retbool(C.setsockopt(getfd(fd), stringflag(level, "SOL_"), stringflag(optname, "SO_"), optval, optlen))
end

function S.getsockopt(fd, level, optname) -- will need fixing for non int/bool options
  local optval, optlen = t.int1(), t.socklen1()
  optlen[0] = s.int
  local ret = C.getsockopt(getfd(fd), level, optname, optval, optlen)
  if ret == -1 then return nil, t.error() end
  return tonumber(optval[0]) -- no special case for bool
end

function S.fchdir(fd) return retbool(C.fchdir(getfd(fd))) end
function S.fsync(fd) return retbool(C.fsync(getfd(fd))) end
function S.fdatasync(fd) return retbool(C.fdatasync(getfd(fd))) end
function S.fchmod(fd, mode) return retbool(C.fchmod(getfd(fd), S.mode(mode))) end
function S.fchmodat(dirfd, pathname, mode)
  return retbool(C.fchmodat(getfd_at(dirfd), pathname, S.mode(mode), 0)) -- no flags actually supported
end
function S.sync_file_range(fd, offset, count, flags)
  return retbool(C.sync_file_range(getfd(fd), offset, count, stringflags(flags, "SYNC_FILE_RANGE_")))
end

function S.stat(path, buf)
  if not buf then buf = t.stat() end
  local ret = C.stat(path, buf)
  if ret == -1 then return nil, t.error() end
  return buf
end

function S.lstat(path, buf)
  if not buf then buf = t.stat() end
  local ret = C.lstat(path, buf)
  if ret == -1 then return nil, t.error() end
  return buf
end

function S.fstat(fd, buf)
  if not buf then buf = t.stat() end
  local ret = C.fstat(getfd(fd), buf)
  if ret == -1 then return nil, t.error() end
  return buf
end

function S.fstatat(fd, path, buf, flags)
  if not buf then buf = t.stat() end
  local ret = C.fstatat(getfd_at(fd), path, buf, flaglist(flags, "AT_", {"AT_NO_AUTOMOUNT", "AT_SYMLINK_NOFOLLOW"}))
  if ret == -1 then return nil, t.error() end
  return buf
end

local function gettimespec2(ts)
  if ts and (not ffi.istype(t.timespec2, ts)) then
    local s1, s2 = ts[1], ts[2]
    ts = t.timespec2()
    if type(s1) == 'string' then ts[0].tv_nsec = stringflag(s1, "UTIME_") else ts[0] = t.timespec(s1) end
    if type(s2) == 'string' then ts[1].tv_nsec = stringflag(s2, "UTIME_") else ts[1] = t.timespec(s2) end
  end
  return ts
end

function S.futimens(fd, ts)
  return retbool(C.futimens(getfd(fd), gettimespec2(ts)))
end

function S.utimensat(dirfd, path, ts, flags)
  return retbool(C.utimensat(getfd_at(dirfd), path, gettimespec2(ts), flaglist(flags, "AT_", {"AT_SYMLINK_NOFOLLOW"})))
end

-- because you can just pass floats to all the time functions, just use the same one, but provide different templates
function S.utime(path, actime, modtime)
  local ts
  if not modtime then modtime = actime end
  if actime and modtime then ts = {actime, modtime} end
  return S.utimensat(nil, path, ts)
end

S.utimes = S.utime

function S.chroot(path) return retbool(C.chroot(path)) end

function S.getcwd(buf, size)
  size = size or S.PATH_MAX
  buf = buf or t.buffer(size)
  local ret = C.getcwd(buf, size)
  if ret == -1 then return nil, t.error() end
  return ffi.string(buf)
end

function S.statfs(path)
  local st = t.statfs()
  local ret = C.statfs(path, st)
  if ret == -1 then return nil, t.error() end
  return st
end

function S.fstatfs(fd)
  local st = t.statfs()
  local ret = C.fstatfs(getfd(fd), st)
  if ret == -1 then return nil, t.error() end
  return st
end

function S.nanosleep(req, rem)
  req = istype(t.timespec, req) or t.timespec(req)
  rem = rem or t.timespec()
  local ret = C.nanosleep(req, rem)
  if ret == -1 then
    if ffi.errno() == S.E.INTR then return rem else return nil, t.error() end
  end
  return true
end

function S.sleep(sec) -- standard libc function
  local rem, err = S.nanosleep(sec)
  if not rem then return nil, err end
  if rem == true then return 0 end
  return tonumber(rem.tv_sec)
end

function S.mmap(addr, length, prot, flags, fd, offset)
  return retptr(C.mmap(addr, length, stringflags(prot, "PROT_"), stringflags(flags, "MAP_"), getfd(fd), offset))
end
function S.munmap(addr, length)
  return retbool(C.munmap(addr, length))
end
function S.msync(addr, length, flags) return retbool(C.msync(addr, length, stringflags(flags, "MS_"))) end
function S.mlock(addr, len) return retbool(C.mlock(addr, len)) end
function S.munlock(addr, len) return retbool(C.munlock(addr, len)) end
function S.mlockall(flags) return retbool(C.mlockall(stringflags(flags, "MCL_"))) end
function S.munlockall() return retbool(C.munlockall()) end
function S.mremap(old_address, old_size, new_size, flags, new_address)
  return retptr(C.mremap(old_address, old_size, new_size, stringflags(flags, "MREMAP_"), new_address))
end
function S.madvise(addr, length, advice) return retbool(C.madvise(addr, length, S.MADV[advice])) end
function S.fadvise(fd, advice, offset, len) -- note argument order
  return retbool(C.posix_fadvise(getfd(fd), offset or 0, len or 0, S.POSIX_FADV[advice]))
end
function S.fallocate(fd, mode, offset, len)
  return retbool(C.fallocate(getfd(fd), S.FALLOC_FL[mode], offset or 0, len))
end
function S.posix_fallocate(fd, offset, len) return S.fallocate(fd, 0, offset, len) end
function S.readahead(fd, offset, count) return retbool(C.readahead(getfd(fd), offset, count)) end

local function sproto(domain, protocol) -- helper function to lookup protocol type depending on domain
  if domain == S.AF.NETLINK then return S.NETLINK[protocol] end
  return protocol or 0
end

function S.socket(domain, stype, protocol)
  domain = S.AF[domain]
  local ret = C.socket(domain, stringflags(stype, "SOCK_"), sproto(domain, protocol))
  if ret == -1 then return nil, t.error() end
  return t.fd(ret)
end

mt.socketpair = {
  __index = {
    close = function(s)
      local ok1, err1 = s[1]:close()
      local ok2, err2 = s[2]:close()
      if not ok1 then return nil, err1 end
      if not ok2 then return nil, err2 end
      return true
    end,
    nonblock = function(s)
      local ok, err = s[1]:nonblock()
      if not ok then return nil, err end
      local ok, err = s[2]:nonblock()
      if not ok then return nil, err end
      return true
    end,
    block = function(s)
      local ok, err = s[1]:block()
      if not ok then return nil, err end
      local ok, err = s[2]:block()
      if not ok then return nil, err end
      return true
    end,
    setblocking = function(s, b)
      local ok, err = s[1]:setblocking(b)
      if not ok then return nil, err end
      local ok, err = s[2]:setblocking(b)
      if not ok then return nil, err end
      return true
    end,
  }
}

function S.socketpair(domain, stype, protocol)
  domain = S.AF[domain]
  local sv2 = t.int2()
  local ret = C.socketpair(domain, stringflags(stype, "SOCK_"), sproto(domain, protocol), sv2)
  if ret == -1 then return nil, t.error() end
  return setmetatable({t.fd(sv2[0]), t.fd(sv2[1])}, mt.socketpair)
end

function S.bind(sockfd, addr, addrlen)
  return retbool(C.bind(getfd(sockfd), addr, addrlen or ffi.sizeof(addr)))
end

function S.listen(sockfd, backlog) return retbool(C.listen(getfd(sockfd), backlog or S.SOMAXCONN)) end
function S.connect(sockfd, addr, addrlen)
  return retbool(C.connect(getfd(sockfd), addr, addrlen or ffi.sizeof(addr)))
end

function S.shutdown(sockfd, how) return retbool(C.shutdown(getfd(sockfd), S.SHUT[how])) end

function S.accept(sockfd, flags, addr, addrlen)
  if not addr then addr = t.sockaddr_storage() end
  if not addrlen then addrlen = t.socklen1(addrlen or ffi.sizeof(addr)) end
  local ret
  if not flags
    then ret = C.accept(getfd(sockfd), addr, addrlen)
    else ret = C.accept4(getfd(sockfd), addr, addrlen, stringflags(flags, "SOCK_"))
  end
  if ret == -1 then return nil, t.error() end
  return {fd = t.fd(ret), addr = sa(addr, addrlen[0])}
end

function S.getsockname(sockfd, ss, addrlen)
  if not ss then
    ss = t.sockaddr_storage()
    addrlen = t.socklen1(s.sockaddr_storage)
  end
  local ret = C.getsockname(getfd(sockfd), ss, addrlen)
  if ret == -1 then return nil, t.error() end
  return sa(ss, addrlen[0])
end

function S.getpeername(sockfd, ss, addrlen)
  if not ss then
    ss = t.sockaddr_storage()
    addrlen = t.socklen1(s.sockaddr_storage)
  end
  local ret = C.getpeername(getfd(sockfd), ss, addrlen)
  if ret == -1 then return nil, t.error() end
  return sa(ss, addrlen[0])
end

local function getflock(arg)
  if not arg then arg = t.flock() end
  if not ffi.istype(t.flock, arg) then
    for _, v in pairs {"type", "whence", "start", "len", "pid"} do -- allow use of short names
      if arg[v] then
        arg["l_" .. v] = arg[v] -- TODO cleanup this to use table?
        arg[v] = nil
      end
    end
    arg.l_type = S.FCNTL_LOCK[arg.l_type]
    arg.l_whence = S.SEEK[arg.l_whence]
    arg = t.flock(arg)
  end
  return arg
end

local fcntl_commands = {
  [S.F.SETFL] = function(arg) return bit.bor(stringflags(arg, "O_"), S.O_LARGEFILE) end,
  [S.F.SETFD] = function(arg) return stringflag(arg, "FD_") end,
  [S.F.GETLK] = getflock,
  [S.F.SETLK] = getflock,
  [S.F.SETLKW] = getflock,
}

local fcntl_ret = {
  [S.F.DUPFD] = function(ret) return t.fd(ret) end,
  [S.F.DUPFD_CLOEXEC] = function(ret) return t.fd(ret) end,
  [S.F.GETFD] = function(ret) return tonumber(ret) end,
  [S.F.GETFL] = function(ret) return tonumber(ret) end,
  [S.F.GETLEASE] = function(ret) return tonumber(ret) end,
  [S.F.GETOWN] = function(ret) return tonumber(ret) end,
  [S.F.GETSIG] = function(ret) return tonumber(ret) end,
  [S.F.GETPIPE_SZ] = function(ret) return tonumber(ret) end,
  [S.F.GETLK] = function(ret, arg) return arg end,
}

function S.fcntl(fd, cmd, arg)
  cmd = S.F[cmd]

  if fcntl_commands[cmd] then arg = fcntl_commands[cmd](arg) end

  local ret = C.fcntl(getfd(fd), cmd, pt.void(arg or 0))
  if ret == -1 then return nil, t.error() end

  if fcntl_ret[cmd] then return fcntl_ret[cmd](ret, arg) end

  return true
end

function S.uname()
  local u = t.utsname()
  local ret = C.uname(u)
  if ret == -1 then return nil, t.error() end
  return {sysname = ffi.string(u.sysname), nodename = ffi.string(u.nodename), release = ffi.string(u.release),
          version = ffi.string(u.version), machine = ffi.string(u.machine), domainname = ffi.string(u.domainname)}
end

function S.gethostname()
  local u, err = S.uname()
  if not u then return nil, err end
  return u.nodename
end

function S.getdomainname()
  local u, err = S.uname()
  if not u then return nil, err end
  return u.domainname
end

function S.sethostname(s) -- only accept Lua string, do not see use case for buffer as well
  return retbool(C.sethostname(s, #s))
end

function S.setdomainname(s)
  return retbool(C.setdomainname(s, #s))
end

-- does not support passing a function as a handler, use sigaction instead
-- actualy glibc does not call the syscall anyway, defines in terms of sigaction; TODO we should too
function S.signal(signum, handler) return retbool(C.signal(stringflag(signum, "SIG"), S.SIGACT[handler])) end

-- missing siginfo functionality for now, only supports getting signum TODO
-- NOTE I do not think it is safe to call this with a function argument as the jit compiler will not know when it is going to
-- be called, so have removed this functionality again
-- recommend using signalfd to handle signals if you need to do anything complex.
function S.sigaction(signum, handler, mask, flags)
  local sa
  if ffi.istype(t.sigaction, handler) then sa = handler
  else
    if type(handler) == 'string' then
      handler = ffi.cast(t.sighandler, t.int1(S.SIGACT[handler]))
    --elseif
    --  type(handler) == 'function' then handler = ffi.cast(t.sighandler, handler) -- TODO check if gc problem here? need to copy?
    end
    sa = t.sigaction{sa_handler = handler, sa_mask = mksigset(mask), sa_flags = stringflags(flags, "SA_")}
  end
  local old = t.sigaction()
  local ret = C.sigaction(stringflag(signum, "SIG"), sa, old)
  if ret == -1 then return nil, t.error() end
  return old
end

function S.kill(pid, sig) return retbool(C.kill(pid, stringflag(sig, "SIG"))) end
function S.killpg(pgrp, sig) return S.kill(-pgrp, sig) end

function S.gettimeofday(tv)
  if not tv then tv = t.timeval() end -- note it is faster to pass your own tv if you call a lot
  local ret = C.gettimeofday(tv, nil)
  if ret == -1 then return nil, t.error() end
  return tv
end

function S.settimeofday(tv) return retbool(C.settimeofday(tv, nil)) end

function S.time()
  return tonumber(C.time(nil))
end

function S.sysinfo(info)
  if not info then info = t.sysinfo() end
  local ret = C.sysinfo(info)
  if ret == -1 then return nil, t.error() end
  return info
end

local function growattrbuf(f, a, b)
  local len = 512
  local buffer = t.buffer(len)
  local ret
  repeat
    if b then
      ret = tonumber(f(a, b, buffer, len))
    else
      ret = tonumber(f(a, buffer, len))
    end
    if ret == -1 and ffi.errno ~= S.E.ERANGE then return nil, t.error() end
    if ret == -1 then
      len = len * 2
      buffer = t.buffer(len)
    end
  until ret >= 0

  if ret > 0 then ret = ret - 1 end -- has trailing \0

  return ffi.string(buffer, ret)
end

local function lattrbuf(sys, a)
  local s, err = growattrbuf(sys, a)
  if not s then return nil, err end
  return split('\0', s)
end

function S.listxattr(path) return lattrbuf(C.listxattr, path) end
function S.llistxattr(path) return lattrbuf(C.llistxattr, path) end
function S.flistxattr(fd) return lattrbuf(C.flistxattr, getfd(fd)) end

function S.setxattr(path, name, value, flags)
  return retbool(C.setxattr(path, name, value, #value + 1, stringflag(flags, "XATTR_")))
end
function S.lsetxattr(path, name, value, flags)
  return retbool(C.lsetxattr(path, name, value, #value + 1, stringflag(flags, "XATTR_")))
end
function S.fsetxattr(fd, name, value, flags)
  return retbool(C.fsetxattr(getfd(fd), name, value, #value + 1, stringflag(flags, "XATTR_")))
end

function S.getxattr(path, name) return growattrbuf(C.getxattr, path, name) end
function S.lgetxattr(path, name) return growattrbuf(C.lgetxattr, path, name) end
function S.fgetxattr(fd, name) return growattrbuf(C.fgetxattr, getfd(fd), name) end

function S.removexattr(path, name) return retbool(C.removexattr(path, name)) end
function S.lremovexattr(path, name) return retbool(C.lremovexattr(path, name)) end
function S.fremovexattr(fd, name) return retbool(C.fremovexattr(getfd(fd), name)) end

-- helper function to set and return attributes in tables
local function xattr(list, get, set, remove, path, t)
  local l, err = list(path)
  if not l then return nil, err end
  if not t then -- no table, so read
    local r = {}
    for _, name in ipairs(l) do
      r[name] = get(path, name) -- ignore errors
    end
    return r
  end
  -- write
  for _, name in ipairs(l) do
    if t[name] then
      set(path, name, t[name]) -- ignore errors, replace
      t[name] = nil
    else
      remove(path, name)
    end
  end
  for name, value in pairs(t) do
    set(path, name, value) -- ignore errors, create
  end
  return true
end

function S.xattr(path, t) return xattr(S.listxattr, S.getxattr, S.setxattr, S.removexattr, path, t) end
function S.lxattr(path, t) return xattr(S.llistxattr, S.lgetxattr, S.lsetxattr, S.lremovexattr, path, t) end
function S.fxattr(fd, t) return xattr(S.flistxattr, S.fgetxattr, S.fsetxattr, S.fremovexattr, fd, t) end

-- fdset handlers
local function mkfdset(fds, nfds) -- should probably check fd is within range (1024), or just expand structure size
  local set = t.fdset()
  for i, v in ipairs(fds) do
    local fd = tonumber(getfd(v))
    if fd + 1 > nfds then nfds = fd + 1 end
    local fdelt = bit.rshift(fd, 5) -- always 32 bits
    set.fds_bits[fdelt] = bit.bor(set.fds_bits[fdelt], bit.lshift(1, fd % 32)) -- always 32 bit words
  end
  return set, nfds
end

local function fdisset(fds, set)
  local f = {}
  for i, v in ipairs(fds) do
    local fd = tonumber(getfd(v))
    local fdelt = bit.rshift(fd, 5) -- always 32 bits
    if bit.band(set.fds_bits[fdelt], bit.lshift(1, fd % 32)) ~= 0 then table.insert(f, v) end -- careful not to duplicate fd objects
  end
  return f
end

function S.sigprocmask(how, set)
  local oldset = t.sigset()
  local ret = C.sigprocmask(S.SIGPM[how], mksigset(set), oldset)
  if ret == -1 then return nil, t.error() end
  return oldset
end

function S.sigpending()
  local set = t.sigset()
  local ret = C.sigpending(set)
  if ret == -1 then return nil, t.error() end
 return set
end

function S.sigsuspend(mask) return retbool(C.sigsuspend(mksigset(mask))) end

function S.signalfd(set, flags, fd) -- note different order of args, as fd usually empty. See also signalfd_read()
  return retfd(C.signalfd(getfd(fd) or -1, mksigset(set), stringflags(flags, "SFD_")))
end

-- TODO convert to metatype?
function S.select(s) -- note same structure as returned
  local r, w, e
  local nfds = 0
  local timeout
  if s.timeout then
    if ffi.istype(t.timeval, s.timeout) then timeout = s.timeout else timeout = t.timeval(s.timeout) end
  end
  r, nfds = mkfdset(s.readfds or {}, nfds or 0)
  w, nfds = mkfdset(s.writefds or {}, nfds)
  e, nfds = mkfdset(s.exceptfds or {}, nfds)
  local ret = C.select(nfds, r, w, e, timeout)
  if ret == -1 then return nil, t.error() end
  return {readfds = fdisset(s.readfds or {}, r), writefds = fdisset(s.writefds or {}, w),
          exceptfds = fdisset(s.exceptfds or {}, e), count = tonumber(ret)}
end

function S.pselect(s) -- note same structure as returned
  local r, w, e
  local nfds = 0
  local timeout, set
  if s.timeout then
    if ffi.istype(t.timespec, s.timeout) then timeout = s.timeout else timeout = t.timespec(s.timeout) end
  end
  if s.sigset then set = mksigset(s.sigset) end
  r, nfds = mkfdset(s.readfds or {}, nfds or 0)
  w, nfds = mkfdset(s.writefds or {}, nfds)
  e, nfds = mkfdset(s.exceptfds or {}, nfds)
  local ret = C.pselect(nfds, r, w, e, timeout, set)
  if ret == -1 then return nil, t.error() end
  return {readfds = fdisset(s.readfds or {}, r), writefds = fdisset(s.writefds or {}, w),
          exceptfds = fdisset(s.exceptfds or {}, e), count = tonumber(ret), sigset = set}
end

function S.poll(fds, timeout)
  fds = istype(t.pollfds, fds) or t.pollfds(fds)
  local ret = C.poll(fds.pfd, #fds, timeout or -1)
  if ret == -1 then return nil, t.error() end
  return fds
end

-- note that syscall does return timeout remaining but libc does not, due to standard prototype
function S.ppoll(fds, timeout, set)
  fds = istype(t.pollfds, fds) or t.pollfds(fds)
  if timeout then timeout = istype(t.timespec, timeout) or t.timespec(timeout) end
  if set then set = mksigset(set) end
  local ret = C.ppoll(fds.pfd, #fds, timeout, set)
  if ret == -1 then return nil, t.error() end
  return fds
end

function S.mount(source, target, filesystemtype, mountflags, data)
  if type(source) == "table" then
    local t = source
    source = t.source
    target = t.target
    filesystemtype = t.type
    mountflags = t.flags
    data = t.data
  end
  return retbool(C.mount(source, target, filesystemtype, stringflags(mountflags, "MS_"), data))
end

function S.umount(target, flags)
  if flags then return retbool(C.umount2(target, flaglist(flags, "", {"MNT_FORCE", "MNT_DETACH", "MNT_EXPIRE", "UMOUNT_NOFOLLOW"}))) end
  return retbool(C.umount(target))
end

-- unlimited value. TODO metatype should return this to Lua.
-- TODO math.huge should be converted to this in __new
S.RLIM_INFINITY = ffi.cast("rlim64_t", -1)

function S.prlimit(pid, resource, new_limit, old_limit)
  if new_limit then new_limit = istype(t.rlimit, new_limit) or t.rlimit(new_limit) end
  old_limit = old_limit or t.rlimit()
  local ret = C.prlimit64(pid or 0, stringflag(resource, "RLIMIT_"), new_limit, old_limit)
  if ret == -1 then return nil, t.error() end
  return old_limit
end

-- old rlimit functions are 32 bit only so now defined using prlimit
function S.getrlimit(resource)
  return S.prlimit(0, resource)
end

function S.setrlimit(resource, rlim)
  local ret, err = S.prlimit(0, resource, rlim)
  if not ret then return nil, err end
  return true
end

function S.epoll_create(flags)
  return retfd(C.epoll_create1(stringflags(flags, "EPOLL_")))
end

function S.epoll_ctl(epfd, op, fd, event, data)
  if not ffi.istype(t.epoll_event, event) then
    local events = stringflags(event, "EPOLL")
    event = t.epoll_event()
    event.events = events
    if data then event.data.u64 = data else event.data.fd = getfd(fd) end
  end
  return retbool(C.epoll_ctl(getfd(epfd), stringflag(op, "EPOLL_CTL_"), getfd(fd), event))
end

local epoll_flags = {"EPOLLIN", "EPOLLOUT", "EPOLLRDHUP", "EPOLLPRI", "EPOLLERR", "EPOLLHUP"}

function S.epoll_wait(epfd, events, maxevents, timeout, sigmask) -- includes optional epoll_pwait functionality
  if not maxevents then maxevents = 16 end
  if not events then events = t.epoll_events(maxevents) end
  if sigmask then sigmask = mksigset(sigmask) end
  local ret
  if sigmask then
    ret = C.epoll_pwait(getfd(epfd), events, maxevents, timeout or -1, sigmask)
  else
    ret = C.epoll_wait(getfd(epfd), events, maxevents, timeout or -1)
  end
  if ret == -1 then return nil, t.error() end
  local r = {}
  for i = 1, ret do -- put in Lua array
    local e = events[i - 1]
    local ev = setmetatable({fileno = tonumber(e.data.fd), data = t.uint64(e.data.u64), events = e.events}, mt.epoll)
    r[i] = ev
  end
  return r
end

function S.splice(fd_in, off_in, fd_out, off_out, len, flags)
  local offin, offout = off_in, off_out
  if off_in and not ffi.istype(t.loff1, off_in) then
    offin = t.loff1()
    offin[0] = off_in
  end
  if off_out and not ffi.istype(t.loff1, off_out) then
    offout = t.loff1()
    offout[0] = off_out
  end
  return retnum(C.splice(getfd(fd_in), offin, getfd(fd_out), offout, len, stringflags(flags, "SPLICE_F_")))
end

function S.vmsplice(fd, iov, flags)
  iov = istype(t.iovecs, iov) or t.iovecs(iov)
  return retnum(C.vmsplice(getfd(fd), iov.iov, #iov, stringflags(flags, "SPLICE_F_")))
end

function S.tee(fd_in, fd_out, len, flags)
  return retnum(C.tee(getfd(fd_in), getfd(fd_out), len, stringflags(flags, "SPLICE_F_")))
end

function S.inotify_init(flags) return retfd(C.inotify_init1(stringflags(flags, "IN_"))) end
function S.inotify_add_watch(fd, pathname, mask) return retnum(C.inotify_add_watch(getfd(fd), pathname, stringflags(mask, "IN_"))) end
function S.inotify_rm_watch(fd, wd) return retbool(C.inotify_rm_watch(getfd(fd), wd)) end

-- helper function to read inotify structs as table from inotify fd
function S.inotify_read(fd, buffer, len)
  if not len then len = 1024 end
  if not buffer then buffer = t.buffer(len) end
  local ret, err = S.read(fd, buffer, len)
  if not ret then return nil, err end
  local off, ee = 0, {}
  while off < ret do
    local ev = pt.inotify_event(buffer + off)
    local le = setmetatable({wd = tonumber(ev.wd), mask = tonumber(ev.mask), cookie = tonumber(ev.cookie)}, mt.inotify)
    if ev.len > 0 then le.name = ffi.string(ev.name) end
    ee[#ee + 1] = le
    off = off + ffi.sizeof(t.inotify_event(ev.len))
  end
  return ee
end

function S.sendfile(out_fd, in_fd, offset, count) -- bit odd having two different return types...
  if not offset then return retnum(C.sendfile(getfd(out_fd), getfd(in_fd), nil, count)) end
  local off = t.off1()
  off[0] = offset
  local ret = C.sendfile(getfd(out_fd), getfd(in_fd), off, count)
  if ret == -1 then return nil, t.error() end
  return {count = tonumber(ret), offset = tonumber(off[0])}
end

function S.eventfd(initval, flags) return retfd(C.eventfd(initval or 0, stringflags(flags, "EFD_"))) end
-- eventfd read and write helpers, as in glibc but Lua friendly. Note returns 0 for EAGAIN, as 0 never returned directly
-- returns Lua number - if you need all 64 bits, pass your own value in and use that for the exact result
function S.eventfd_read(fd, value)
  if not value then value = t.uint64_1() end
  local ret = C.read(getfd(fd), value, 8)
  if ret == -1 and ffi.errno() == S.E.EAGAIN then
    value[0] = 0
    return 0
  end
  if ret == -1 then return nil, t.error() end
  return tonumber(value[0])
end
function S.eventfd_write(fd, value)
  if not value then value = 1 end
  if type(value) == "number" then value = t.uint64_1(value) end
  return retbool(C.write(getfd(fd), value, 8))
end

local function sigcode(s, signo, code)
  s.code = code
  s.signo = signo
  local name = signals[s.signo]
  s[name] = true
  s[name:lower():sub(4)] = true
  local rname = signal_reasons_gen[code]
  if not rname and signal_reasons[signo] then rname = signal_reasons[signo][code] end
  if rname then
    s[rname] = true
    s[rname:sub(rname:find("_") + 1):lower()] = true
  end
end

-- TODO use metatypes
function S.signalfd_read(fd, buffer, len)
  if not len then len = s.signalfd_siginfo * 4 end
  if not buffer then buffer = t.buffer(len) end
  local ret, err = S.read(fd, buffer, len)
  if ret == 0 or (err and err.EAGAIN) then return {} end
  if not ret then return nil, err end
  local offset, ss = 0, {}
  while offset < ret do
    local ssi = pt.signalfd_siginfo(buffer + offset)
    local sig = {}
    sig.errno = tonumber(ssi.ssi_errno)
    sigcode(sig, tonumber(ssi.ssi_signo), tonumber(ssi.ssi_code))

    if sig.SI_USER or sig.SI_QUEUE then
      sig.pid = tonumber(ssi.ssi_pid)
      sig.uid = tonumber(ssi.ssi_uid)
      sig.int = tonumber(ssi.ssi_int)
      sig.ptr = t.uint64(ssi.ssi_ptr)
    elseif sig.SI_TIMER then
      sig.overrun = tonumber(ssi.ssi_overrun)
      sig.timerid = tonumber(ssi.ssi_tid)
    end

    if sig.SIGCHLD then 
      sig.pid = tonumber(ssi.ssi_pid)
      sig.uid = tonumber(ssi.ssi_uid)
      sig.status = tonumber(ssi.ssi_status)
      sig.utime = tonumber(ssi.ssi_utime) / 1000000 -- convert to seconds
      sig.stime = tonumber(ssi.ssi_stime) / 1000000
    elseif sig.SIGILL or sig.SIGFPE or sig.SIGSEGV or sig.SIGBUS or sig.SIGTRAP then
      sig.addr = t.uint64(ssi.ssi_addr)
    elseif sig.SIGIO or sig.SIGPOLL then
      sig.band = tonumber(ssi.ssi_band) -- should split this up, is events from poll, TODO
      sig.fd = tonumber(ssi.ssi_fd)
    end

    ss[#ss + 1] = sig
    offset = offset + s.signalfd_siginfo
  end
  return ss
end

function S.getitimer(which, value)
  if not value then value = t.itimerval() end
  local ret = C.getitimer(stringflag(which, "ITIMER_"), value)
  if ret == -1 then return nil, t.error() end
  return value
end

function S.setitimer(which, it)
  it = istype(t.itimerval, it) or t.itimerval(it)
  local oldtime = t.itimerval()
  local ret = C.setitimer(stringflag(which, "ITIMER_"), it, oldtime)
  if ret == -1 then return nil, t.error() end
  return oldtime
end

function S.timerfd_create(clockid, flags)
  return retfd(C.timerfd_create(stringflag(clockid, "CLOCK_"), stringflags(flags, "TFD_")))
end

function S.timerfd_settime(fd, flags, it, oldtime)
  oldtime = oldtime or t.itimerspec()
  it = istype(t.itimerspec, it) or t.itimerspec(it)
  local ret = C.timerfd_settime(getfd(fd), stringflag(flags, "TFD_TIMER_"), it, oldtime)
  if ret == -1 then return nil, t.error() end
  return oldtime
end

function S.timerfd_gettime(fd, curr_value)
  if not curr_value then curr_value = t.itimerspec() end
  local ret = C.timerfd_gettime(getfd(fd), curr_value)
  if ret == -1 then return nil, t.error() end
  return curr_value
end

function S.timerfd_read(fd, buffer)
  if not buffer then buffer = t.uint64_1() end
  local ret, err = S.read(fd, buffer, 8)
  if not ret and err.EAGAIN then return 0 end -- will never actually return 0
  if not ret then return nil, err end
  return tonumber(buffer[0])
end

function S.pivot_root(new_root, put_old) return retbool(C.pivot_root(new_root, put_old)) end

-- aio functions
function S.io_setup(nr_events)
  local ctx = t.aio_context()
  local ret = C.io_setup(nr_events, ctx)
  if ret == -1 then return nil, t.error() end
  return ctx
end

function S.io_destroy(ctx)
  if ctx.ctx == 0 then return end
  local ret = retbool(C.io_destroy(ctx.ctx))
  ctx.ctx = 0
  return ret
end

-- TODO replace these functions with metatypes
local function getiocb(ioi, iocb)
  if not iocb then iocb = t.iocb() end
  iocb.aio_lio_opcode = stringflags(ioi.cmd, "IOCB_CMD_")
  iocb.aio_data = ioi.data or 0
  iocb.aio_reqprio = ioi.reqprio or 0
  iocb.aio_fildes = getfd(ioi.fd)
  iocb.aio_buf = ffi.cast(t.int64, ioi.buf) -- TODO check, looks wrong
  iocb.aio_nbytes = ioi.nbytes
  iocb.aio_offset = ioi.offset
  if ioi.resfd then
    iocb.aio_flags = iocb.aio_flags + S.IOCB_FLAG_RESFD
    iocb.aio_resfd = getfd(ioi.resfd)
  end
  return iocb
end

local function getiocbs(iocb, nr)
  if type(iocb) == "table" then
    local io = iocb
    nr = #io
    iocb = t.iocb_ptrs(nr)
    local iocba = t.iocbs(nr)
    for i = 0, nr - 1 do
      local ioi = io[i + 1]
      iocb[i] = iocba + i
      getiocb(ioi, iocba[i])
    end
  end
  return iocb, nr
end

function S.io_cancel(ctx, iocb, result)
  iocb = getiocb(iocb)
  if not result then result = t.io_event() end
  local ret = C.io_cancel(ctx.ctx, iocb, result)
  if ret == -1 then return nil, t.error() end
  return ret
end

function S.io_getevents(ctx, min, nr, events, timeout)
  events = events or t.io_events(nr)
  timeout = istype(t.timespec, timeout) or t.timespec(timeout)
  local ret = C.io_getevents(ctx.ctx, min, nr, events, timeout)
  if ret == -1 then return nil, t.error() end
  -- need to think more about how to return these, eg metatype for io_event?
  local r = {}
  for i = 0, nr - 1 do
    r[i + 1] = events[i]
  end
  r.timeout = timeout
  r.events = events
  r.count = tonumber(ret)
  return r
end

function S.io_submit(ctx, iocb, nr) -- takes an array of pointers to iocb. note order of args TODO redo like iov so no nr
  iocb, nr = getiocbs(iocb)
  return retnum(C.io_submit(ctx.ctx, iocb, nr))
end

-- map for valid options for arg2
local prctlmap = {
  [S.PR_CAPBSET_READ] = "CAP_",
  [S.PR_CAPBSET_DROP] = "CAP_",
  [S.PR_SET_ENDIAN] = "PR_ENDIAN",
  [S.PR_SET_FPEMU] = "PR_FPEMU_",
  [S.PR_SET_FPEXC] = "PR_FP_EXC_",
  [S.PR_SET_PDEATHSIG] = "SIG",
  [S.PR_SET_SECUREBITS] = "SECBIT_",
  [S.PR_SET_TIMING] = "PR_TIMING_",
  [S.PR_SET_TSC] = "PR_TSC_",
  [S.PR_SET_UNALIGN] = "PR_UNALIGN_",
  [S.PR_MCE_KILL] = "PR_MCE_KILL_",
  [S.PR_SET_SECCOMP] = "SECCOMP_MODE_",
}

local prctlrint = { -- returns an integer directly TODO add metatables to set names
  [S.PR_GET_DUMPABLE] = true,
  [S.PR_GET_KEEPCAPS] = true,
  [S.PR_CAPBSET_READ] = true,
  [S.PR_GET_TIMING] = true,
  [S.PR_GET_SECUREBITS] = true,
  [S.PR_MCE_KILL_GET] = true,
  [S.PR_GET_SECCOMP] = true,
}

local prctlpint = { -- returns result in a location pointed to by arg2
  [S.PR_GET_ENDIAN] = true,
  [S.PR_GET_FPEMU] = true,
  [S.PR_GET_FPEXC] = true,
  [S.PR_GET_PDEATHSIG] = true,
  [S.PR_GET_UNALIGN] = true,
}

function S.prctl(option, arg2, arg3, arg4, arg5)
  local i, name
  option = stringflag(option, "PR_") -- actually not all PR_ prefixed options ok some are for other args, could be more specific
  local noption = tonumber(option)
  local m = prctlmap[noption]
  if m then arg2 = stringflag(arg2, m) end
  if option == S.PR_MCE_KILL and arg2 == S.PR_MCE_KILL_SET then arg3 = stringflag(arg3, "PR_MCE_KILL_")
  elseif prctlpint[noption] then
    i = t.int1()
    arg2 = ffi.cast(t.ulong, i)
  elseif option == S.PR_GET_NAME then
    name = t.buffer(16)
    arg2 = ffi.cast(t.ulong, name)
  elseif option == S.PR_SET_NAME then
    if type(arg2) == "string" then arg2 = ffi.cast(t.ulong, arg2) end
  end
  local ret = C.prctl(option, arg2 or 0, arg3 or 0, arg4 or 0, arg5 or 0)
  if ret == -1 then return nil, t.error() end
  if prctlrint[noption] then return ret end
  if prctlpint[noption] then return i[0] end
  if option == S.PR_GET_NAME then
    if name[15] ~= 0 then return ffi.string(name, 16) end -- actually, 15 bytes seems to be longest, aways 0 terminated
    return ffi.string(name)
  end
  return true
end

-- this is the glibc name for the syslog syscall
function S.klogctl(tp, buf, len)
  if not buf and (tp == 2 or tp == 3 or tp == 4) then
    if not len then
      len = C.klogctl(10, nil, 0) -- get size so we can allocate buffer
      if len == -1 then return nil, t.error() end
    end
    buf = t.buffer(len)
  end
  local ret = C.klogctl(tp, buf or nil, len or 0)
  if ret == -1 then return nil, t.error() end
  if tp == 9 or tp == 10 then return tonumber(ret) end
  if tp == 2 or tp == 3 or tp == 4 then return ffi.string(buf, ret) end
  return true
end

function S.adjtimex(a)
  if not a then a = t.timex() end
  if type(a) == 'table' then  -- TODO pull this out to general initialiser for t.timex
    if a.modes then a.modes = tonumber(stringflags(a.modes, "ADJ_")) end
    if a.status then a.status = tonumber(stringflags(a.status, "STA_")) end
    a = t.timex(a)
  end
  local ret = C.adjtimex(a)
  if ret == -1 then return nil, t.error() end
  -- we need to return a table, as we need to return both ret and the struct timex. should probably put timex fields in table
  return setmetatable({state = ret, timex = a}, mt.timex)
end

function S.clock_getres(clk_id, ts)
  ts = istype(t.timespec, ts) or t.timespec(ts)
  local ret = C.clock_getres(stringflag(clk_id, "CLOCK_"), ts)
  if ret == -1 then return nil, t.error() end
  return ts
end

function S.clock_gettime(clk_id, ts)
  ts = istype(t.timespec, ts) or t.timespec(ts)
  local ret = C.clock_gettime(stringflag(clk_id, "CLOCK_"), ts)
  if ret == -1 then return nil, t.error() end
  return ts
end

function S.clock_settime(clk_id, ts)
  ts = istype(t.timespec, ts) or t.timespec(ts)
  return retbool(C.clock_settime(stringflag(clk_id, "CLOCK_"), ts))
end

function S.clock_nanosleep(clk_id, flags, req, rem)
  req = istype(t.timespec, req) or t.timespec(req)
  rem = rem or t.timespec()
  local ret = C.clock_nanosleep(stringflag(clk_id, "CLOCK_"), stringflag(flags, "TIMER_"), req, rem)
  if ret == -1 then
    if ffi.errno() == S.E.INTR then return rem else return nil, t.error() end
  end
  return true
end

-- straight passthroughs, no failure possible, still wrap to allow mocking
function S.getuid() return C.getuid() end
function S.geteuid() return C.geteuid() end
function S.getppid() return C.getppid() end
function S.getgid() return C.getgid() end
function S.getegid() return C.getegid() end
function S.sync() return C.sync() end
function S.alarm(s) return C.alarm(s) end

function S.getpid() return C.getpid() end -- note this will use syscall as overridden above

function S.setuid(uid) return retbool(C.setuid(uid)) end
function S.setgid(gid) return retbool(C.setgid(gid)) end
function S.seteuid(uid) return retbool(C.seteuid(uid)) end
function S.setegid(gid) return retbool(C.setegid(gid)) end
function S.setreuid(ruid, euid) return retbool(C.setreuid(ruid, euid)) end
function S.setregid(rgid, egid) return retbool(C.setregid(rgid, egid)) end

function S.getresuid()
  local ruid, euid, suid = t.uid1(), t.uid1(), t.uid1()
  local ret = C.getresuid(ruid, euid, suid)
  if ret == -1 then return nil, t.error() end
  return {ruid = ruid[0], euid = euid[0], suid = suid[0]}
end
function S.getresgid()
  local rgid, egid, sgid = t.gid1(), t.gid1(), t.gid1()
  local ret = C.getresgid(rgid, egid, sgid)
  if ret == -1 then return nil, t.error() end
  return {rgid = rgid[0], egid = egid[0], sgid = sgid[0]}
end
function S.setresuid(ruid, euid, suid)
  if type(ruid) == "table" then
    local t = ruid
    ruid = t.ruid
    euid = t.euid
    suid = t.suid
  end
  return retbool(C.setresuid(ruid, euid, suid))
end
function S.setresgid(rgid, egid, sgid)
  if type(rgid) == "table" then
    local t = rgid
    rgid = t.rgid
    egid = t.egid
    sgid = t.sgid
  end
  return retbool(C.setresgid(rgid, egid, sgid))
end

t.groups = ffi.metatype("struct {int count; gid_t list[?];}", {
  __index = function(g, k)
    return g.list[k - 1]
  end,
  __newindex = function(g, k, v)
    g.list[k - 1] = v
  end,
  __new = function(tp, gs)
    if type(gs) == 'number' then return ffi.new(tp, gs, gs) end
    return ffi.new(tp, #gs, #gs, gs)
  end,
  __len = function(g) return g.count end,
})

function S.getgroups()
  local size = C.getgroups(0, nil)
  if size == -1 then return nil, t.error() end
  local groups = t.groups(size)
  local ret = C.getgroups(size, groups.list)
  if ret == -1 then return nil, t.error() end
  return groups
end

function S.setgroups(groups)
  if type(groups) == "table" then groups = t.groups(groups) end
  return retbool(C.setgroups(groups.count, groups.list))
end

function S.umask(mask) return C.umask(S.mode(mask)) end

function S.getsid(pid) return retnum(C.getsid(pid or 0)) end
function S.setsid() return retnum(C.setsid()) end

-- handle environment (Lua only provides os.getenv). TODO add metatable to make more Lualike.
function S.environ() -- return whole environment as table
  local environ = ffi.C.environ
  if not environ then return nil end
  local r = {}
  local i = 0
  while environ[i] ~= zeropointer do
    local e = ffi.string(environ[i])
    local eq = e:find('=')
    if eq then
      r[e:sub(1, eq - 1)] = e:sub(eq + 1)
    end
    i = i + 1
  end
  return r
end

function S.getenv(name)
  return S.environ()[name]
end
function S.unsetenv(name) return retbool(C.unsetenv(name)) end
function S.setenv(name, value, overwrite)
  if type(overwrite) == 'boolean' and overwrite then overwrite = 1 end
  return retbool(C.setenv(name, value, overwrite or 0))
end
function S.clearenv() return retbool(C.clearenv()) end

-- 'macros' and helper functions etc
-- TODO from here (approx, some may be in wrong place), move to util library. These are library functions.

function S.major(dev)
  local h, l = S.i64(dev)
  return bit.bor(bit.band(bit.rshift(l, 8), 0xfff), bit.band(h, bit.bnot(0xfff)));
end

function S.minor(dev)
  local h, l = S.i64(dev)
  return bit.bor(bit.band(l, 0xff), bit.band(bit.rshift(l, 12), bit.bnot(0xff)));
end

function S.makedev(major, minor)
  return bit.bor(bit.band(minor, 0xff), bit.lshift(bit.band(major, 0xfff), 8), bit.lshift(bit.band(minor, bit.bnot(0xff)), 12)) + 0x100000000 * bit.band(major, bit.bnot(0xfff))
end

-- cmsg functions, try to hide some of this nasty stuff from the user
local function align(len, a) return bit.band(tonumber(len) + a - 1, bit.bnot(a - 1)) end

local cmsg_align
local cmsg_hdrsize = ffi.sizeof(t.cmsghdr(0))
if ffi.abi('32bit') then
  function cmsg_align(len) return align(len, 4) end
else
  function cmsg_align(len) return align(len, 8) end
end

local cmsg_ahdr = cmsg_align(cmsg_hdrsize)
local function cmsg_space(len) return cmsg_ahdr + cmsg_align(len) end
local function cmsg_len(len) return cmsg_ahdr + len end

-- msg_control is a bunch of cmsg structs, but these are all different lengths, as they have variable size arrays

-- these functions also take and return a raw char pointer to msg_control, to make life easier, as well as the cast cmsg
local function cmsg_firsthdr(msg)
  if tonumber(msg.msg_controllen) < cmsg_hdrsize then return nil end
  local mc = msg.msg_control
  local cmsg = pt.cmsghdr(mc)
  return mc, cmsg
end

local function cmsg_nxthdr(msg, buf, cmsg)
  if tonumber(cmsg.cmsg_len) < cmsg_hdrsize then return nil end -- invalid cmsg
  buf = pt.char(buf)
  local msg_control = pt.char(msg.msg_control)
  buf = buf + cmsg_align(cmsg.cmsg_len) -- find next cmsg
  if buf + cmsg_hdrsize > msg_control + msg.msg_controllen then return nil end -- header would not fit
  cmsg = pt.cmsghdr(buf)
  if buf + cmsg_align(cmsg.cmsg_len) > msg_control + msg.msg_controllen then return nil end -- whole cmsg would not fit
  return buf, cmsg
end

-- if no msg provided, assume want to receive cmsg
function S.recvmsg(fd, msg, flags)
  if not msg then 
    local buf1 = t.buffer(1) -- assume user wants to receive single byte to get cmsg
    local io = t.iovecs{{buf1, 1}}
    local bufsize = 1024 -- sane default, build your own structure otherwise
    local buf = t.buffer(bufsize)
    msg = t.msghdr{msg_iov = io.iov, msg_iovlen = #io, msg_control = buf, msg_controllen = bufsize}
  end
  local ret = C.recvmsg(getfd(fd), msg, stringflags(flags, "MSG_"))
  if ret == -1 then return nil, t.error() end
  local ret = {count = ret, iovec = msg.msg_iov} -- thats the basic return value, and the iovec
  local mc, cmsg = cmsg_firsthdr(msg)
  while cmsg do
    if cmsg.cmsg_level == S.SOL_SOCKET then
      if cmsg.cmsg_type == S.SCM.CREDENTIALS then
        local cred = pt.ucred(cmsg + 1) -- cmsg_data
        ret.pid = cred.pid
        ret.uid = cred.uid
        ret.gid = cred.gid
      elseif cmsg.cmsg_type == S.SCM.RIGHTS then
        local fda = pt.int(cmsg + 1) -- cmsg_data
        local fdc = div(tonumber(cmsg.cmsg_len) - cmsg_ahdr, s.int)
        ret.fd = {}
        for i = 1, fdc do ret.fd[i] = t.fd(fda[i - 1]) end
      end -- add other SOL_SOCKET messages
    end -- add other processing for different types
    mc, cmsg = cmsg_nxthdr(msg, mc, cmsg)
  end
  return ret
end

-- helper functions
function S.sendcred(fd, pid, uid, gid) -- only needed for root to send incorrect credentials?
  if not pid then pid = C.getpid() end
  if not uid then uid = C.getuid() end
  if not gid then gid = C.getgid() end
  local ucred = t.ucred()
  ucred.pid = pid
  ucred.uid = uid
  ucred.gid = gid
  local buf1 = t.buffer(1) -- need to send one byte
  local io = t.iovecs{{buf1, 1}}
  local bufsize = cmsg_space(s.ucred)
  local buflen = cmsg_len(s.ucred)
  local buf = t.buffer(bufsize) -- this is our cmsg buffer
  local msg = t.msghdr() -- assume socket connected and so does not need address
  msg.msg_iov = io.iov
  msg.msg_iovlen = #io
  msg.msg_control = buf
  msg.msg_controllen = bufsize
  local mc, cmsg = cmsg_firsthdr(msg)
  cmsg.cmsg_level = S.SOL_SOCKET
  cmsg.cmsg_type = S.SCM.CREDENTIALS
  cmsg.cmsg_len = buflen
  ffi.copy(cmsg.cmsg_data, ucred, s.ucred)
  msg.msg_controllen = cmsg.cmsg_len -- set to sum of all controllens
  return S.sendmsg(fd, msg, 0)
end

function S.sendfds(fd, ...)
  local buf1 = t.buffer(1) -- need to send one byte
  local io = t.iovecs{{buf1, 1}}
  local fds = {}
  for i, v in ipairs{...} do fds[i] = getfd(v) end
  local fa = t.ints(#fds, fds)
  local fasize = ffi.sizeof(fa)
  local bufsize = cmsg_space(fasize)
  local buflen = cmsg_len(fasize)
  local buf = t.buffer(bufsize) -- this is our cmsg buffer
  local msg = t.msghdr() -- assume socket connected and so does not need address
  msg.msg_iov = io.iov
  msg.msg_iovlen = #io
  msg.msg_control = buf
  msg.msg_controllen = bufsize
  local mc, cmsg = cmsg_firsthdr(msg)
  cmsg.cmsg_level = S.SOL_SOCKET
  cmsg.cmsg_type = S.SCM.RIGHTS
  cmsg.cmsg_len = buflen -- could set from a constructor
  ffi.copy(cmsg + 1, fa, fasize) -- cmsg_data
  msg.msg_controllen = cmsg.cmsg_len -- set to sum of all controllens
  return S.sendmsg(fd, msg, 0)
end

function S.nonblock(fd)
  local fl, err = S.fcntl(fd, S.F.GETFL)
  if not fl then return nil, err end
  fl, err = S.fcntl(fd, S.F.SETFL, bit.bor(fl, S.O_NONBLOCK))
  if not fl then return nil, err end
  return true
end

function S.block(fd)
  local fl, err = S.fcntl(fd, S.F.GETFL)
  if not fl then return nil, err end
  fl, err = S.fcntl(fd, S.F.SETFL, bit.band(fl, bit.bnot(S.O_NONBLOCK)))
  if not fl then return nil, err end
  return true
end

-- TODO fix short reads, add a loop
function S.readfile(name, buffer, length) -- convenience for reading short files into strings, eg for /proc etc, silently ignores short reads
  local f, err = S.open(name, S.O_RDONLY)
  if not f then return nil, err end
  local r, err = f:read(buffer, length or 4096)
  if not r then return nil, err end
  local ok, err = f:close()
  if not ok then return nil, err end
  return r
end

function S.writefile(name, str, mode) -- write string to named file. specify mode if want to create file, silently ignore short writes
  local f, err
  if mode then f, err = S.creat(name, mode) else f, err = S.open(name, S.O_WRONLY) end
  if not f then return nil, err end
  local n, err = f:write(str)
  if not n then return nil, err end
  local ok, err = f:close()
  if not ok then return nil, err end
  return true
end

function S.dirfile(name, nodots) -- return the directory entries in a file, remove . and .. if nodots true
  local fd, d, ok, err
  fd, err = S.open(name, S.O_DIRECTORY + S.O_RDONLY)
  if err then return nil, err end
  d, err = fd:getdents()
  if err then return nil, err end
  if nodots then
    d["."] = nil
    d[".."] = nil
  end
  ok, err = fd:close()
  if not ok then return nil, err end
  return d
end

mt.ls = {
  __tostring = function(t)
    table.sort(t)
    return table.concat(t, "\n")
    end
}

function S.ls(name, nodots) -- return just the list, no other data, cwd if no directory specified
  if not name then name = S.getcwd() end
  local ds = S.dirfile(name, nodots)
  local l = {}
  for k, _ in pairs(ds) do l[#l + 1] = k end
  return setmetatable(l, mt.ls)
end

local function if_nametoindex(name, s) -- internal version when already have socket for ioctl
  local ifr = t.ifreq()
  local len = #name + 1
  if len > IFNAMSIZ then len = IFNAMSIZ end
  ffi.copy(ifr.ifr_ifrn.ifrn_name, name, len)
  local ret, err = S.ioctl(s, S.SIOCGIFINDEX, ifr)
  if not ret then return nil, err end
  return ifr.ifr_ifru.ifru_ivalue
end

function S.if_nametoindex(name) -- standard function in some libc versions
  local s, err = S.socket(S.AF.LOCAL, S.SOCK_STREAM, 0)
  if not s then return nil, err end
  local i, err = if_nametoindex(name, s)
  if not i then return nil, err end
  local ok, err = s:close()
  if not ok then return nil, err end
  return i
end

-- bridge functions, could be in utility library. in error cases use gc to close file.
local function bridge_ioctl(io, name)
  local s, err = S.socket(S.AF.LOCAL, S.SOCK_STREAM, 0)
  if not s then return nil, err end
  local ret, err = S.ioctl(s, io, pt.char(name))
  if not ret then return nil, err end
  local ok, err = s:close()
  if not ok then return nil, err end
  return true
end

function S.bridge_add(name) return bridge_ioctl(S.SIOCBRADDBR, name) end
function S.bridge_del(name) return bridge_ioctl(S.SIOCBRDELBR, name) end

local function bridge_if_ioctl(io, bridge, dev)
  local err, s, ifr, len, ret, ok
  s, err = S.socket(S.AF.LOCAL, S.SOCK_STREAM, 0)
  if not s then return nil, err end
  if type(dev) == "string" then
    dev, err = if_nametoindex(dev, s)
    if not dev then return nil, err end
  end
  ifr = t.ifreq()
  len = #bridge + 1
  if len > IFNAMSIZ then len = IFNAMSIZ end
  ffi.copy(ifr.ifr_ifrn.ifrn_name, bridge, len) -- note not using the short forms as no metatable defined yet...
  ifr.ifr_ifru.ifru_ivalue = dev
  ret, err = S.ioctl(s, io, ifr);
  if not ret then return nil, err end
  ok, err = s:close()
  if not ok then return nil, err end
  return true
end

function S.bridge_add_interface(bridge, dev) return bridge_if_ioctl(S.SIOCBRADDIF, bridge, dev) end
function S.bridge_add_interface(bridge, dev) return bridge_if_ioctl(S.SIOCBRDELIF, bridge, dev) end

-- should probably have constant for "/sys/class/net"

local function brinfo(d) -- can be used as subpart of general interface info
  local bd = "/sys/class/net/" .. d .. "/" .. S.SYSFS_BRIDGE_ATTR
  if not S.stat(bd) then return nil end
  local bridge = {}
  local fs = S.dirfile(bd, true)
  if not fs then return nil end
  for f, _ in pairs(fs) do
    local s = S.readfile(bd .. "/" .. f)
    if s then
      s = s:sub(1, #s - 1) -- remove newline at end
      if f == "group_addr" or f == "root_id" or f == "bridge_id" then -- string values
        bridge[f] = s
      elseif f == "stp_state" then -- bool
        bridge[f] = s == 1
      else
        bridge[f] = tonumber(s) -- not quite correct, most are timevals TODO
      end
    end
  end

  local brif, err = S.ls("/sys/class/net/" .. d .. "/" .. S.SYSFS_BRIDGE_PORT_SUBDIR, true)
  if not brif then return nil end

  local fdb = "/sys/class/net/" .. d .. "/" .. S.SYSFS_BRIDGE_FDB
  if not S.stat(fdb) then return nil end
  local sl = 2048
  local buffer = t.buffer(sl)
  local fd = S.open(fdb, S.O_RDONLY)
  if not fd then return nil end
  local brforward = {}

  repeat
    local n = fd:read(buffer, sl)
    if not n then return nil end

    local fdbs = pt.fdb_entry(buffer)

    for i = 1, n / s.fdb_entry do
      local fdb = fdbs[i - 1]
      local mac = t.macaddr()
      ffi.copy(mac, fdb.mac_addr, IFHWADDRLEN)

      -- TODO ageing_timer_value is not an int, time, float
      brforward[#brforward + 1] = {
        mac_addr = mac, port_no = tonumber(fdb.port_no),
        is_local = fdb.is_local ~= 0,
        ageing_timer_value = tonumber(fdb.ageing_timer_value)
      }
    end

  until n == 0
  if not fd:close() then return nil end

  return {bridge = bridge, brif = brif, brforward = brforward}
end

function S.bridge_list()
  local dir, err = S.dirfile("/sys/class/net", true)
  if not dir then return nil, err end
  local b = {}
  for d, _ in pairs(dir) do
    b[d] = brinfo(d)
  end
  return b
end

mt.proc = {
  __index = function(p, k)
    local name = p.dir .. k
    local st, err = S.lstat(name)
    if not st then return nil, err end
    if st.isreg then
      local fd, err = S.open(p.dir .. k, "rdonly")
      if not fd then return nil, err end
      local ret, err = fd:read() -- read defaults to 4k, sufficient?
      if not ret then return nil, err end
      fd:close()
      return ret -- TODO many could usefully do with some parsing
    end
    if st.islnk then
      local ret, err = S.readlink(name)
      if not ret then return nil, err end
      return ret
    end
    -- TODO directories
  end,
  __tostring = function(p) -- TODO decide what to print
    local c = p.cmdline
    if c then
      if #c == 0 then
        local comm = p.comm
        if comm and #comm > 0 then
          c = '[' .. comm:sub(1, -2) .. ']'
        end
      end
      return p.pid .. '  ' .. c
    end
  end
}

function S.proc(pid)
  if not pid then pid = S.getpid() end
  return setmetatable({pid = pid, dir = "/proc/" .. pid .. "/"}, mt.proc)
end

mt.ps = {
  __tostring = function(ps)
    local s = {}
    for i = 1, #ps do
      s[#s + 1] = tostring(ps[i])
    end
    return table.concat(s, '\n')
  end
}

function S.ps()
  local ls, err = S.ls("/proc")
  if not ls then return nil, err end
  local ps = {}
  for i = 1, #ls do
    if not string.match(ls[i], '[^%d]') then
      local p = S.proc(tonumber(ls[i]))
      if p then ps[#ps + 1] = p end
    end
  end
  table.sort(ps, function(a, b) return a.pid < b.pid end)
  return setmetatable(ps, mt.ps)
end

function S.mounts(file)
  local mf, err = S.readfile(file or "/proc/mounts")
  if not mf then return nil, err end
  local mounts = {}
  for line in mf:gmatch("[^\r\n]+") do
    local l = {}
    local parts = {"source", "target", "type", "flags", "freq", "passno"}
    local p = 1
    for word in line:gmatch("%S+") do
      l[parts[p]] = word
      p = p + 1
    end
    mounts[#mounts + 1] = l
  end
  -- TODO some of the options you get in /proc/mounts are file system specific and should be moved to l.data
  -- idea is you can round-trip this data
  -- a lot of the fs specific options are key=value so easier to recognise
  return mounts
end

-- these functions are all just ioctls can do natively
function S.cfmakeraw(termios)
  C.cfmakeraw(termios)
  return true
end

function S.cfgetispeed(termios)
  local bits = C.cfgetispeed(termios)
  if bits == -1 then return nil, t.error() end
  return bits_to_speed(bits)
end

function S.cfgetospeed(termios)
  local bits = C.cfgetospeed(termios)
  if bits == -1 then return nil, t.error() end
  return bits_to_speed(bits)
end

function S.cfsetispeed(termios, speed)
  return retbool(C.cfsetispeed(termios, speed_to_bits(speed)))
end

function S.cfsetospeed(termios, speed)
  return retbool(C.cfsetospeed(termios, speed_to_bits(speed)))
end

function S.cfsetspeed(termios, speed)
  return retbool(C.cfsetspeed(termios, speed_to_bits(speed)))
end

t.termios = ffi.metatype("struct termios", {
  __index = {
    cfmakeraw = S.cfmakeraw,
    cfgetispeed = S.cfgetispeed,
    cfgetospeed = S.cfgetospeed,
    cfsetispeed = S.cfsetispeed,
    cfsetospeed = S.cfsetospeed,
    cfsetspeed = S.cfsetspeed
  }
})

function S.tcgetattr(fd)
  local termios = t.termios()
  local ret = C.tcgetattr(getfd(fd), termios)
  if ret == -1 then return nil, t.error() end
  return termios
end

function S.isatty(fd)
  local tc = S.tcgetattr(fd)
  if tc then return true else return false end
end

function S.tcsetattr(fd, optional_actions, termios)
  return retbool(C.tcsetattr(getfd(fd), stringflag(optional_actions, "TCSA"), termios))
end

function S.tcsendbreak(fd, duration)
  return retbool(C.tcsendbreak(getfd(fd), duration))
end

function S.tcdrain(fd)
  return retbool(C.tcdrain(getfd(fd)))
end

function S.tcflush(fd, queue_selector)
  return retbool(C.tcflush(getfd(fd), stringflag(queue_selector, "TC")))
end

function S.tcflow(fd, action)
  return retbool(C.tcflow(getfd(fd), stringflag(action, "TC")))
end

function S.tcgetsid(fd)
  return retnum(C.tcgetsid(getfd(fd)))
end

function S.posix_openpt(flags)
  return S.open("/dev/ptmx", flags);
end

function S.grantpt(fd) -- I don't think we need to do anything here (eg Musl libc does not)
  return true
end

function S.unlockpt(fd)
  local unlock = t.int1()
  local ret, err = S.ioctl(fd, S.TIOCSPTLCK, pt.void(unlock)) -- TODO make sure this returns true instead?
  if not ret then return nil, err end
  return true
end

function S.ptsname(fd)
  local pts = t.int1()
  local ret, error = S.ioctl(fd, S.TIOCGPTN, pt.void(pts))
  if not ret then return nil, err end
  return "/dev/pts/" .. tostring(pts[0])
end

function S.vhangup() return retbool(C.vhangup()) end

-- Nixio compatibility to make porting easier, and useful functions (often man 3). Incomplete.
function S.setblocking(s, b) if b then return s:block() else return s:nonblock() end end
function S.tell(fd) return fd:lseek(0, S.SEEK.CUR) end

function S.lockf(fd, cmd, len)
  cmd = stringflag(cmd, "F_")
  if cmd == S.F_LOCK then
    return S.fcntl(fd, "setlkw", {l_type = S.FCNTL_LOCK.WRLCK, l_whence = S.SEEK.CUR, l_start = 0, l_len = len})
  elseif cmd == S.F_TLOCK then
    return S.fcntl(fd, "setlk", {l_type = S.FCNTL_LOCK.WRLCK, l_whence = S.SEEK.CUR, l_start = 0, l_len = len})
  elseif cmd == S.F_ULOCK then
    return S.fcntl(fd, "setlk", {l_type = S.FCNTL_LOCK.UNLCK, l_whence = S.SEEK.CUR, l_start = 0, l_len = len})
  elseif cmd == S.F_TEST then
    local ret, err = S.fcntl(fd, "getlk", {l_type = S.FCNTL_LOCK.WRLCK, l_whence = S.SEEK.CUR, l_start = 0, l_len = len})
    if not ret then return nil, err end
    return ret.l_type == S.FCNTL_LOCK.UNLCK
  end
end

-- constants
S.INADDR_ANY = t.in_addr()
S.INADDR_LOOPBACK = t.in_addr("127.0.0.1")
S.INADDR_BROADCAST = t.in_addr("255.255.255.255")
-- ipv6 versions
S.in6addr_any = t.in6_addr()
S.in6addr_loopback = t.in6_addr("::1")

-- methods on an fd
-- note could split, so a socket does not have methods only appropriate for a file
local fdmethods = {'nogc', 'nonblock', 'block', 'setblocking', 'sendfds', 'sendcred',
                   'close', 'dup', 'read', 'write', 'pread', 'pwrite', 'tell', 'lockf',
                   'lseek', 'fchdir', 'fsync', 'fdatasync', 'fstat', 'fcntl', 'fchmod',
                   'bind', 'listen', 'connect', 'accept', 'getsockname', 'getpeername',
                   'send', 'sendto', 'recv', 'recvfrom', 'readv', 'writev', 'sendmsg',
                   'recvmsg', 'setsockopt', 'epoll_ctl', 'epoll_wait', 'sendfile', 'getdents',
                   'eventfd_read', 'eventfd_write', 'ftruncate', 'shutdown', 'getsockopt',
                   'inotify_add_watch', 'inotify_rm_watch', 'inotify_read', 'flistxattr',
                   'fsetxattr', 'fgetxattr', 'fremovexattr', 'fxattr', 'splice', 'vmsplice', 'tee',
                   'signalfd_read', 'timerfd_gettime', 'timerfd_settime', 'timerfd_read',
                   'fadvise', 'fallocate', 'posix_fallocate', 'readahead',
                   'tcgetattr', 'tcsetattr', 'tcsendbreak', 'tcdrain', 'tcflush', 'tcflow', 'tcgetsid',
                   'grantpt', 'unlockpt', 'ptsname', 'sync_file_range', 'fstatfs', 'futimens',
                   'fstatat', 'unlinkat', 'mkdirat', 'mknodat', 'faccessat', 'fchmodat', 'fchown',
                   'fchownat', 'readlinkat', 'mkfifoat', 'isatty', 'setns', 'openat',
                   'preadv', 'pwritev'
                   }
local fmeth = {}
for _, v in ipairs(fdmethods) do fmeth[v] = S[v] end

-- allow calling without leading f
fmeth.stat = S.fstat
fmeth.chdir = S.fchdir
fmeth.sync = S.fsync
fmeth.datasync = S.fdatasync
fmeth.chmod = S.fchmod
fmeth.setxattr = S.fsetxattr
fmeth.getxattr = S.gsetxattr
fmeth.truncate = S.ftruncate
fmeth.statfs = S.fstatfs
fmeth.utimens = S.futimens
fmeth.utime = S.futimens
fmeth.seek = S.lseek
fmeth.lock = S.lockf
fmeth.chown = S.fchown

-- sequence number used by netlink messages
fmeth.seq = function(fd)
  fd.sequence = fd.sequence + 1
  return fd.sequence
end

fmeth.fileno = function(fd) return fd.filenum end

t.fd = ffi.metatype("struct {int filenum; int sequence;}", {
  __index = fmeth,
  __gc = S.close,
})

S.stdin = ffi.gc(t.fd(S.STDIN_FILENO), nil)
S.stdout = ffi.gc(t.fd(S.STDOUT_FILENO), nil)
S.stderr = ffi.gc(t.fd(S.STDERR_FILENO), nil)

t.aio_context = ffi.metatype("struct {aio_context_t ctx;}", {
  __index = {destroy = S.io_destroy, submit = S.io_submit, getevents = S.io_getevents, cancel = S.io_cancel},
  __gc = S.io_destroy
})

return S

end

return syscall()


