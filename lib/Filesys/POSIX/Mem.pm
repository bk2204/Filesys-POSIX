package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode ();

sub new {
    my ($class) = @_;
    my $fs = bless {}, $class;

    $fs->{'root'} = Filesys::POSIX::Mem::Inode->new(
        'mode' => $S_IFDIR | 0755,
        'dev'  => $fs
    );

    return $fs;
}

sub init {
    my ( $self, %flags ) = @_;

    $self->{'flags'} = \%flags;

    return $self;
}

1;
