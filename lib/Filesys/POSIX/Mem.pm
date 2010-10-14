package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode;

sub new {
    my ($class, %opts) = @_;
    my $root = Filesys::POSIX::Inode->new($S_IFDIR | 0755);

    $root->{'dirent'} = {
        '.'     => $root,
        '..'    => $root
    };

    return bless {
        'noatime'   => $opts{'noatime'},
        'first'     => $root
    }, $class;
}

1;
