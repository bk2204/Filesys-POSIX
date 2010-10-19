package Filesys::POSIX::Real;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

sub new {
    return bless {}, shift;
}

sub init {
    my ($self, %data) = @_;

    my $path = $data{'special'};
    $path =~ s/^real:// or die('Invalid special path');

    $self->{'flags'} = \%data;
    $self->{'path'} = Filesys::POSIX::Path->full($path);
    $self->{'root'} = Filesys::POSIX::Real::Inode->new($path,
        'dev' => $self
    );

    return $self;
}

1;
