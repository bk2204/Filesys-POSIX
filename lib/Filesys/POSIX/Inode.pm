package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub dir {
    my ($self) = @_;
    return ($self->{'mode'} & $S_IFMT) == $S_IFDIR;
}

1;
