use strict;
use warnings;

use Filesys::POSIX             ();
use Filesys::POSIX::Mem        ();
use Filesys::POSIX::IO::Handle ();
use Filesys::POSIX::Bits;

use Fcntl;
use IPC::Open3;

use Test::More ( 'tests' => 4 );
use Test::Exception;
use Test::NoWarnings;

my $fs = Filesys::POSIX->new( Filesys::POSIX::Mem->new );
$fs->import_module('Filesys::POSIX::Userland::Tar');

$fs->mkdir('foo');
$fs->symlink( 'foo', 'bar' );

my $fd = $fs->open( 'foo/baz', $O_CREAT | $O_WRONLY );

foreach ( 1 .. 128 ) {
    $fs->write( $fd, 'foobarbaz', 9 );
}

$fs->close($fd);

$fd = $fs->open( 'foo/poop', $O_CREAT | $O_WRONLY );

$fs->write( $fd, 'X' x 256, 256 );
$fs->write( $fd, 'O' x 256, 256 );

$fs->close($fd);

#
# Make a really deep and annoying directory structure.
#
{
    my @parts = qw(
      asifyoucouldnottell thisissupposedtobe areallydeepdirectorystructure whichpushesthelimits ofthefilelength toa
      ratherbignumber soasyoucantelliamjustmaking crapupasi go along
    );

    $fs->mkpath( join( '/', @parts ) );
}

{
    pipe my ( $out, $in );

    my $pid = fork;

    if ( $pid > 0 ) {
        close($out);

        lives_ok {
            $fs->tar( Filesys::POSIX::IO::Handle->new($in), '.' );
        }
        "Filesys::POSIX->tar() doesn't seem to vomit";
    }
    elsif ( $pid == 0 ) {
        close($in);

        while ( my $len = sysread( $out, my $buf, 512 ) ) {

            # Neat!
        }

        exit 0;
    }
    elsif ( !defined $pid ) {
        die("Unable to fork(): $!");
    }
}

#
# Test tar()'s unwillingness to handle paths greater than 255 characters long.
#
{
    my $fs = Filesys::POSIX->new( Filesys::POSIX::Mem->new );
    $fs->import_module('Filesys::POSIX::Userland::Tar');

    my $path_a = 'a' x 128;
    my $path_b = 'b' x 128;

    $fs->mkpath("$path_a/$path_b");

    sysopen( my $fh, '/dev/null', O_WRONLY );

    throws_ok {
        $fs->tar( Filesys::POSIX::IO::Handle->new($fh), '.' );
    }
    qr/^Filename too long/, "Filesys::POSIX->tar() dies on filenames that are too long";

    close($fh);
}

#
# Test tar()'s output with the system tar(1).
#
{
    my $tar_pid = open3( my ( $in, $out, $error ), qw/tar tf -/ ) or die("Unable to spawn tar: $!");
    my $pid = fork;

    if ( $pid > 0 ) {
        close($in);

        while ( sysread( $out, my $buf, 512 ) ) {

            # Discard
        }

        waitpid( $pid, 0 );

        ok( $? == 0, "Filesys::POSIX->tar() outputs archive data in a format readable by system tar(1)" );
    }
    elsif ( $pid == 0 ) {
        close($out);
        $fs->tar( Filesys::POSIX::IO::Handle->new($in), '.' );

        exit 0;
    }
    elsif ( !defined $pid ) {
        die("Unable to fork(): $!");
    }
}
