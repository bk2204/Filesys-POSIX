use strict;
use warnings;

use Filesys::POSIX::FdTable ();

use Test::More ( 'tests' => 2 );
use Test::Exception;
use Test::NoWarnings;

package Dummy::Inode;

sub new {
    bless {}, shift;
}

sub open {
    return 0;
}

package main;

my $fds = Filesys::POSIX::FdTable->new;

throws_ok {
    $fds->open( Dummy::Inode->new, 0 );
}
qr/^Unable to open device-specific file handle/, "Filesys::POSIX::FdTable->open() dies when \$inode->open() fails";
