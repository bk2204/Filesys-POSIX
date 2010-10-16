package Filesys::POSIX::Real::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Fcntl;

sub new {
    my ($class, $path, %opts) = @_;
    my @st = stat $path or die("$path: $!");

    my $inode = bless {
        'path'      => $path,
        'atime'     => $st[8],
        'mtime'     => $st[9],
        'ctime'     => $st[10],
        'uid'       => $st[4],
        'gid'       => $st[5],
        'mode'      => $st[2],
        'dev'       => $opts{'dev'},
        'rdev'      => $st[6],
        'parent'    => $opts{'parent'}
    }, $class;

    if ($st[2] & $S_IFDIR) {
        $inode->{'dirent'} = Filesys::POSIX::Real::Dirent->new($path, $inode);
    }

    return $inode;
}

sub child {
    my ($self, $name, $mode) = @_;

    die('Not a directory') unless $self->{'mode'} & $S_IFDIR;
    die('Invalid directory entry name') if $name =~ /\//;
    die('File exists') if $self->{'dirent'}->exists($name);

    my $path = "$self->{'path'}/$name";
    my $child;

    if ($mode & $S_IFDIR) {
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

sub chown {
    my ($self, $uid, $gid) = @_;
    CORE::chown($uid, $gid, $self->{'path'});
}

sub chmod {
    my ($self, $mode) = @_;
    CORE::chmod($mode, $self->{'path'});
}

sub readlink {
    my ($self) = @_;
    die('Not a symlink') unless $self->{'mode'} & $S_IFLNK;

    return CORE::readlink($self->{'path'});
}

1;
