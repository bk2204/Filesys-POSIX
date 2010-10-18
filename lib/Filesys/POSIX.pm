package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;
use Filesys::POSIX::VFS;

sub new {
    my ($class, $rootfs, %opts) = @_;

    die('No root filesystem specified') unless $rootfs;

    $rootfs->init(%opts);

    my $vfs = Filesys::POSIX::VFS->new;
    $vfs->mount($rootfs, '/', $rootfs->{'root'}, %opts);

    return bless {
        'fds'   => Filesys::POSIX::FdTable->new,
        'vfs'   => $vfs,
        'cwd'   => $rootfs->{'root'},
        'root'  => $rootfs->{'root'},
        'umask' => 022,
    }, $class;
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

        unless ($item) {
            $dir = $self->{'root'};
            next;
        }

        die('Not a directory') unless $dir->{'mode'} & $S_IFDIR;

        unless ($self->{'vfs'}->statfs($dir)->{'flags'}->{'noatime'}) {
            $dir->{'atime'} = time;
        }

        $node = $self->{'vfs'}->vnode($dir->{'dirent'}->get($item)) or die('No such file or directory');

        if ($opts{'resolve_symlinks'} && $node->{'mode'} & $S_IFLNK) {
            $hier = Filesys::POSIX::Path->new($node->readlink);
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
    return $self->{'fds'}->lookup($fd);
}

sub open {
    my ($self, $path, $flags, $mode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $inode;

    if ($flags & $O_CREAT) {
        my $parent = $self->stat($hier->dirname);
        my $format = $mode? $mode & $S_IFMT: $S_IFREG;
        my $perms = $mode? $mode & $S_IPERM: $S_IRW ^ $self->{'umask'};

        die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;
        die('File exists') if $parent->{'dirent'}->exists($name);

        if ($format & $S_IFDIR) {
            $perms |= $S_IX ^ $self->{'umask'} unless $perms;
        }

        $inode = $parent->child($name, $format | $perms);
    }

    return $self->{'fds'}->alloc($inode);
}

sub close {
    my ($self, $fd) = @_;
    $self->{'fds'}->free($fd);
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
    my $perm = $mode? $mode & ($S_IPERM | $S_IPROT): $S_IPERM ^ $self->{'umask'};

    my $fd = $self->open($path, $O_CREAT, $perm | $S_IFDIR);
    $self->close($fd);
}

sub link {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $node = $self->stat($src);
    my $parent = $node->{'parent'};

    die('Cross-device link') unless $node->{'dev'} == $parent->{'dev'};
    die('Is a directory') if $node->{'mode'} & $S_IFDIR;
    die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;
    die('File exists') if $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->set($name, $node);
}

sub symlink {
    my ($self, $src, $dest) = @_;
    my $perms = $S_IPERM ^ $self->{'umask'};

    my $fd = $self->open($dest, $O_CREAT | $O_WRONLY, $S_IFLNK | $perms);
    $self->fstat($fd)->{'dest'} = Filesys::POSIX::Path->full($src);
    $self->close($fd);
}

sub readlink {
    my ($self, $path) = @_;

    return $self->stat($path)->readlink;
}

sub unlink {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $node = $self->stat($hier->full);
    my $parent = $node->{'parent'};

    die('Is a directory') if $node->{'mode'} & $S_IFDIR;
    die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;
    die('No such file or directory') unless $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->delete($name);
}

sub rmdir {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $node = $self->stat($hier->full);
    my $parent = $node->{'parent'};

    die('Not a directory') unless $node->{'mode'} & $S_IFDIR;
    die('Device or resource busy') if $node == $parent;
    die('Directory not empty') unless $node->{'dirent'}->count == 2;
    die('No such file or directory') unless $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->delete($name);
}

1;
