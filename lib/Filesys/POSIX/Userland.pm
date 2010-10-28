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

        my $dirent = $dir->dirent;

        dirent: foreach ($dirent->list) {
            next if $_ eq '.' || $_ eq '..';
            next dirent unless $self->{'vfs'}->vnode($dirent->get($_)) == $self->{'vfs'}->vnode($inode);

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

    while ($hier->count) {
        my $item = $hier->shift;

        unless ($item) {
            $dir = $self->{'root'};
            next;
        }

        my $dirent = $dir->dirent;
        my $inode = $self->{'vfs'}->vnode($dirent->get($item));

        if ($inode) {
            $dir = $inode;
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

sub opendir {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);

    my $dirent = $self->stat($path)->dirent;
    $dirent->open;

    return $dirent;
}

sub readdir {
    my ($self, $dirent) = @_;

    return $dirent->read unless wantarray;

    my @ret;

    while (my $item = $dirent->read) {
        push @ret, $item;
    }

    return @ret;
}

sub closedir {
    my ($self, $dirent) = @_;
    return $dirent->close;
}

sub touch {
    my ($self, $path) = @_;
    my $fd = $self->open($path, $O_CREAT | $O_WRONLY);

    $self->close($fd);
}

1;
