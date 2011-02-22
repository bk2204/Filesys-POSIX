package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Mem ();
use Filesys::POSIX::FdTable ();
use Filesys::POSIX::Path ();
use Filesys::POSIX::VFS ();
use Filesys::POSIX::Bits;

use Filesys::POSIX::IO ();
use Filesys::POSIX::Mount ();
use Filesys::POSIX::Userland ();

use Carp qw/confess/;

our $AUTOLOAD;

BEGIN {
    use Exporter ();
    use vars qw/$VERSION/;

    our $VERSION = '0.9';
}

=head1 NAME

Filesys::POSIX - Provide POSIX-like filesystem semantics in pure Perl

=head1 SYNOPSIS

    use Filesys::POSIX
    use Filesys::POSIX::Mem;

    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new,
        'noatime' => 1
    );

    $fs->umask(0700);
    $fs->mkdir('foo');

    my $fd = $fs->open('/foo/bar', $O_CREAT | $O_WRONLY);
    my $inode = $fs->fstat($fd);
    $fs->printf("I have mode 0%o\n", $inode->{'mode'});
    $fs->close($fd);

=head1 DESCRIPTION

Filesys::POSIX provides a fairly complete suite of tools comprising the
semantics of a POSIX filesystem, with path resolution, mount points, inodes,
a VFS, and some common utilities found in the userland.  Some features not
found in a normal POSIX environment include the ability to perform cross-
mountpoint hard links (aliasing), mapping portions of the real filesystem into
an instance of a virtual filesystem, and allowing the developer to attach and
replace inodes at arbitrary points with replacements of their own
specification.

Two filesystem types are provided out-of-the-box: A filesystem that lives in
memory completely, and a filesystem that provides a "portal" to any given
portion of the real underlying filesystem.

By and large, the manner in which data is structured is quite similar to a
real kernel filesystem implementation, with some differences: VFS inodes are
not created for EVERY disk inode (only mount points); inodes are not referred
to numerically, but rather by Perl reference; and, directory entries can be
implemented in a device-specific manner, as long as they adhere to the normal
interface specified within.

=head1 INSTANTIATING THE FILESYSTEM ENVIRONMENT

=over

=item Filesys::POSIX->new($rootfs, %opts)

Create a new filesystem environment, specifying a reference to an
uninitialized instance of a filesystem type object to be mounted at the root
of the virtual filesystem.  Options passed will be passed to the filesystem
initialization method $rootfs->init() in flat hash form, and passed on again
to the VFS, where the options will be stored for later retrieval.

=back

=head1 ERROR HANDLING

Errors are emitted in the form of exceptions thrown by Carp::confess(), with
full stack traces.

=cut
sub new {
    my ($class, $rootfs, %opts) = @_;

    confess('No root filesystem specified') unless $rootfs;

    $rootfs->init(%opts);

    my $vfs = Filesys::POSIX::VFS->new->mount($rootfs, '/', $rootfs->{'root'}, %opts);

    return bless {
        'methods'   => {},
        'umask'     => 022,
        'fds'       => Filesys::POSIX::FdTable->new,
        'cwd'       => $rootfs->{'root'},
        'root'      => $rootfs->{'root'},
        'vfs'       => $vfs,
        'cwd'       => $vfs->vnode($rootfs->{'root'}),
        'root'      => $vfs->vnode($rootfs->{'root'})
    }, $class;
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my $method = $AUTOLOAD;
    $method =~ s/^([a-z0-9_]+::)*//i;

    my $module = $self->{'methods'}->{$method};

    return if $method eq 'DESTROY';
    confess("No module imported for method '". __PACKAGE__ ."::$method()") unless $module;

    no strict 'refs';

    return *{"$module\::$method"}->($self, @args);
}

=head1 IMPORTING MODULES FOR ADDITIONAL FUNCTIONALITY

=over

=item $fs->import_module($module);

Import functionality from the module specified into the namespace of the
current filesystem object instance.  The module to be imported should be
specified in the usual form of a Perl package name.  Only the methods returned
by its EXPORT() function will be imported.

See the L</"EXTENSION MODULES"> section below for a listing of modules that
Filesys::POSIX provides.

=back

