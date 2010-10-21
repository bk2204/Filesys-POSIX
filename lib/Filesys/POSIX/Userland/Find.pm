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

    while (my $path = pop @paths) {
        my $method = $opts{'follow'}? 'stat': 'lstat';
        my $node = $self->$method($path->full);

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
