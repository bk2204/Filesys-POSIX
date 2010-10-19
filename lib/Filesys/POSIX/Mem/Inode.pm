package Filesys::POSIX::Mem::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub new {
    my ($class, %opts) = @_;
    my $now = time;

    my $inode = bless {
        'size'      => 0,
        'atime'     => $now,
        'mtime'     => $now,
        'ctime'     => $now,
        'uid'       => 0,
        'gid'       => 0,
        'mode'      => $opts{'mode'}? $opts{'mode'}: 0,
        'dev'       => $opts{'dev'},
        'rdev'      => $opts{'rdev'},
        'parent'    => $opts{'parent'}
    }, $class;

    if (exists $opts{'mode'} && $opts{'mode'} & $S_IFDIR) {
        $inode->{'dirent'} = Filesys::POSIX::Mem::Dirent->new(
            '.'     => $inode,
            '..'    => $opts{'parent'}? $opts{'parent'}: $inode
        );
    }

    return $inode;
}

sub child {
    my ($self, $name, $mode) = @_;

    die('Not a directory') unless $self->{'mode'} & $S_IFDIR;
    die('Invalid directory entry name') if $name =~ /\//;
    die('File exists') if $self->{'dirent'}->exists($name);

    my $child = __PACKAGE__->new(
        'mode'      => $mode,
        'dev'       => $self->{'dev'},
        'parent'    => $self
    );

    $self->{'dirent'}->{$name} = $child;

    return $child;
}

sub chown {
    my ($self, $uid, $gid) = @_;
    @{$self}{qw/uid gid/} = ($uid, $gid);
}

sub chmod {
    my ($self, $mode) = @_;
    my $format = $self->{'mode'} & $S_IFMT;
    my $perm = $mode & ($S_IPERM | $S_IPROT);

    $self->{'mode'} = $format | $perm;
}

sub readlink {
    my ($self) = @_;

    die('Not a symlink') unless $self->{'mode'} & $S_IFLNK;

    return $self->{'dest'};
}

1;