=cut
sub import_module {
    my ($self, $module) = @_;

    eval "use $module";
    confess $@ if $@;

    no strict 'refs';

    foreach (*{"$module\::EXPORT"}->()) {
        if (my $imported = $self->{'methods'}->{$_}) {
            confess("Module $imported already imported method $_") unless $module eq $imported;
        }

        $self->{'methods'}->{$_} = $module;
    }
}

=head1 SYSTEM CALLS

=over

=item $fs->umask()

=item $fs->umask($mode)

When called without an argument, the current umask value is returned.  When a
value is specified, the current umask is modified to that value, and is
returned once set.

=cut
sub umask {
    my ($self, $umask) = @_;

    return $self->{'umask'} = $umask if defined $umask;
    return $self->{'umask'};
}

sub _find_inode {
    my ($self, $path, %opts) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $dir = $self->{'cwd'};
    my $inode;

    return $self->{'root'} if $hier->full eq '/';

    while ($hier->count) {
        my $item = $hier->shift;

        #
        # We've encountered an absolute path.  Start from the beginning.
        #
        unless ($item) {
            $dir = $self->{'root'};
            next;
        }

        #
        # Before we go further, we need to resolve the current directory for
        # a possible VFS inode in the event of a mountpoint or filesystem root.
        #
        $dir = $self->{'vfs'}->vnode($dir);

        unless ($dir->{'dev'}->{'flags'}->{'noatime'}) {
            $dir->{'atime'} = time;
        }

        #
        # From this point, deal with the directory in terms of a directory entry.
        #
        my $directory = $dir->directory;

        if ($item eq '.') {
            $inode = $dir;
        } elsif ($item eq '..') {
            my $vnode = $self->{'vfs'}->vnode($dir);
            $inode = $vnode->{'parent'}? $vnode->{'parent'}: $self->{'vfs'}->vnode($directory->get('..'));
        } else {
            $inode = $self->{'vfs'}->vnode($directory->get($item));
        }

        confess('No such file or directory') unless $inode;

        if ($inode->link) {
            $hier = $hier->concat($inode->readlink) if $opts{'resolve_symlinks'} || $hier->count;
        } else {
            $dir = $inode;
        }
    }

    return $inode;
}

=item $fs->stat($path)

Resolve the given path for an inode in the filesystem.  If the inode found is
a symlink, the path of that symlink will be resolved in turn until the desired
inode is located.

Paths will be resolved relative to the current working directory when not
prefixed with a slash ('/'), and will be resolved relative to the root
directory when prefixed with a slash ('/').

=cut
sub stat {
    my ($self, $path) = @_;
    return $self->_find_inode($path,
        'resolve_symlinks' => 1
    );
}

=item $fs->lstat($path)

Resolve the given path for an inode in the filesystem.  Unlinke $fs->stat(),
the inode found will be returned literally in the case of a symlink.

=cut
sub lstat {
    my ($self, $path) = @_;
    return $self->_find_inode($path);
}

=item $fs->fstat($fd)

Return the inode corresponding to the open file descriptor passed.  An
exception will be thrown by the file descriptor lookup module if the file
descriptor passed does not correspond to an open file.

=cut
sub fstat {
    my ($self, $fd) = @_;
    return $self->{'fds'}->lookup($fd)->{'inode'};
}

=item $fs->chdir($path)

Change the current working directory to the path specified.  An $fs->stat()
call will be used internally to lookup the inode for that path; an exception
"Not a directory" will be thrown unless the inode found is a directory.  The
internal current working directory pointer will be updated with the directory
inode found.

=cut
sub chdir {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);
    confess('Not a directory') unless $inode->dir;

    $self->{'cwd'} = $inode;
}

=item $fs->chdir($fd)

When passed a file descriptor for a directory, return a reference to the
corresponding directory inode.  If the inode is not a directory, an exception
"Not a directory" will be thrown.

=cut
sub fchdir {
    my ($self, $fd) = @_;
    my $inode = $self->fstat($fd);
    confess('Not a directory') unless $inode->dir;

    $self->{'cwd'} = $inode;
}

=item $fs->chown($path, $uid, $gid)

Using $fs->stat() to locate the inode of the path specified, update that inode
object's 'uid' and 'gid' fields with the values specified.

=cut
sub chown {
    my ($self, $path, $uid, $gid) = @_;
    $self->stat($path)->chown($uid, $gid);
}

=item $fs->fchown($fd, $uid, $gid)

Using $fs->fstat() to locate the inode of the file descriptor specified, update
that inode object's 'uid' and 'gid' fields with the values specified.

