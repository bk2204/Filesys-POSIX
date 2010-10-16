package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode;
use Filesys::POSIX::Mem::Dirent;

sub new {
    my ($class) = @_;

    my $fs = bless {}, $class;
    $fs->{'root'} = $fs->inode($S_IFDIR | 0755);

    return $fs;
}

sub inode {
    my ($self, $mode, $parent) = @_;

    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'      => $mode,
        'dev'       => $self,
        'parent'    => $parent
    );

    if ($mode & $S_IFDIR) {
        $inode->{'dirent'} = Filesys::POSIX::Mem::Dirent->new(
            '.'     => $inode,
            '..'    => $parent? $parent: $inode
        );
    }

    return $inode;
}

1;
