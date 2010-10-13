use strict;
use warnings;

#
# Flags as recognized by open()
#
our $O_RDONLY   = 0x0001;
our $O_WRONLY   = 0x0002;
our $O_RDWR     = 0x0004;
our $O_NONBLOCK = 0x0008;
our $O_APPEND   = 0x0010;
our $O_CREAT    = 0x0020;
our $O_TRUNC    = 0x0040;
our $O_EXCL     = 0x0080;
our $O_SHLOCK   = 0x0100;
our $O_EXLOCK   = 0x0200;
our $O_NOFOLLOW = 0x0400;
our $O_SYMLINK  = 0x0800;
our $O_EVTONLY  = 0x1000;

#
# Inode format bitfield and values
#
our $S_IFMT     = 0170000;

our $S_IFIFO    = 0010000;
our $S_IFCHR    = 0020000;
our $S_IFDIR    = 0040000;
our $S_IFBLK    = 0060000;
our $S_IFREG    = 0100000;
our $S_IFLNK    = 0120000;
our $S_IFSOCK   = 0140000;
our $S_IFWHT    = 0160000;

#
# Inode execution protection bitfield and values
#
our $S_IPROT    = 0007000;

our $S_ISUID    = 0004000;
our $S_ISGID    = 0002000;
our $S_ISVTX    = 0001000;

#
# Inode permission bitfield and values
#
our $S_IPERM    = 0000777;

# Per assigned user
our $S_IRWXU    = 0000700;

our $S_IRUSR    = 0000400;
our $S_IWUSR    = 0000200;
our $S_IXUSR    = 0000100;

# Per assigned group
our $S_IRWXG    = 0000070;

our $S_IRGRP    = 0000040;
our $S_IWGRP    = 0000020;
our $S_IXGRP    = 0000010;

# All other users
our $S_IRWXO    = 0000007;

our $S_IROTH    = 0000004;
our $S_IWOTH    = 0000002;
our $S_IXOTH    = 0000001;

1;
