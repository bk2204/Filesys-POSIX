use strict;
use warnings;

use Filesys::POSIX::Bits;

use Filesys::POSIX                        ();
use Filesys::POSIX::Mem                   ();
use Filesys::POSIX::Mem::Inode            ();
use Filesys::POSIX::IO::Handle            ();
use Filesys::POSIX::Userland::Tar::Header ();

use Fcntl;
use IPC::Open3;

use Test::More ( 'tests' => 22 );
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

#
# Ensure that Filesys::POSIX::Userland::Tar::Header lists a zero size for symlink inodes.
#
{
    my $fs = Filesys::POSIX->new(
        Filesys::POSIX::Mem->new,
        'noatime' => 1
    );

    $fs->symlink( 'foo', 'bar' );

    my $inode = $fs->lstat('bar');

    #
    # Fudge the inode object to reflect a nonzero size, as would occur on
    # inodes mapped in with Filesys::POSIX::Real.
    #
    $inode->{'size'} = 3;

    my $header = Filesys::POSIX::Userland::Tar::Header->from_inode( $inode, 'bar' );

    is( $header->{'size'}, 0, "File size on symlink inodes listed as 0 in header objects" );
}

#
# Ensure that Filesys::POSIX::Userland::Tar::Header splits path names correctly,
# and that it will make sure pathnames are made unique in the case of long names.
#
{
    my @TESTS = (
        {
            'path'   => 'foo',
            'prefix' => '',
            'suffix' => 'foo/',
            'mode'   => $S_IFDIR | 0755
        },

        {
            'path'   => 'foo',
            'prefix' => '',
            'suffix' => 'foo',
            'mode'   => $S_IFREG | 0644
        },

        {
            'path'   => 'foo/',
            'prefix' => '',
            'suffix' => 'foo/',
            'mode'   => $S_IFDIR | 0755
        },

        {
            'path'   => 'foo/',
            'prefix' => '',
            'suffix' => 'foo',
            'mode'   => $S_IFREG | 0644
        },

        {
            'path'   => 'foo/bar',
            'prefix' => '',
            'suffix' => 'foo/bar',
            'mode'   => $S_IFREG | 0644
        },

        {
            'path'   => 'foo/bar',
            'prefix' => '',
            'suffix' => 'foo/bar/',
            'mode'   => $S_IFDIR | 0755
        },

        {
            'path' => '/' . ( 'X' x 154 ) . '/' . ( 'O' x 100 ),
            'prefix' => '/' . ( 'X' x 154 ),
            'suffix' => 'O' x 100,
            'mode'   => $S_IFREG | 0644
        },

        {
            'path' => '/' . ( 'X' x 155 ) . '/' . ( 'O' x 101 ),
            'prefix' => '/' . ( 'X' x 147 ) . 'cba2be6',
            'suffix' => ( 'O' x 93 ) . '73b8f86',
            'mode'   => $S_IFREG | 0644
        },

        {
            'path'   => 'X' x 130,
            'prefix' => '',
            'suffix' => ( 'X' x 92 ) . '64e7d7e/',
            'mode'   => $S_IFDIR | 0755
        }
    );

    foreach my $test (@TESTS) {
        my $inode = Filesys::POSIX::Mem::Inode->new( 'mode' => $test->{'mode'} );

        my $result = Filesys::POSIX::Userland::Tar::Header::split_path_components( $test->{'path'}, $inode );

        is( $result->{'prefix'}, $test->{'prefix'}, "Prefix of '$test->{'path'}' is '$test->{'prefix'}'" );
        is( $result->{'suffix'}, $test->{'suffix'}, "Suffix of '$test->{'path'}' is '$test->{'suffix'}'" );
    }
}
