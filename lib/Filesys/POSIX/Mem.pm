package Filesys::POSIX::Mem;

use strict;
use warnings;

our $O_RDONLY   = 0x0001;
our $O_WRONLY   = 0x0002;
our $O_RDWR     = 0x0004;
our $O_NONBLOCK = 0x0008;
our $O_APPEND   = 0x0010;
our $O_CREAT    = 0x0020;
our $O_TRUNC    = 0x0040;
our $O_EXCL     = 0x0080;
our $O_SHLOCK   = 0x0100;
our $O_EXLOCK   = 0x0200;
our $O_NOFOLLOW = 0x0400;
our $O_SYMLINK  = 0x0800;
our $O_EVTONLY  = 0x1000;

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
    my ($mode, $umask) = @_;
    my $now = time;

    return {
        'atime' => $now,
        'mtime' => $now,
        'uid'   => 0,
        'gid'   => 0,
        'mode'  => $mode ^ $umask
    };
}

sub _mkfs {
    my $root = _inode(040777, 022);

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

        die('File exists') if $parent->{'dirent'}->{$name};
        die('Not a directory') unless $parent->{'mode'} & 040000;

        $inode = _inode($mode, $self->{'umask'});

        if ($mode & 040000) {
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

sub chown {
    my ($self, $path, $uid, $gid) = @_;
    my $node = $self->stat($path);
    @{$node}{qw/uid gid/} = ($uid, $gid);
}

sub fchown {
    my ($self, $fd, $uid, $gid) = @_;
    my $node = $self->fstat($fd);
    @{$node}{qw/uid gid/} = ($uid, $gid);
}

sub mkdir {
    my ($self, $path, $mode) = @_;
    my $fd = $self->open($path, $O_CREAT, 040777);
    $self->close($fd);
}

1;
