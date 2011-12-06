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

use Test::More ( 'tests' => 75 );
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
            'suffix' => ( 'O' x 93 ) . 'cba2be6',
            'mode'   => $S_IFREG | 0644
        },

        {
            'path'   => 'X' x 130,
            'prefix' => '',
            'suffix' => ( 'X' x 92 ) . 'da39a3e/',
            'mode'   => $S_IFDIR | 0755
        }
    );

    foreach my $test (@TESTS) {
        my $inode = Filesys::POSIX::Mem::Inode->new( 'mode' => $test->{'mode'} );
        my $parts = Filesys::POSIX::Path->new( $test->{'path'} );

        my $result = Filesys::POSIX::Userland::Tar::Header::split_path_components( $parts, $inode );

        is( $result->{'prefix'}, $test->{'prefix'}, "Prefix of '$test->{'path'}' is '$test->{'prefix'}'" );
        is( $result->{'suffix'}, $test->{'suffix'}, "Suffix of '$test->{'path'}' is '$test->{'suffix'}'" );
    }
}

#
# Ensure that Filesys::POSIX::Userland::Tar::Header GNU extensions work; test
# the LongLink extension functionality, in particular.
#
{
    my $fs = Filesys::POSIX->new(
        Filesys::POSIX::Mem->new,
        'noatime' => 1
    );

    $fs->mkpath('foo/bar/baz');

    {
        my $path   = 'foo/bar/baz/' . ( 'meow' x 70 );
        my $inode  = $fs->mkpath($path);
        my $header = Filesys::POSIX::Userland::Tar::Header->from_inode( $inode, $path );

        ok( $header->{'path'} =~ /\/$/, "$path ends with a / in header object" );
        is( substr( $header->encode_gnu, 0, 13 ), '././@LongLink', "GNU tar header for $path contains proper path" );
    }

    {
        my $path   = 'foo/bar/baz/' . ( 'bleh' x 70 );
        my $inode  = $fs->touch($path);
        my $header = Filesys::POSIX::Userland::Tar::Header->from_inode( $inode, $path );

        ok( $header->{'path'} !~ /\/$/, "$path does not end with a / in header object" );
    }
}

#
# Test every field in the tar header for correctness, for a variety of inode
# types.
#
{
    my $fs = Filesys::POSIX->new(
        Filesys::POSIX::Mem->new,
        'noatime' => 1
    );

    my %FIELDS = (
        'path'          => [ 0,   100, 'filename (UStar suffix)' ],
        'mode'          => [ 100, 8,   'mode' ],
        'uid'           => [ 108, 8,   'uid' ],
        'gid'           => [ 116, 8,   'gid' ],
        'size'          => [ 124, 12,  'size' ],
        'type'          => [ 156, 1,   'link type' ],
        'dest'          => [ 157, 100, 'symlink destination' ],
        'ustar'         => [ 257, 6,   'UStar magic' ],
        'ustar_version' => [ 263, 2,   'UStar version' ],
        'user'          => [ 265, 32,  'owner username' ],
        'group'         => [ 297, 32,  'owner group name' ],
        'major'         => [ 329, 8,   'device major number' ],
        'minor'         => [ 337, 8,   'device minor number' ],
        'prefix'        => [ 345, 155, 'ustar filename prefix' ]
    );

    my @TESTS = (
        {
            'path' => 'foo',
            'type' => 'regular file',

            'setup' => sub {
                my ($path) = @_;

                my $fd = $fs->open( $path, $O_CREAT | $O_WRONLY );
                $fs->fchmod( $fd, 0644 );
                $fs->print( $fd, "bar\n" );
                $fs->close($fd);

                return $fs->lstat($path);
            },

            'expected' => {
                'path'          => 'foo',
                'mode'          => '0000644',
                'uid'           => '0000000',
                'gid'           => '0000000',
                'size'          => '00000000004',
                'type'          => '0',
                'dest'          => '',
                'ustar'         => 'ustar',
                'ustar_version' => '00',
                'user'          => '',
                'group'         => '',
                'major'         => '',
                'minor'         => '',
                'prefix'        => ''
            }
        },

        {
            'path' => 'bar',
            'type' => 'symbolic link',

            'setup' => sub {
                my ($path) = @_;
                $fs->symlink( 'foo', $path );
                return $fs->lstat($path);
            },

            'expected' => {
                'path'          => 'bar',
                'mode'          => '0000755',
                'uid'           => '0000000',
                'gid'           => '0000000',
                'size'          => '00000000000',
                'type'          => '2',
                'dest'          => 'foo',
                'ustar'         => 'ustar',
                'ustar_version' => '00',
                'user'          => '',
                'group'         => '',
                'major'         => '',
                'minor'         => '',
                'prefix'        => ''
            }
        },

        {
            'path' => 'baz/boo/' . ( 'meow' x 70 ),
            'type' => 'GNU long filename',

            'setup' => sub {
                my ($path) = @_;
                $fs->mkpath($path);
                return $fs->lstat($path);
            },

            'expected' => {
                'path'          => '././@LongLink',
                'mode'          => '0000000',
                'uid'           => '0000000',
                'gid'           => '0000000',
                'size'          => '00000000441',
                'type'          => 'L',
                'dest'          => '',
                'ustar'         => 'ustar',
                'ustar_version' => '00',
                'user'          => '',
                'group'         => '',
                'major'         => '',
                'minor'         => '',
                'prefix'        => ''
            },

            'values' => [
                [ 512, 288, 'baz/boo/' . ( 'meow' x 70 ) ],
                [ 1024, 100, ( 'meow' x 23 ) . '01658e3/' ],
                [ 1124, 8,   '0000755' ],
                [ 1132, 8,   '0000000' ],
                [ 1140, 8,   '0000000' ],
                [ 1148, 12,  '00000000000' ],
                [ 1180, 1,   '5' ],
                [ 1369, 155, 'baz/boo' ]
            ]
        }
    );

    foreach my $test (@TESTS) {
        my $type   = $test->{'type'};
        my $path   = $test->{'path'};
        my $inode  = $test->{'setup'}->($path);
        my $header = Filesys::POSIX::Userland::Tar::Header->from_inode( $inode, $path );
        my $block  = $header->encode_gnu;

        foreach my $field ( sort keys %{ $test->{'expected'} } ) {
            my $offset = $FIELDS{$field}->[0];
            my $len    = $FIELDS{$field}->[1];
            my $label  = $FIELDS{$field}->[2];

            my $expected = $test->{'expected'}->{$field};
            my $found = unpack( 'Z*', substr( $block, $offset, $len ) );

            is( $found, $expected, "$type: $label correct in $len-byte field at offset $offset in header" );
        }

        if ( $test->{'values'} ) {
            foreach my $value ( @{ $test->{'values'} } ) {
                my $offset = $value->[0];
                my $len    = $value->[1];

                my $expected = $value->[2];
                my $found = unpack( 'Z*', substr( $block, $offset, $len ) );

                is( $found, $expected, "$type: Correct value in $len-byte field at offset $offset in header" );
            }
        }
    }
}
