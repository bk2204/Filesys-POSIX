package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;
use Filesys::POSIX::VFS;

use Filesys::POSIX::IO;
use Filesys::POSIX::Userland;

our $AUTOLOAD;

sub new {
    my ($class, $rootfs, %opts) = @_;

    die('No root filesystem specified') unless $rootfs;

    $rootfs->init(%opts);

    return bless {
        'methods'   => {},
        'umask'     => 022,
        'fds'       => Filesys::POSIX::FdTable->new,
        'cwd'       => $rootfs->{'root'},
        'root'      => $rootfs->{'root'},

        'vfs'       => Filesys::POSIX::VFS->new->mount(
            $rootfs, '/', $rootfs->{'root'}, %opts
        )
    }, $class;
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my $method = $AUTOLOAD;
    $method =~ s/^([a-z0-9_]+::)*//i;

    my $module = $self->{'methods'}->{$method};

    return if $method eq 'DESTROY';
    die("No module imported for method '". __PACKAGE__ ."::$method()") unless $module;

    no strict 'refs';

    return *{"$module\::$method"}->($self, @args);
}

sub import_module {
    my ($self, $module, @args) = @_;

    eval "use $module";
    die $@ if $@;

    no strict 'refs';

    foreach (*{"$module\::EXPORT"}->()) {
        if (my $imported = $self->{'methods'}->{$_}) {
            die("Module $imported already imported method $_") unless $module eq $imported;
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
    my $node;

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

        die('Not a directory') unless ($dir->{'mode'} & $S_IFMT) == $S_IFDIR;

        unless ($self->{'vfs'}->statfs($dir)->{'flags'}->{'noatime'}) {
            $dir->{'atime'} = time;
        }

        if ($item eq '..') {
            $node = $dir->{'parent'}? $dir->{'parent'}: $dir;
        } elsif ($item eq '.') {
            $node = $dir;
        } else {
            $node = $self->{'vfs'}->vnode($dir->{'dirent'}->get($item)) or die('No such file or directory');
        }

        if ($opts{'resolve_symlinks'} && ($node->{'mode'} & $S_IFMT) == $S_IFLNK) {
            $hier = $hier->concat($node->readlink);
        } else {
            $dir = $node;
        }
    }

    die('No such file or directory') unless $node;

    return $node;
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
    my $node = $self->lstat($src);
    my $parent = $node->{'parent'};

    die('Cross-device link') unless $node->{'dev'} == $parent->{'dev'};
    die('Is a directory') if ($node->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('File exists') if $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->set($name, $node);
}

sub symlink {
    my ($self, $src, $dest) = @_;
    my $perms = $S_IPERM ^ $self->{'umask'};
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    $parent->child($name, $S_IFLNK | $perms);
}

sub readlink {
    my ($self, $path) = @_;

    return $self->lstat($path)->readlink;
}

sub unlink {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $node = $self->lstat($hier->full);
    my $parent = $node->{'parent'};

    die('Is a directory') if ($node->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('No such file or directory') unless $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->delete($name);
}

sub rmdir {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $node = $self->lstat($hier->full);
    my $parent = $node->{'parent'};

    die('Not a directory') unless ($node->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('Device or resource busy') if $node == $parent;
    die('Directory not empty') unless $node->{'dirent'}->count == 2;
    die('No such file or directory') unless $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->delete($name);
}

1;
