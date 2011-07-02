use strict;
use warnings;

use Filesys::POSIX::FdTable ();

use Test::More ( 'tests' => 3 );
use Test::Exception;
use Test::NoWarnings;

package Dummy::Inode;

sub new {
    bless {}, shift;
}

sub open {
    my ( $self, $flags ) = @_;

    return $flags ? 'OK' : undef;
}

package main;

my $fds = Filesys::POSIX::FdTable->new;

lives_ok {
    $fds->open( Dummy::Inode->new, 1 );
}
'Filesys::POSIX::FdTable->open() returns a file handle opened by inode object';

throws_ok {
    $fds->open( Dummy::Inode->new, 0 );
}
qr/^Unable to open device-specific file handle/, "Filesys::POSIX::FdTable->open() dies when \$inode->open() fails";
