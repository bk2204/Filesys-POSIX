package Filesys::POSIX::Mem::Dirent;

use strict;
use warnings;

sub new {
    my ($class, %initial) = @_;
    return bless \%initial, $class;
}

sub get {
    my ($self, $name) = @_;
    return $self->{$name};
}

sub set {
    my ($self, $name, $node) = @_;
    $self->{$name} = $node;
}

sub exists {
    my ($self, $name) = @_;
    return exists $self->{$name};
}

sub delete {
    my ($self, $name) = @_;
    delete $self->{$name};
}

sub list {
    my ($self) = @_;
    return keys %$self;
}

sub count {
    my ($self) = @_;
    return scalar keys %$self;
}

sub rewind {
    my ($self) = @_;

    keys %$self;
}

sub read {
    my ($self) = @_;

    each %$self;
}

sub close {
    return;
}

1;
