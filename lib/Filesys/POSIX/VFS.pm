package Filesys::POSIX::VFS;

use strict;
use warnings;

use Filesys::POSIX::Path;

sub new {
    return bless {}, shift;
}

sub _resolve_mountpoint {
    my ($self, $node) = @_;

    return $node if $self->{$node};

    foreach (keys %$self) {
        next unless $self->{$_}->{'dev'} eq $node;
        return $_;
        last;
    }

    die('Not currently mounted');
}

sub statfs {
    my ($self, $node) = @_;
    my $mountpoint = $self->_resolve_mountpoint;

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
