package Filesys::POSIX::Bits;

use strict;
use warnings;

BEGIN {
    use Exporter ();
    use vars qw/@ISA @EXPORT/;

    @ISA    = qw/Exporter/;

    @EXPORT = qw(
        $O_RDONLY $O_WRONLY $O_RDWR $O_NONBLOCK $O_APPEND $O_CREAT $O_TRUNC
        $O_EXCL $O_SHLOCK $O_EXLOCK $O_NOFOLLOW $O_SYMLINK $O_EVTONLY $S_IFMT
        $S_IFIFO $S_IFCHR $S_IFDIR $S_IFBLK $S_IFREG $S_IFLNK $S_IFSOCK
        $S_IFWHT $S_IPROT $S_ISUID $S_ISGID $S_ISVTX $S_IPERM $S_IRWXU
        $S_IRUSR $S_IWUSR $S_IXUSR $S_IRWXG $S_IRGRP $S_IWGRP $S_IXGRP
        $S_IRWXO $S_IROTH $S_IWOTH $S_IXOTH
    );
}

#
# Flags as recognized by open()
#
my $O_RDONLY   = 0x0001;
my $O_WRONLY   = 0x0002;
my $O_RDWR     = 0x0004;
my $O_NONBLOCK = 0x0008;
my $O_APPEND   = 0x0010;
my $O_CREAT    = 0x0020;
my $O_TRUNC    = 0x0040;
my $O_EXCL     = 0x0080;
my $O_SHLOCK   = 0x0100;
my $O_EXLOCK   = 0x0200;
my $O_NOFOLLOW = 0x0400;
my $O_SYMLINK  = 0x0800;
my $O_EVTONLY  = 0x1000;

#
# Inode format bitfield and values
#
my $S_IFMT     = 0170000;

my $S_IFIFO    = 0010000;
my $S_IFCHR    = 0020000;
my $S_IFDIR    = 0040000;
my $S_IFBLK    = 0060000;
my $S_IFREG    = 0100000;
my $S_IFLNK    = 0120000;
my $S_IFSOCK   = 0140000;
my $S_IFWHT    = 0160000;

#
# Inode execution protection bitfield and values
#
my $S_IPROT    = 0007000;

my $S_ISUID    = 0004000;
my $S_ISGID    = 0002000;
my $S_ISVTX    = 0001000;

#
# Inode permission bitfield and values
#
my $S_IPERM    = 0000777;

# Per assigned user
my $S_IRWXU    = 0000700;

my $S_IRUSR    = 0000400;
my $S_IWUSR    = 0000200;
my $S_IXUSR    = 0000100;

# Per assigned group
my $S_IRWXG    = 0000070;

my $S_IRGRP    = 0000040;
my $S_IWGRP    = 0000020;
my $S_IXGRP    = 0000010;

# All other users
my $S_IRWXO    = 0000007;

my $S_IROTH    = 0000004;
my $S_IWOTH    = 0000002;
my $S_IXOTH    = 0000001;

1;
