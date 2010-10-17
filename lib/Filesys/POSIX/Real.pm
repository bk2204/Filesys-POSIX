package Filesys::POSIX::Real;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

sub new {
    return bless {}, shift;
}

sub init {
    my ($self, %flags) = @_;

    $self->{'path'} = $flags{'path'};
    $self->{'root'} = Filesys::POSIX::Real::Inode->new($flags{'path'},
        'dev' => $self
    );

    return $self;
}

1;
