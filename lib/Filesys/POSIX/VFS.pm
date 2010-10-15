package Filesys::POSIX::VFS;

use strict;
use warnings;

use Filesys::POSIX::Path;

sub new {
    return bless {}, shift;
}

sub _resolve_mountpoint {
    my ($self, $node) = @_;

    if (ref $node eq 'Filesys::POSIX::Inode') {
        return $node if $self->{$node};
    } elsif (ref $node eq 'Filesys::POSIX::Mem') {
        foreach (keys %$self) {
            return $_ if $self->{$_}->{'dev'} == $node;
        }
    } else {
        die('Node passed not an inode mountpoint or filesystem reference');
    }

    die('Not currently mounted');
}

sub statfs {
    my ($self, $mountpoint) = @_;

    die('Not an inode') unless ref $mountpoint eq 'Filesys::POSIX::Inode';
    die('Not mounted') unless $self->{$mountpoint};

    return $self->{$mountpoint};
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

    foreach ($fs, $mountpoint) {
        eval {
            $self->_resolve_mountpoint($_);
        };

        die('Already mounted') unless $@;
    }

    $self->{$mountpoint} = {
        %opts,
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
