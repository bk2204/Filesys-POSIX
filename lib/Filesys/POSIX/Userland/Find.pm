package Filesys::POSIX::Userland::Find;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;

use strict;
use warnings;

sub EXPORT {
    qw/find/;
}

sub find {
    my $self = shift;
    my $callback = shift;
    my %opts = ref $_[0] eq 'HASH'? %{(shift)}: ();
    my @args = @_;

    my @paths = map { Filesys::POSIX::Path->new($_) } @args;
    my @inodes = map { $self->stat($_) } @args;

    while (my $inode = pop @inodes) {
        my $path = pop @paths;

        if ($inode->link) {
            $inode = $self->stat($inode->readlink) if $opts{'follow'};
        }

        $callback->($path, $inode);

        if ($inode->dir) {
            my $dirent = $inode->{'dirent'};

            $dirent->open;

            while (my $item = $dirent->read) {
                next if $item eq '.' || $item eq '..';
                push @paths, Filesys::POSIX::Path->new($path->full . "/$item");
                push @inodes, $self->{'vfs'}->vnode($dirent->get($item));
            }

            $dirent->close;
        }
    }
}

1;
