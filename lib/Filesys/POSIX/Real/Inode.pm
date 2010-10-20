package Filesys::POSIX::Real::Inode;

use strict;
use warnings;

use Fcntl;

use Filesys::POSIX::Bits;
use Filesys::POSIX::IO::Handle;

sub new {
    my ($class, $path, %opts) = @_;
    my @st = $opts{'st_info'}? @{$opts{'st_info'}}: lstat $path or die $!;

    my $inode = bless {
        'path'      => $path,
        'dev'       => $opts{'dev'},
        'parent'    => $opts{'parent'}
    }, $class;

    $inode->_load_st_info(@st);

    if (($st[2] & $S_IFMT) == $S_IFDIR) {
        $inode->{'dirent'} = Filesys::POSIX::Real::Dirent->new($path, $inode);
    }

    return $inode;
}

sub _load_st_info {
    my ($self, @st) = @_;

    @{$self}{qw/size atime mtime ctime uid gid mode rdev/} = (@st[7..10], @st[4..5], $st[2], $st[6]);
}

sub child {
    my ($self, $name, $mode) = @_;

    die('Not a directory') unless ($self->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('Invalid directory entry name') if $name =~ /\//;
    die('File exists') if $self->{'dirent'}->exists($name);

    my $path = "$self->{'path'}/$name";
    my $child;

    if (($mode & $S_IFMT) == $S_IFDIR) {
        mkdir($path, $mode) or die $!;
    } else {
        sysopen(my $fh, $path, O_CREAT | O_TRUNC | O_WRONLY, $mode) or die $!;
        close($fh);
    }

    return __PACKAGE__->new($path,
        'dev'       => $self->{'dev'},
        'parent'    => $self
    );
}

sub open {
    my ($self, $flags) = @_;

    sysopen(my $fh, $self->{'path'}, $flags) or die $!;

    return $self->{'handle'} = Filesys::POSIX::IO::Handle->new($fh);
}

sub close {
    my ($self) = @_;

    if ($self->{'handle'}) {
        $self->{'handle'}->close;
    }
}

sub chown {
    my ($self, $uid, $gid) = @_;
    CORE::chown($uid, $gid, $self->{'path'});
    @{$self}{qw/uid gid/} = ($uid, $gid);
}

sub chmod {
    my ($self, $mode) = @_;
    CORE::chmod($mode, $self->{'path'});
    $self->{'mode'} = $mode;
}

sub readlink {
    my ($self) = @_;
    die('Not a symlink') unless ($self->{'mode'} & $S_IFMT) == $S_IFLNK;

    return CORE::readlink($self->{'path'});
}

1;
