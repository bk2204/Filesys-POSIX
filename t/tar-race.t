# Copyright (c) 2013, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

use strict;
use warnings;

use Filesys::POSIX::Bits;

use Filesys::POSIX                        ();
use Filesys::POSIX::Mem                   ();
use Filesys::POSIX::Mem::Inode            ();
use Filesys::POSIX::IO::Handle            ();
use Filesys::POSIX::Userland::Tar::Header ();

use Fcntl;
use File::Temp;
use IPC::Open3;

use Test::More ( 'tests' => 5 );
use Test::Exception;
use Test::NoWarnings;


foreach my $ignore ( 0 .. 1 ) {
    my $tempdir = File::Temp->newdir;
    my $fs = Filesys::POSIX->new( Filesys::POSIX::Mem->new );
    $fs->import_module('Filesys::POSIX::Userland::Tar');
    $fs->import_module('Filesys::POSIX::Extensions');
    $fs->import_module('Filesys::POSIX::Userland::Find');

    $fs->mkdir('foo');
    $fs->symlink( 'foo', 'bar' );
    my $max_files = 2000;

    for ( 1 .. $max_files ) {
        open( my $fh, ">", "$tempdir/$_" );
        close($fh);
        $fs->map( "$tempdir/$_", "foo/$_" );
    }

    {
        pipe my ( $out, $in );

        my $pid = fork;

        if ( $pid > 0 ) {
            close($out);

            if ($ignore) {
                my $callback = sub {
                    my $file = shift;
                    is($file, "./foo/$max_files", "missing file is correctly indicated");
                };

                lives_ok {
                    $fs->tar( Filesys::POSIX::IO::Handle->new($in), { 'ignore_missing' => $callback }, "." );
                }
                "Filesys::POSIX->tar() doesn't die when file is missing";
            }
            else {
                dies_ok {
                    $fs->tar( Filesys::POSIX::IO::Handle->new($in), "." );
                }
                "Filesys::POSIX->tar() dies when file is missing";
                like $@, qr/No such file or directory/i, "dies with expected message";
            }
        }
        elsif ( $pid == 0 ) {
            close($in);

            unlink("$tempdir/$max_files");

            while ( my $len = sysread( $out, my $buf, 512 ) ) {

                # Neat!
            }

            exit 0;
        }
        elsif ( !defined $pid ) {
            die("Unable to fork(): $!");
        }
    }
}
