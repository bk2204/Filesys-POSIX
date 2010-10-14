package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub new {
    my ($class, $mode) = @_;
    my $now = time;

    return bless {
        'atime' => $now,
        'mtime' => $now,
        'uid'   => 0,
        'gid'   => 0,
        'mode'  => $mode? $mode: 0
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

1;
