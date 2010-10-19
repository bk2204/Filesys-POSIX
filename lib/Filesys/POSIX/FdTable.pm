package Filesys::POSIX::FdTable;

use strict;
use warnings;

sub new {
    return bless {}, shift;
}

sub alloc {
    my ($self, $inode) = @_;
    my $fd = 3;

    foreach (sort { $a <=> $b } keys %$self) {
        next if $self->{$fd = $_ + 1};
        last;
    }

    $self->{$fd} = $inode;

    return $fd;
}

sub lookup {
    my ($self, $fd) = @_;
    my $inode = $self->{$fd} or die('Invalid file descriptor');

    return $inode;
}

sub free {
    my ($self, $fd) = @_;
    delete $self->{$fd};
}

sub list {
    my ($self) = @_;
    return keys %$self;
}

1;
