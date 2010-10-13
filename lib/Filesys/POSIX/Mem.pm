package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode;
use Filesys::POSIX::FdTable;

sub new {
    my ($class) = @_;
    my $root = Filesys::POSIX::Inode->new($S_IFDIR | 0755);

    $root->{'dirent'} = {
        '.'     => $root,
        '..'    => $root
    };

    return bless {
        'root'  => $root,
        'cwd'   => $root,
        'umask' => 022,
        'fds'   => Filesys::POSIX::FdTable->new
    }, $class;
}

sub _cleanpath {
    my ($path) = @_;
    my @components = split /\//, $path;

    my @ret = grep {
        $_ && $_ ne '.'
    } @components;

    $components[0]? @ret: ('', @ret);
}

sub _resolve {
    my $self = shift;
    my @hier = _cleanpath(shift);
    my $node = $self->{'cwd'};
    my $now = time;

    die('Empty path') unless @hier;

    unless ($hier[0]) {
        $node = $self->{'root'};
        shift @hier;
    }

    dir: while (my $dir = shift @hier) {
        die('Not a directory') unless $node->{'mode'} & 040000;

        $node->{'atime'} = $now;

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

sub stat {
    my ($self, $path) = @_;
    return $self->_resolve($path);
}

sub fstat {
    my ($self, $fd) = @_;
    return $self->{'fds'}->lookup($fd);
}

sub open {
    my ($self, $path, $flags, $mode) = @_;
    my @hier = _cleanpath($path);
    my $name = $hier[$#hier];
    my $inode;

    die('Empty path') unless $name;

    if ($flags & $O_CREAT) {
        my $parent = $hier[0]? $self->stat(join('/', @hier[0..$#hier-1])): $self->{'root'};
        my $perms = $mode? $mode & ($S_IFMT | $S_IPROT | $S_IPERM): $S_IFREG | ($S_IPERM ^ $self->{'umask'});

        die('File exists') if $parent->{'dirent'}->{$name};
        die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;

        $inode = Filesys::POSIX::Inode->new($mode);

        if ($mode & $S_IFDIR) {
            my $parent = $hier[0]? $self->stat(join('/', @hier[0..$#hier-1])): $self->{'root'};

            $inode->{'dirent'} = {
                '.'     => $inode,
                '..'    => $parent
            };

            $parent->{'dirent'}->{$name} = $inode;
        }
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

1;
