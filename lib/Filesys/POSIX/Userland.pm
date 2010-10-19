package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub _find_inode_path {
    my ($self, $start) = @_;
    my $node = $self->{'vfs'}->vnode($start);
    my @ret;

    while (my $dir = $self->{'vfs'}->vnode($node->{'parent'})) {
        last if $dir eq $node;

        die('Not a directory') unless $dir->{'mode'} & $S_IFDIR;

        dirent: foreach ($dir->{'dirent'}->list) {
            next if $_ eq '.' || $_ eq '..';
            next dirent unless $self->{'vfs'}->vnode($dir->{'dirent'}->get($_)) == $self->{'vfs'}->vnode($node);

            push @ret, $_;
            $node = $dir;
        }
    }

    return '/' . join('/', reverse @ret);
}

sub getcwd {
    my ($self) = @_;

    return $self->_find_inode_path($self->{'cwd'});
}

sub realpath {
    my ($self, $path) = @_;
    my $node = $self->stat($path);

    return $self->_find_inode_path($node);
}

sub mount {
    my ($self, $fs, $path, %data) = @_;
    my $mountpoint = $self->stat($path);
    my $realpath = $self->_find_inode_path($mountpoint);

    $fs->init(%data);

    $self->{'vfs'}->mount($fs, $realpath, $mountpoint, %data);
}

sub unmount {
    my ($self, $path) = @_;
    my $mount = $self->statfs($path);

    #
    # First, check for open file descriptors held on the desired device.
    #
    foreach ($self->{'fds'}->list) {
        my $node = $self->{'fds'}->fetch($_);

        die('Device or resource busy') if $mount->{'dev'} eq $node->{'dev'};
    }

    #
    # Next, check to see if the current working directory's device inode
    # is the same device as the one being requested for unmounting.
    #
    die('Device or resource busy') if $mount->{'dev'} eq $self->{'cwd'}->{'dev'};

    $self->{'vfs'}->unmount($mount);
}

sub statfs {
    my ($self, $path) = @_;
    my $node = $self->stat($path);

    return $self->{'vfs'}->statfs($node);
}

sub fstatfs {
    my ($self, $fd) = @_;
    my $node = $self->fstat($fd);

    return $self->{'vfs'}->statfs($node);
}

sub mountlist {
    shift->{'vfs'}->mountlist;
}

1;
