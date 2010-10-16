package Filesys::POSIX::Real;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

sub new {
    my ($class, $path) = @_;

    my $fs = bless {
        'path' => $path
    }, $class;

    my $root = Filesys::POSIX::Real::Inode->new($path,
        'dev' => $fs
    );

    die('Not a directory') unless $root->{'mode'} & $S_IFDIR;

    $fs->{'root'} = $root;

    return $fs;
}

1;
