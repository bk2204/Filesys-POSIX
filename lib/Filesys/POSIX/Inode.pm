package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Carp;

sub dir {
    (shift->{'mode'} & $S_IFMT) == $S_IFDIR;
}

sub link {
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

sub perms {
    shift->{'mode'} & $S_IPERM;
}

sub readable {
    (shift->{'mode'} & $S_IR) != 0;
}

sub writable {
    (shift->{'mode'} & $S_IW) != 0;
}

sub executable {
    (shift->{'mode'} & $S_IX) != 0;
}

sub setuid {
    (shift->{'mode'} & $S_ISUID) != 0;
}

sub setgid {
    (shift->{'mode'} & $S_ISGID) != 0;
}

sub update {
    my ($self, @st) = @_;

    @{$self}{qw/size atime mtime ctime uid gid mode rdev/} = (@st[7..10], @st[4..5], $st[2], $st[6]);
}

sub dirent {
    my ($self) = @_;
    confess('Not a directory') unless $self->dir;

    return $self->{'dirent'};
}

sub empty {
    my ($self) = @_;
    my $dirent = $self->dirent;

    return $dirent->count == 2 && $dirent->get('.') && $dirent->get('..');
}

1;