=cut
sub fchown {
    my ($self, $fd, $uid, $gid) = @_;
    $self->fstat($fd)->chown($uid, $gid);
}

=item $fs->chmod($path, $mode)

Using $fs->stat() to locate the inode of the path specified, update that inode
object's 'mode' field with the value specified.

=cut
sub chmod {
    my ($self, $path, $mode) = @_;
    $self->stat($path)->chmod($mode);
}

=item $fs->fchmod($fd, $mode)

Using $fs->fstat() to locate the inode of the file descriptor specified, update
that inode object's 'mode' field with the value specified.

=cut
sub fchmod {
    my ($self, $fd, $mode) = @_;
    $self->fstat($fd)->chmod($mode);
}

=item $fs->mkdir($path)

=item $fs->mkdir($path, $mode)

Create a new directory at the path specified, applying the permissions field in
the mode value specified.  If no mode is specified, the default permissions of
0777 will be modified by the current umask value.  A "Not a directory"
exception will be thrown in case the intended parent of the directory to be
created is not actually a directory itself.

=cut
sub mkdir {
    my ($self, $path, $mode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);
    my $perm = $mode? $mode & ($S_IPERM | $S_IPROT): $S_IPERM ^ $self->{'umask'};

    $parent->child($name, $perm | $S_IFDIR);
}

=item $fs->link($src, $dest)

Using $fs->stat() to resolve the path of the link source, and the parent of the
link destination, $fs->link() place a reference to the source inode in the
location specified by the destination.

If a destination inode already exists, it will only be able to be replaced by
the source if both are either directories or non-directories.  If the source
and destination are both directories, the destination will only be replaced if
the directory entry for the destination is empty.

Links traversing filesystem mount points are not allowed.  This functionality
is provided in the alias() call provided by the Filesys::POSIX::Extensions
module, which can be imported by $fs->import_module() at runtime.

Exceptions thrown:

=over

=item Cross-device link

The inode resolved for the link source is not associated with the same device
as the inode of the destination's parent directory.

=item Is a directory

Thrown if the source inode is a directory.  Hard links can only be made for
non-directory inodes.

=item File exists

Thrown if an entry at the destination path already exists.

=back

=cut
sub link {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $inode = $self->stat($src);
    my $parent = $self->stat($hier->dirname);
    my $directory = $parent->directory;

    confess('Cross-device link') unless $inode->{'dev'} == $parent->{'dev'};
    confess('Is a directory') if $inode->dir;
    confess('File exists') if $directory->exists($name);

    $directory->set($name, $inode);
}

=item $fs->symlink($path, $dest)

The path in the first argument specified, $path, is cleaned up using
Filesys::POSIX::Path->full(), and stored in a new symlink inode created in the
location specified by $dest.  An exception will be thrown if the destination
exists.

=cut
sub symlink {
    my ($self, $path, $dest) = @_;
    my $perms = $S_IPERM ^ $self->{'umask'};
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    $parent->child($name, $S_IFLNK | $perms)->symlink(Filesys::POSIX::Path->full($path));
}

=item $fs->readlink($path)

Using $fs->lstat() to resolve the given path for an inode, the symlink
destination path associated with the inode is returned as a string.  A "Not a
symlink" exception is thrown unless the inode found is indeed a symlink.

=cut
sub readlink {
    my ($self, $path) = @_;
    my $inode = $self->lstat($path);
    confess('Not a symlink') unless $inode->link;

    return $inode->readlink;
}

=item $fs->unlink($path)

Using $fs->lstat() to resolve the given path for an inode specified, said inode
will be removed from its parent directory entry.  The following exceptions will
be thrown in the event of certain errors:

=over

=item No such file or directory

No entry was found in the path's parent directory for the item specified in the
path.

=item Is a directory

$fs->unlink() was called with a directory specified.  $fs->rmdir() must be used
instead for removing directory inodes.

=back

=cut
sub unlink {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->lstat($hier->dirname);
    my $directory = $parent->directory;
    my $inode = $directory->get($name);

    confess('No such file or directory') unless $inode;
    confess('Is a directory') if $inode->dir;

    $directory->delete($name);
}

=item $fs->rename($old, $new)

Relocate the item specified by the $old argument to the new path specified by
$new.

Using $fs->lstat(), the inode for the old pathname is resolved; $fs->stat() is
then used to resolve the path of the parent directory of the argument specified
in $new.

