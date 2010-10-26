package Filesys::POSIX::Extensions;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

use Carp;

sub EXPORT {
    qw/attach map alias detach replace/;
}

sub attach {
    my ($self, $inode, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    confess('File exists') unless $parent->{'dirent'}->get($name);
    confess('Not a directory') unless $parent->dir;

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
    confess('Not a directory') unless $parent->dir;

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

    confess('File exists') if $parent->{'dirent'}->exists($name);
    confess('Not a directory') unless $parent->dir;

    $parent->{'dirent'}->set($name, $inode);
}

sub detach {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    die('Not a directory') unless $parent->dir;
    die('No such file or directory') unless $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->unlink($name);
}

sub replace {
    my ($self, $path, $inode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    die('Not a directory') unless $parent->dir;
    die('No such file or directory') unless $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->unlink($name);
    $parent->{'dirent'}->set($name, $inode);
}

1;
