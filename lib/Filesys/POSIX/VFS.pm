package Filesys::POSIX::VFS;

use strict;
use warnings;

use Filesys::POSIX::Path;

sub new {
    return bless {}, shift;
}

sub _resolve_mountpoint {
    my ($self, $node) = @_;

    die('Not an inode') unless ref $node eq 'Filesys::POSIX::Inode';

    #
    # Is the current inode's filesystem's root inode a mount point?
    #
    return $node->{'dev'}->{'root'} if exists $self->{$node->{'dev'}->{'root'}};

    #
    # Is the current inode a mount point?
    #
    return $node if exists $self->{$node};

    #
    # Is the current inode's device currently mounted?
    #
    foreach (keys %$self) {
        next unless $self->{$_}->{'dev'} eq $node->{'dev'};

        return $_;
    }

    die('Not mounted');
}

sub statfs {
    my ($self, $node) = @_;
    my $mountpoint = $self->_resolve_mountpoint($node);

    return $self->{$mountpoint};
}

sub mountpoints {
    my ($self) = @_;

    return map {
        $self->{$_}->{'node'}
    } keys %$self;
}

#
# It should be noted that any usage of pathnames in this module are entirely
# symbolic and are not used for canonical purposes.  The higher-level
# filesystem layer should take on the responsibility of providing both the
# canonically-correct absolute pathnames for mount points, and helping locate
# the appropriate VFS mount point for querying purposes.
#
sub mount {
    my ($self, $fs, $path, $mountpoint, %opts) = @_;

    #
    # Does the mount point passed already have a filesystem mounted?
    #
    die('Already mounted') if exists $self->{$mountpoint};

    #
    # Is the filesystem passed currently mounted?
    #
    foreach (keys %$self) {
        die('Already mounted') if $self->{$_}->{'dev'} == $fs;
    }

    $self->{$mountpoint} = {
        'flags' => \%opts,
        'node'  => $mountpoint,
        'dev'   => $fs,
        'path'  => $path
    };

    return $self;
}

sub unmount {
    my ($self, $node) = @_;
    my $mountpoint = $self->_resolve_mountpoint($node);

    delete $self->{$mountpoint};
    return $self;
}

1;
