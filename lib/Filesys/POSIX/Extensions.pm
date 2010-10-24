package Filesys::POSIX::Extensions;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

use Carp;

sub EXPORT {
    qw/attach map alias/;
}

sub attach {
    my ($self, $inode, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    eval {
        $self->stat($dest);
    };

    confess('File exists') unless $@;
    confess('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

    $parent->{'dirent'}->set($name, $inode);
}

sub map {
    my ($self, $real_src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    eval {
        $self->stat($dest);
    };

    confess('File exists') unless $@;
    confess('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

    my $inode = Filesys::POSIX::Real::Inode->new($real_src,
        'dev'       => $parent->{'dev'},
        'parent'    => $parent
    );

    $parent->{'dirent'}->set($name, $inode);
}

sub alias {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $inode = $self->stat($src);
    my $parent = $self->stat($hier->dirname);

    eval {
        $self->stat($dest);
    };

    confess('File exists') unless $@;
    confess('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

    $parent->{'dirent'}->set($name, $inode);
}

1;
