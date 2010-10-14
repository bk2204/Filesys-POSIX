package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub new {
    my ($class, %opts) = @_;
    my $now = time;

    return bless {
        'atime'     => $now,
        'mtime'     => $now,
        'uid'       => 0,
        'gid'       => 0,
        'mode'      => $opts{'mode'}? $opts{'mode'}: 0,
        'dev'       => $opts{'dev'},
        'rdev'      => $opts{'rdev'},
        'parent'    => $opts{'parent'}
    }, $class;
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
