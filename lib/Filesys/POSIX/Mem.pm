package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;

sub new {
    my ($class, %opts) = @_;
    my $root = Filesys::POSIX::Inode->new($S_IFDIR | 0755);

    $root->{'dirent'} = {
        '.'     => $root,
        '..'    => $root
    };

    return bless {
        'noatime'   => $opts{'noatime'},
        'root'      => $root,
        'cwd'       => $root,
        'umask'     => 022,
        'fds'       => Filesys::POSIX::FdTable->new
    }, $class;
}

sub stat {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $node = $self->{'cwd'};
    my $now = time;

    unless ($hier->[0]) {
        $node = $self->{'root'};
        $hier->shift;
    }

    dir: while (my $dir = $hier->shift) {
        die('Not a directory') unless $node->{'mode'} & $S_IFDIR;

        $node->{'atime'} = $now unless $self->{'noatime'};

        subdir: foreach (keys %{$node->{'dirent'}}) {
            if ($_ eq $dir) {
                $node = $node->{'dirent'}->{$_};
                next dir;
            }
        }

        die('No such file or directory');
    }

    return $node;
}

sub umask {
    my ($self, $umask) = @_;

    if ($umask) {
        return $self->{'umask'} = $umask;
    }

    return $self->{'umask'};
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

        die('File exists') if $parent->{'dirent'}->{$name};
        die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;

        $inode = Filesys::POSIX::Inode->new;

        if ($format & $S_IFDIR) {
            $perms |= $S_IX ^ $self->{'umask'} unless $perms;

            $inode->{'dirent'} = {
                '.'     => $inode,
                '..'    => $parent
            };
        }

        $inode->{'mode'} = $format | $perms;
        $parent->{'dirent'}->{$name} = $inode;
    }

    return $self->{'fds'}->alloc($inode);
}

sub close {
    my ($self, $fd) = @_;
    $self->{'fds'}->free($fd);
}

sub getcwd {
    return shift->{'cwd'};
}

sub chdir {
    my ($self, $path) = @_;
    $self->{'cwd'} = $self->stat($path);
}

sub chown {
    my ($self, $path, $uid, $gid) = @_;
    $self->stat($path)->chown($uid, $gid);
}

sub fchown {
    my ($self, $fd, $uid, $gid) = @_;
    $self->fstat($fd)->chown($uid, $gid);
}

sub chmod {
    my ($self, $path, $mode) = @_;
    $self->stat($path)->chmod($mode);
}

sub fchmod {
    my ($self, $fd, $mode) = @_;
    $self->fstat($fd)->chmod($mode);
}

sub mkdir {
    my ($self, $path, $mode) = @_;
    my $perm = $mode? $mode & ($S_IPERM | $S_IPROT): $S_IPERM;

    my $fd = $self->open($path, $O_CREAT, $perm | $S_IFDIR);
    $self->close($fd);
}

sub link {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $node = $self->stat($src);
    my $parent = $self->stat($hier->dirname);

    die('Is a directory') if $node->{'mode'} & $S_IFDIR;
    die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;
    die('File exists') if $parent->{'dirent'}->{$name};

    $parent->{'dirent'}->{$name} = $node;
}

sub symlink {
    my ($self, $src, $dest) = @_;
    my $perms = $S_IPERM ^ $self->{'umask'};

    my $fd = $self->open($dest, $O_CREAT | $O_WRONLY, $S_IFLNK | $perms);
    $self->fstat($fd)->{'dest'} = Filesys::POSIX::Path->full($src);
    $self->close($fd);
}

sub unlink {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $node = $self->stat($hier->full);
    my $parent = $self->stat($hier->dirname);

    die('Is a directory') if $node->{'mode'} & $S_IFDIR;
    die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;
    die('No such file or directory') unless $parent->{'dirent'}->{$name};

    delete $parent->{'dirent'}->{$name};
}

sub rmdir {
    my ($self, $path) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $node = $self->stat($hier->full);
    my $parent = $self->stat($hier->dirname);

    die('Not a directory') unless $node->{'mode'} & $S_IFDIR;
    die('Device or resource busy') if $node == $parent;
    die('Directory not empty') unless scalar(keys %{$node->{'dirent'}}) == 2 && @{$node->{'dirent'}}{qw/. ../};
    die('No such file or directory') unless $parent->{'dirent'}->{$name};

    delete $parent->{'dirent'}->{$name};
}

1;
