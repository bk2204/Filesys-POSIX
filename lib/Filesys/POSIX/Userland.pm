package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub _find_inode_path {
    my ($self, $start) = @_;
    my $node = $self->_last($start);
    my @ret;

    while (my $dir = $node->{'parent'}) {
        last if $dir eq $node;

        die('Not a directory') unless $dir->{'mode'} & $S_IFDIR;

        dirent: foreach ($dir->{'dirent'}->list) {
            next if $_ eq '.' || $_ eq '..';
            next dirent unless $dir->{'dirent'}->get($_) == $node;

            push @ret, $_;
            $node = $self->_last($dir);
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
    my ($self, $fs, $path, %flags) = @_;
    my $mountpoint = $self->stat($path);
    my $realpath = $self->_find_inode_path($mountpoint);

    $fs->init(%flags);

    $self->{'vfs'}->mount($fs, $realpath, $mountpoint, %flags);
}

sub unmount {
    my ($self, $path) = @_;
    my $mountpoint = $self->stat($path);

    $self->{'vfs'}->unmount($mountpoint);
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

sub mountpoints {
    my ($self) = @_;

    return sort {
        $a cmp $b
    } map {
        $self->_find_inode_path($_)
    } $self->{'vfs'}->mountpoints;
}

1;
