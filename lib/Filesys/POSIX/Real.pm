package Filesys::POSIX::Real;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

use Carp;

sub new {
    return bless {}, shift;
}

sub init {
    my ($self, %data) = @_;

    my $path = $data{'special'};
    $path =~ s/^real:// or confess('Invalid special path');

    $self->{'flags'} = \%data;
    $self->{'path'} = Filesys::POSIX::Path->full($path);
    $self->{'root'} = Filesys::POSIX::Real::Inode->new($path,
        'dev' => $self
    );

    return $self;
}

1;
