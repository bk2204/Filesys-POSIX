package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;
use Filesys::POSIX::VFS;

use Filesys::POSIX::IO;
use Filesys::POSIX::Mount;
use Filesys::POSIX::Userland;

use Carp;

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

Import each method from the module specified into the namespace of the current
filesystem object instance.  The module to be imported should be specified in
the usual form of a Perl package name.  Only the methods returned by its
EXPORT() function will be imported.

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
        my $dirent = $dir->dirent;

        if ($item eq '.') {
            $inode = $dir;
        } elsif ($item eq '..') {
            my $vnode = $self->{'vfs'}->vnode($dir);
            $inode = $vnode->{'parent'}? $vnode->{'parent'}: $self->{'vfs'}->vnode($dirent->get('..'));
        } else {
            $inode = $self->{'vfs'}->vnode($dirent->get($item));
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
    die('Not a directory') unless $inode->dir;

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
    die('Not a directory') unless $inode->dir;

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

=item $fs->lchown($path, $uid, $gid)

Using $fs->lstat() to locate the inode of the path specified, update that inode
object's 'uid' and 'gid' fields with the values specified.

=cut
sub lchown {
    my ($self, $path, $uid, $gid) = @_;
    $self->lstat($path)->chown($uid, $gid);
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

=item $fs->lchmod($path, $mode)

Using $fs->lstat() to locate the inode of the path specified, update that inode
object's 'mode' field with the value specified.

=cut
sub lchmod {
    my ($self, $path, $mode) = @_;
    $self->lstat($path)->chmod($mode);
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

=cut
sub link {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $inode = $self->stat($src);
    my $parent = $self->stat($hier->dirname);
    my $dirent = $parent->dirent;

    confess('Cross-device link') unless $inode->{'dev'} == $parent->{'dev'};
    confess('Is a directory') if $inode->dir;
    confess('File exists') if $dirent->exists($name);

    $dirent->set($name, $inode);
}

sub symlink {
    my ($self, $path, $dest) = @_;
    my $perms = $S_IPERM ^ $self->{'umask'};
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    $parent->child($name, $S_IFLNK | $perms)->symlink($path);
}

sub readlink {
    my ($self, $path) = @_;

    return $self->lstat($path)->readlink;
}

sub unlink {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->lstat($hier->dirname);
    my $dirent = $parent->dirent;
    my $inode = $dirent->get($name);

    confess('No such file or directory') unless $inode;
    confess('Is a directory') if $inode->dir;

    $dirent->delete($name);
}

sub rename {
    my ($self, $old, $new) = @_;
    my $hier = Filesys::POSIX::Path->new($new);
    my $name = $hier->basename;
    my $inode = $self->lstat($old);
    my $parent = $self->stat($hier->dirname);
    my $dirent = $parent->dirent;

    confess('Operation not permitted') if ref $inode eq 'Filesys::POSIX::Real::Inode';
    confess('Cross-device link') unless $inode->{'dev'} eq $parent->{'dev'};

    if (my $existing = $dirent->get($name)) {
        if ($inode->dir) {
            confess('Not a directory') unless $existing->dir;
        } else {
            confess('Is a directory') if $existing->dir;
        }
    }

    my $remove = $inode->dir? 'rmdir': 'unlink';
    $self->$remove($old);

    $dirent->set($name, $inode);
}

sub rmdir {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->lstat($hier->dirname);
    my $dirent = $parent->dirent;
    my $inode = $dirent->get($name);

    confess('No such file or directory') unless $inode;
    confess('Device or resource busy') if $self->{'vfs'}->statfs($self->stat($path), 'exact' => 1);
    confess('Directory not empty') unless $inode->dirent->count == 2;

    $dirent->delete($name);
}

1;
