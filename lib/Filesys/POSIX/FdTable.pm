package Filesys::POSIX::FdTable;

use strict;
use warnings;

use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::FdTable

=head1 DESCRIPTION

This internal module used by Filesys::POSIX handles the allocation and tracking
of numeric file descriptors associated with inodes opened for I/O.  It does not
intend to expose any public interfaces.

=cut

sub new {
    return bless {}, shift;
}

sub open {
    my ($self, $inode, $flags) = @_;
    my $fd = 2;

    my $handle = $inode->open($flags) or confess('Unable to open device-specific file handle');

    foreach (sort { $a <=> $b } ($fd, keys %$self)) {
        next if $self->{$fd = $_ + 1};
        last;
    }

    $self->{$fd} = {
        'inode'     => $inode,
        'handle'    => $handle,
        'flags'     => $flags
    };

    return $fd;
}

sub lookup {
    my ($self, $fd) = @_;
    my $entry = $self->{$fd} or confess('Invalid file descriptor');

    return $entry;
}

sub close {
    my ($self, $fd) = @_;
    my $entry = $self->{$fd} or return;

    $entry->{'handle'}->close;

    delete $self->{$fd};
}

sub list {
    my ($self) = @_;

    return keys %$self;
}

1;
