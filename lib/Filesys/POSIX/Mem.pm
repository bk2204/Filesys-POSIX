package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode;

sub new {
    my ($class, %opts) = @_;
    my $fs = bless \%opts, $class;

    my $root = Filesys::POSIX::Inode->new(
        'mode'  => $S_IFDIR | 0755,
        'dev'   => $fs
    );

    $root->{'dirent'} = {
        '.'     => $root,
        '..'    => $root
    };

    $root->{'parent'} = $root;

    $fs->{'root'} = $root;

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
