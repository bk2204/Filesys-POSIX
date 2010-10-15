package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode;

sub new {
    my ($class) = @_;
    my $fs = bless {}, $class;

    my $root = $fs->inode($S_IFDIR | 0755);

    $root->{'dirent'} = {
        '.'     => $root,
        '..'    => $root
    };

    $root->{'parent'}   = $root;
    $fs->{'root'}       = $root;

    return $fs;
}

sub inode {
    my ($self, $mode) = @_;

    return Filesys::POSIX::Inode->new(
        'mode'  => $mode,
        'dev'   => $self
    );
}

1;
