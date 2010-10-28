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

sub import_module {
    my ($self, $module, @args) = @_;

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

sub umask {
    my ($self, $umask) = @_;

    return $self->{'umask'} = $umask if $umask;
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

sub stat {
    my ($self, $path) = @_;
    return $self->_find_inode($path,
        'resolve_symlinks' => 1
    );
}

sub lstat {
    my ($self, $path) = @_;
    return $self->_find_inode($path);
}

sub fstat {
    my ($self, $fd) = @_;
    return $self->{'fds'}->lookup($fd)->{'inode'};
}

sub chdir {
    my ($self, $path) = @_;
    $self->{'cwd'} = $self->stat($path);
}

sub fchdir {
    my ($self, $fd) = @_;
    $self->{'cwd'} = $self->fstat($fd);
}

sub chown {
    my ($self, $path, $uid, $gid) = @_;
    $self->stat($path)->chown($uid, $gid);
}

sub lchown {
    my ($self, $path, $uid, $gid) = @_;
    $self->lstat($path)->chown($uid, $gid);
}

sub fchown {
    my ($self, $fd, $uid, $gid) = @_;
    $self->fstat($fd)->chown($uid, $gid);
}

sub chmod {
    my ($self, $path, $mode) = @_;
    $self->stat($path)->chmod($mode);
}

sub lchmod {
    my ($self, $path, $mode) = @_;
    $self->lstat($path)->chmod($mode);
}

sub fchmod {
    my ($self, $fd, $mode) = @_;
    $self->fstat($fd)->chmod($mode);
}

sub mkdir {
    my ($self, $path, $mode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);
    my $perm = $mode? $mode & ($S_IPERM | $S_IPROT): $S_IPERM ^ $self->{'umask'};

    $parent->child($name, $perm | $S_IFDIR);
}

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
