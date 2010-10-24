package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;

use Carp;

sub _find_inode_path {
    my ($self, $start) = @_;
    my $inode = $self->{'vfs'}->vnode($start);
    my @ret;

    while (my $dir = $self->{'vfs'}->vnode($inode->{'parent'})) {
        last if $dir eq $inode;

        confess('Not a directory') unless ($dir->{'mode'} & $S_IFMT) == $S_IFDIR;

        dirent: foreach ($dir->{'dirent'}->list) {
            next if $_ eq '.' || $_ eq '..';
            next dirent unless $self->{'vfs'}->vnode($dir->{'dirent'}->get($_)) == $self->{'vfs'}->vnode($inode);

            push @ret, $_;
            $inode = $dir;
        }
    }

    return '/' . join('/', reverse @ret);
}

sub mkpath {
    my ($self, $path, $mode) = @_;
    my $perm = $mode? $mode & ($S_IPERM | $S_IPROT): $S_IPERM ^ $self->{'umask'};
    my $hier = Filesys::POSIX::Path->new($path);
    my $dir = $self->{'cwd'};

    while (my $item = $hier->shift) {
        unless ($item) {
            $dir = $self->{'root'};
        }

        my $node = $self->{'vfs'}->vnode($dir->{'dirent'}->get($item));

        if ($node) {
            die('Not a directory') unless ($node->{'mode'} & $S_IFMT) == $S_IFDIR;
            $dir = $node;
        } else {
            $dir = $dir->child($item, $perm | $S_IFDIR);
        }
    }
}

sub getcwd {
    my ($self) = @_;

    return $self->_find_inode_path($self->{'cwd'});
}

sub realpath {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);

    return $self->_find_inode_path($inode);
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
