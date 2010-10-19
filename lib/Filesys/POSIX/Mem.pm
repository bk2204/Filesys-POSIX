package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode;
use Filesys::POSIX::Mem::Dirent;

sub new {
    my ($class) = @_;
    my $fs = bless {}, $class;

    $fs->{'root'} = Filesys::POSIX::Mem::Inode->new(
        'mode'  => $S_IFDIR | 0755,
        'dev'   => $fs
    );

    return $fs;
}

sub init {
    my ($self, %data) = @_;

    $self->{'flags'} = \%data;

    return $self;
}

1;
