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
    my ($self, %opts) = @_;

    $self->{'path'} = $opts{'path'};
    $self->{'root'} = Filesys::POSIX::Real::Inode->new($opts{'path'},
        'dev' => $self
    );

    return $self;
}

1;
