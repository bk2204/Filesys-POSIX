package Filesys::POSIX::Real::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Real::Dirent;

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

sub chown {
    my ($self, $uid, $gid) = @_;
    chown($self->{'path'}, $uid, $gid);
}

sub chmod {
    my ($self, $mode) = @_;
    chmod($self->{'path'}, $mode);
}

sub readlink {
    my ($self) = @_;
    die('Not a symlink') unless $self->{'mode'} & $S_IFLNK;
    
    return readlink($self->{'path'});
}

1;
