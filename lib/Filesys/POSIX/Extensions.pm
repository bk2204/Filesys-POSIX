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
    my $dirent = $parent->dirent;

    confess('File exists') if $dirent->exists($name);

    $dirent->set($name, $inode);
}

sub map {
    my ($self, $real_src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);
    my $dirent = $parent->dirent;

    eval {
        $self->stat($dest);
    };

    confess('File exists') unless $@;

    my $inode = Filesys::POSIX::Real::Inode->new($real_src,
        'dev'       => $parent->{'dev'},
        'parent'    => $parent
    );

    $dirent->set($name, $inode);
}

sub alias {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $inode = $self->stat($src);
    my $parent = $self->stat($hier->dirname);
    my $dirent = $parent->dirent;

    confess('File exists') if $dirent->exists($name);

    $dirent->set($name, $inode);
}

sub detach {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);
    my $dirent = $parent->dirent;

    confess('No such file or directory') unless $dirent->exists($name);

    $dirent->unlink($name);
}

sub replace {
    my ($self, $path, $inode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);
    my $dirent = $parent->dirent;

    confess('No such file or directory') unless $dirent->exists($name);

    $dirent->unlink($name);
    $dirent->set($name, $inode);
}

1;
