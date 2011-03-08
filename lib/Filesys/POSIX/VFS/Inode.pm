package Filesys::POSIX::VFS::Inode;

use strict;
use warnings;

sub new {
    my ( $class, $mountpoint, $root ) = @_;

    return bless {
        %$root,
        'parent' => $mountpoint->{'parent'}
      },
      ref $root;
}

1;
