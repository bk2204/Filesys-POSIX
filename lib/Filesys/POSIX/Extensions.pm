package Filesys::POSIX::Extensions;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

sub EXPORT {
    qw/attach map alias/;
}

sub attach {
    my ($self, $node, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    eval {
        $self->stat($dest);
    };

    die('File exists') unless $@;
    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

    $parent->{'dirent'}->set($name, $node);
}

sub map {
    my ($self, $real_src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    eval {
        $self->stat($dest);
    };

    die('File exists') unless $@;
    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

    my $node = Filesys::POSIX::Real::Inode->new($real_src,
        'dev'       => $parent->{'dev'},
        'parent'    => $parent
    );

    $parent->{'dirent'}->set($name, $node);
}

sub alias {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $node = $self->stat($src);
    my $parent = $self->stat($hier->dirname);

    eval {
        $self->stat($dest);
    };

    die('File exists') unless $@;
    die('Device or resource busy') if $self->stat($dest) eq $parent;
    die('Is a directory') if ($node->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

    $parent->{'dirent'}->set($name, $node);
}

1;
