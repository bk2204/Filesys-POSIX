package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub dir {
    (shift->{'mode'} & $S_IFMT) == $S_IFDIR;
}

sub symlink {
    (shift->{'mode'} & $S_IFMT) == $S_IFLNK;
}

sub file {
    (shift->{'mode'} & $S_IFMT) == $S_IFREG;
}

sub char {
    (shift->{'mode'} & $S_IFMT) == $S_IFCHR;
}

sub block {
    (shift->{'mode'} & $S_IFMT) == $S_IFBLK;
}

sub fifo {
    (shift->{'mode'} & $S_IFMT) == $S_IFIFO;
}

sub update {
    my ($self, @st) = @_;

    @{$self}{qw/size atime mtime ctime uid gid mode rdev/} = (@st[7..10], @st[4..5], $st[2], $st[6]);
}

1;
