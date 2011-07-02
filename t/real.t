use strict;
use warnings;

use Filesys::POSIX       ();
use Filesys::POSIX::Real ();
use Filesys::POSIX::Bits;

use File::Temp ();
use Fcntl;

use Test::More ( 'tests' => 11 );
use Test::Exception;
use Test::NoWarnings;

my $tmpdir = File::Temp::tempdir( 'CLEANUP' => 1 );

my %files = (
    'foo'          => 'file',
    'bar'          => 'dir',
    'bar/baz'      => 'dir',
    'bar/boo'      => 'dir',
    'bar/boo/cats' => 'file'
);

foreach ( sort keys %files ) {
    my $path = "$tmpdir/$_";

    if ( $files{$_} eq 'file' ) {
        sysopen( my $fh, $path, O_CREAT );
        close($fh);
    }
    elsif ( $files{$_} eq 'dir' ) {
        mkdir($path);
    }
}

my $fs = Filesys::POSIX->new(
    Filesys::POSIX::Real->new,
    'special' => "real:$tmpdir"
);

foreach ( sort keys %files ) {
    my $inode = $fs->stat($_);

    if ( $files{$_} eq 'file' ) {
        ok( $inode->file,          "Filesys::POSIX::Real sees $_ as a file" );
        ok( $inode->{'size'} == 0, "Filesys::POSIX::Real sees $_ as a 0 byte file" );
    }
    elsif ( $files{$_} eq 'dir' ) {
        ok( $inode->dir, "Filesys::POSIX::Real sees $_ as a directory" );
    }
}

throws_ok {
    Filesys::POSIX->new(
        Filesys::POSIX::Real->new,
        'special' => 'poop:'
    );
}
qr/^Invalid special path/, "Filesys::POSIX::Real->init() dies when an invalid special was passed at mount time";

throws_ok {
    Filesys::POSIX->new(
        Filesys::POSIX::Real->new,
        'special' => 'real:/dev/null'
    );
}
qr/^Not a directory/, "Filesys::POSIX::Real->init() dies when special is not a directory";

throws_ok {
    $fs->rename( 'foo', 'bleh' );
}
qr/^Operation not permitted/, "Filesys::POSIX->rename() prohibits renaming real files";
