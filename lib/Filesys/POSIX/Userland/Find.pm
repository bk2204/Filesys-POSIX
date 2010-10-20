package Filesys::POSIX::Userland::Find;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;

use strict;
use warnings;

sub EXPORT {
    qw/find/;
}

sub find {
    my ($self, $callback, @args) = @_;
    my %opts;

    if (ref $args[0] eq 'HASH') {
        %opts = %{shift @args};
    }

    my @paths = map { Filesys::POSIX::Path->new($_) } @args;

    while (my $path = pop @paths) {
        my $node = $self->lstat($path->full);

        $callback->($path, $node);

        if (($node->{'mode'} & $S_IFMT) == $S_IFDIR) {
            push @paths, map {
                Filesys::POSIX::Path->new($path->full . "/$_")
            } grep {
                $_ ne '.' && $_ ne '..'
            } $node->{'dirent'}->list;
        }
    }
}

1;
