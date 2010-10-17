package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode;

sub new {
    return bless {}, shift;
}

sub init {
    my ($self) = @_;

    $self->{'root'} = Filesys::POSIX::Mem::Inode->new(
        'mode'  => $S_IFDIR | 0755,
        'dev'   => $self
    );

    return $self;
}

1;
