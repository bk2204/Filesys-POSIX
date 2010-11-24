use strict;
use warnings;

use Filesys::POSIX ();
use Filesys::POSIX::Mem ();
use Filesys::POSIX::Bits;

use Test::More ('tests' => 2);
use Test::Exception;
use Test::NoWarnings;

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);

$fs->mkdir('foo');

my $inode = $fs->stat('foo');

throws_ok {
    $fs->{'vfs'}->statfs($inode, 'exact' => 1);
} qr/^Not mounted/, "Filesys::POSIX::VFS->statfs() complains when a non mountpoint inode is specified";
