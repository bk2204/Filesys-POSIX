package Filesys::POSIX::VFS;

use strict;
use warnings;

use Filesys::POSIX::Path;

sub new {
    return bless [], shift;
}

sub statfs {
    my ($self, $node, %opts) = @_;

    unless ($opts{'exact'}) {
        $node = $node->{'dev'}->{'root'};
    }

    unless ($node) {
        die('No node');
    }

    foreach my $mount (@$self) {
        foreach (qw/mountpoint root vnode/) {
            return $mount if $mount->{$_} eq $node;
        }
    }

    die('Not mounted') unless $opts{'silent'};

    return undef;
}

sub mountpoints {
    my ($self) = @_;

    return map {
        $_->{'mountpoint'}
    } @$self;
}

#
# It should be noted that any usage of pathnames in this module are entirely
# symbolic and are not used for canonical purposes.  The higher-level
# filesystem layer should take on the responsibility of providing both the
# canonically-correct absolute pathnames for mount points, and helping locate
# the appropriate VFS mount point for querying purposes.
#
sub mount {
    my ($self, $fs, $path, $mountpoint, %data) = @_;

    if ($self->statfs($mountpoint, 'exact' => 1, 'silent' => 1) || grep { $_->{'dev'} eq $fs } @$self ) {
        die('Already mounted');
    }

    $data{'special'} ||= scalar $fs;

    #
    # Build the vnode from the data provided in the root inode; however,
    # we do want to retain the mountpoint's parent reference within the
    # vnode itself.
    #
    my $vnode = bless {
        %{$fs->{'root'}}
    }, ref $fs->{'root'};

    $vnode->{'parent'} = $mountpoint->{'parent'};

    push @$self, {
        'mountpoint'    => $mountpoint,
        'root'          => $fs->{'root'},
        'vnode'         => $vnode,
        'special'       => $data{'special'},
        'dev'           => $fs,
        'path'          => $path,

        'flags'         => {
            map {
                $_ => $data{$_}
            } grep {
                $_ ne 'special'
            } keys %data
        }
    };

    return $self;
}

sub vnode {
    my ($self, $inode) = @_;

    return undef unless $inode;

    if (my $mount = $self->statfs($inode, 'exact' => 1, 'silent' => 1)) {
        return $mount->{'vnode'};
    }

    return $inode;
}

sub unmount {
    my ($self, $node) = @_;
    my $mount = $self->statfs($node, 'exact' => 1);

    #
    # First, check to see that the filesystem mount record found is a
    # dependency for another mounted filesystem.
    #
    foreach (@$self) {
        next if $_ == $mount;
        die('Device or resource busy') if $_->{'mountpoint'}->{'dev'} == $mount->{'dev'};
    }

    for (my $i=0; $self->[$i]; $i++) {
        next unless $self->[$i] eq $mount;
        splice @$self, $i;
        last;
    }

    return $self;
}

1;
