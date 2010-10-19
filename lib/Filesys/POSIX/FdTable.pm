package Filesys::POSIX::FdTable;

use strict;
use warnings;

sub new {
    return bless {}, shift;
}

sub open {
    my ($self, $inode, $flags) = @_;
    my $fd = 3;

    my $handle = $inode->open($flags) or die('Unable to open device-specific file handle');

    foreach (sort { $a <=> $b } keys %$self) {
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
    my $entry = $self->{$fd} or die('Invalid file descriptor');

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
