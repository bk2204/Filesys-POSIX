package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode;

sub new {
    my ($class) = @_;

    my $fs = bless {}, $class;

    my $root = Filesys::POSIX::Mem::Inode->new(
        'mode'      => $S_IFDIR | 0755,
        'dev'       => $fs
    );

    $fs->{'root'} = $root;

    return $fs;
}

1;
