package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub new {
    my ($class) = @_;
    my $root = _mkfs();

    return bless {
        'root'  => $root,
        'cwd'   => $root,
        'umask' => 022,
        'fds'   => {}
    }, $class;
}

sub _fd_alloc {
    my ($self, $inode) = @_;
    my $fd = 3;

    foreach (sort { $a <=> $b } keys %{$self->{'fds'}}) {
        next if $self->{'fds'}->{$fd = $_ + 1};
        last;
    }

    $self->{'fds'}->{$fd} = $inode;

    return $fd;
}

sub _fd_lookup {
    my ($self, $fd) = @_;
    my $inode = $self->{'fds'}->{$fd} or die('Invalid file descriptor');

    return $inode;
}

sub _fd_free {
    my ($self, $fd) = @_;
    delete $self->{'fds'}->{$fd};
}

sub _inode {
    my ($mode) = @_;
    my $now = time;

    return {
        'atime' => $now,
        'mtime' => $now,
        'uid'   => 0,
        'gid'   => 0,
        'mode'  => $mode
    };
}

sub _mkfs {
    my $root = _inode($S_IFDIR | 0755);

    $root->{'dirent'} = {
        '.'     => $root,
        '..'    => $root
    };

    return $root;
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
    return $self->_fd_lookup($fd);
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

        $inode = _inode($mode);

        if ($mode & $S_IFDIR) {
            my $parent = $hier[0]? $self->stat(join('/', @hier[0..$#hier-1])): $self->{'root'};

            $inode->{'dirent'} = {
                '.'     => $inode,
                '..'    => $parent
            };

            $parent->{'dirent'}->{$name} = $inode;
        }
    }

    return $self->_fd_alloc($inode);
}

sub close {
    my ($self, $fd) = @_;
    $self->_fd_free($fd);
}

sub getcwd {
    return shift->{'cwd'};
}

sub chdir {
    my ($self, $path) = @_;
    $self->{'cwd'} = $self->stat($path);
}

sub _chown {
    my ($self, $node, $uid, $gid) = @_;
    @{$node}{qw/uid gid/} = ($uid, $gid);
}

sub chown {
    my ($self, $path, $uid, $gid) = @_;
    $self->_chown($self->stat($path), $uid, $gid);
}

sub fchown {
    my ($self, $fd, $uid, $gid) = @_;
    $self->_chown($self->fstat($fd), $uid, $gid);
}

sub _chmod {
    my ($self, $node, $mode) = @_;
    my $format = $node->{'mode'} & $S_IFMT;
    my $perm = $mode & ($S_IPERM | $S_IPROT);

    $node->{'mode'} = $format | $perm;
}

sub chmod {
    my ($self, $path, $mode) = @_;
    $self->_chmod($self->stat($path), $mode);
}

sub fchmod {
    my ($self, $fd, $mode) = @_;
    $self->_chmod($self->fstat($fd), $mode);
}

sub mkdir {
    my ($self, $path, $mode) = @_;
    my $perm = $mode? $mode & ($S_IPERM | $S_IPROT): $S_IPERM;

    my $fd = $self->open($path, $O_CREAT, $perm | $S_IFDIR);
    $self->close($fd);
}

1;
