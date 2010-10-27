package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;

use Carp;

sub mount {
    my ($self, $fs, $path, %data) = @_;
    my $mountpoint = $self->stat($path);
    my $realpath = $self->_find_inode_path($mountpoint);

    $fs->init(%data);

    $self->{'vfs'}->mount($fs, $realpath, $mountpoint, %data);
}

sub unmount {
    my ($self, $path) = @_;
    my $mountpoint = $self->stat($path);
    my $mount = $self->{'vfs'}->statfs($mountpoint, 'exact' => 1);

    #
    # First, check for open file descriptors held on the desired device.
    #
    foreach ($self->{'fds'}->list) {
        my $inode = $self->{'fds'}->fetch($_);

        confess('Device or resource busy') if $mount->{'dev'} eq $inode->{'dev'};
    }

    #
    # Next, check to see if the current working directory's device inode
    # is the same device as the one being requested for unmounting.
    #
    confess('Device or resource busy') if $mount->{'dev'} eq $self->{'cwd'}->{'dev'};

    $self->{'vfs'}->unmount($mount);
}

sub statfs {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);

    return $self->{'vfs'}->statfs($inode);
}

sub fstatfs {
    my ($self, $fd) = @_;
    my $inode = $self->fstat($fd);

    return $self->{'vfs'}->statfs($inode);
}

sub mountlist {
    shift->{'vfs'}->mountlist;
}

1;
