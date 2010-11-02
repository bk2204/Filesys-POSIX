package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;

use Carp;

=head1 NAME

Filesys::POSIX::Userland

=head1 DESCRIPTION

This module is a mixin imported by Filesys::POSIX into its own namespace, and
provides a variety of higher-level calls to supplement the normal suite of
system calls provided in Filesys::POSIX itself.

=head1 METHODS

=over

=cut

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

=item $fs->mkpath($path)

=item $fs->mkpath($path, $mode)

Similar to the C<-p> flag that can be passed to mkdir(1), this method attempts
to create a hierarchy of directories specified in $path.  Each path component
created will be made with the mode specified by $mode, if any, if a directory
in that location does not already exist.  Exceptions will be thrown if one of
the items along the path hierarchy exists but is not a directory.

A default mode of 0777 is assumed; only the permissions field of $mode is used
when it is specified.  In both cases, the mode specified is modified with
exclusive OR by the current umask value.

=cut
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

=item $fs->getcwd()

Returns a string representation of the current working directory.

=cut
sub getcwd {
    my ($self) = @_;

    return $self->_find_inode_path($self->{'cwd'});
}

=item $fs->realpath($path)

Returns a string representation of the full, true and original path of the
inode specified by $path.

Using $fs->stat(), the inode of $path is resolved, then starting at that inode,
each subsequent inode's name is found from its parent and appended to a list of
path components.  

=cut
sub realpath {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);

    return $self->_find_inode_path($inode);
}

=item $fs->opendir($path)

Returns a newly opened directory entry handle for the item pointed to by $path.
Using other methods in this module, the directory can be read and closed.

=cut
sub opendir {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);

    my $dirent = $self->stat($path)->dirent;
    $dirent->open;

    return $dirent;
}

=item $fs->readdir($dirent)

Read the next member of the directory entry passed.  Returns undef if there are
no more entries to be read.

=cut
sub readdir {
    my ($self, $dirent) = @_;

    return $dirent->read unless wantarray;

    my @ret;

    while (my $item = $dirent->read) {
        push @ret, $item;
    }

    return @ret;
}

=item $fs->closedir($dirent)

Closes the directory entry handle for reading.

=cut
sub closedir {
    my ($self, $dirent) = @_;
    return $dirent->close;
}

=item $fs->touch($path)

Acts like the userland utility touch(1).  Uses $fs->open() with the $O_CREAT
flag to open the entry specified by $path, and immediately closes the file
descriptor returned.  This causes an update of the inode modification time for
existing files, and the creation of new, empty files otherwise.

=cut
sub touch {
    my ($self, $path) = @_;
    my $fd = $self->open($path, $O_CREAT);

    $self->close($fd);
}

=back

=cut

1;
