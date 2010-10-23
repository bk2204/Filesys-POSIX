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
    my %opts = ref $_[0] eq 'HASH'? %{(shift)}: ();
    my $callback = shift;
    my @args = @_;

    my @paths = map { Filesys::POSIX::Path->new($_) } @args;
    my @nodes = map { $self->stat($_) } @args;

    while (my $inode = pop @nodes) {
        my $path = pop @paths;

        if (($inode->{'mode'} & $S_IFMT) == $S_IFLNK) {
            $inode = $self->stat($inode->readlink) if $opts{'follow'};
        }

        $callback->($path, $inode);

        if (($inode->{'mode'} & $S_IFMT) == $S_IFDIR) {
            my $dirent = $inode->{'dirent'};

            $dirent->open;

            while (my $item = $dirent->read) {
                next if $item eq '.' || $item eq '..';
                push @paths, Filesys::POSIX::Path->new($path->full . "/$item");
                push @nodes, $self->{'vfs'}->vnode($dirent->get($item));
            }

            $dirent->close;
        }
    }
}

1;