If an inode exists at the path specified by $new, it will be replaced by $old
in the following circumstances:

=over

=item Both the source ($old) and destination ($new) are non-directory inodes.

=item Both the source ($old) and destination ($new) are directory inodes, and
the destination is empty.

=back

The following exceptions are thrown for error conditions:

=over

=item Operation not permitted

Currently, $fs->rename() cannot operate if the inode at the old location is an
inode associated with a Filesys::POSIX::Real filesystem type.

=item Cross-device link

The inode at the old path does not exist on the same filesystem device as the
inode of the parent directory specified in the new path.

=item Not a directory

The old inode is a directory, but an existing inode found in the new path
specified, is not.

=item Is a directory

The old inode is not a directory, but an existing inode found in the new path
specified, is.

=item Directory not empty

Both the old and new paths correspond to a directory, but the new path is not
of an empty directory.

=back

=cut
sub rename {
    my ($self, $old, $new) = @_;
    my $hier = Filesys::POSIX::Path->new($new);
    my $name = $hier->basename;
    my $inode = $self->lstat($old);
    my $parent = $self->stat($hier->dirname);
    my $directory = $parent->directory;

    confess('Operation not permitted') if ref $inode eq 'Filesys::POSIX::Real::Inode';
    confess('Cross-device link') unless $inode->{'dev'} eq $parent->{'dev'};

    if (my $existing = $directory->get($name)) {
        if ($inode->dir) {
            confess('Not a directory') unless $existing->dir;
            confess('Directory not empty') unless $existing->empty;
        } else {
            confess('Is a directory') if $existing->dir;
        }
    }

    my $remove = $inode->dir? 'rmdir': 'unlink';
    $self->$remove($old);

    $directory->set($name, $inode);
}

=item $fs->rmdir($path)

Unlinks the directory inode at the specified path.  Exceptions are thrown in
the following conditions:

=over

=item No such file or directory

No inode exists by the name specified in the final component of the path in
the parent directory specified in the path.

=item Device or resource busy

The directory specified is an active mount point.

=item Not a directory

The inode found at $path is not a directory.

=item Directory not empty

The directory is not empty.

=back

=cut
sub rmdir {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->lstat($hier->dirname);
    my $directory = $parent->directory;
    my $inode = $directory->get($name);

    confess('No such file or directory') unless $inode;
    confess('Device or resource busy') if $self->{'vfs'}->statfs($self->stat($path), 'exact' => 1, 'silent' => 1);
    confess('Directory not empty') unless $inode->empty;

    $directory->delete($name);
}

=back

=cut

1;

__END__

=head1 EXTENSION MODULES

=over

=item L<Filesys::POSIX::Extensions>

This module provides a variety of functions for performing inode operations in
novel ways that take advantage of the unique characteristics and features of
Filesys::POSIX.  For example, one method is provided that allows a developer to
map a file or directory from the system's underlying, actual filesystem, into
any arbitrary point in the virtual filesystem.

=back

=head1 UTILITIES

=over

=item L<Filesys::POSIX::Path>

A publicly-accessible interface for the path name string manipulation functions
used by Filesys::POSIX itself.

=back

=head1 INTERFACES

=over

=item L<Filesys::POSIX::Directory>

Lists the requirements for writing modules that act as directory structures.

=item L<Filesys::POSIX::Inode>

Lists the requirements for writing modules that act as inodes.

=back

=head1 INTERNALS

=over

=item L<Filesys::POSIX::Bits>

A listing of bitfields and constants used in various places by Filesys::POSIX.

=item L<Filesys::POSIX::FdTable>

The Filesys::POSIX implementation of the file descriptor allocation table.

=item L<Filesys::POSIX::Userland>

Imported by Filesys::POSIX by default.  Provides many POSIX command line
tool-like functions not documented in the current manual page.

=item L<Filesys::POSIX::IO>

Imported by Filesys::POSIX by default.  Provides standard file manipulation
routines as found in a POSIX filesystem.

=item L<Filesys::POSIX::Mount>

Imported by Filesys::POSIX by default.  Provides a frontend to the VFS mount
point management implementation found in L<Filesys::POSIX::VFS>.

=item L<Filesys::POSIX::VFS>

Used by Filesys::POSIX, this module provides an implementation of a filesystem
mount table and VFS inode resolution routines.

=back
