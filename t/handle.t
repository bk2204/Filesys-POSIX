use strict;
use warnings;

use Filesys::POSIX::IO::Handle;
use Filesys::POSIX::Bits;
use File::Temp qw/mkstemp/;

use Test::More ('tests' => 6);

{
    pipe my ($fh_out, $fh_in);

    my $in  = Filesys::POSIX::IO::Handle->new($fh_in);
    my $out = Filesys::POSIX::IO::Handle->new($fh_out);

    ok($in->write('foo', 3) == 3, "Filesys::POSIX::IO::Handle->write() returns expected write length");
    ok($out->read(my $buf, 3) == 3, "Filesys::POSIX::IO::Handle->read() returns expected number of bytes");
    ok($buf eq 'foo', "Filesys::POSIX::IO::Handle->read() populated buffer with expected result");

    $in->close;
    $out->close;
}

{
    my ($fh, $file) = mkstemp('/tmp/.filesys-posix-XXXXXX');
    my $handle = Filesys::POSIX::IO::Handle->new($fh);

    $handle->write('X' x 128, 128);
    $handle->write('O' x 128, 128);

    ok($handle->seek(128, $SEEK_SET) == 128, "Filesys::POSIX::IO::Handle->seek() returns absolute byte offset");
    ok($handle->tell == 128, "Filesys::POSIX::IO::Handle->tell() returns appropriate byte offset after seek()");

    $handle->close;
    ok(!defined fileno($fh), "Filesys::POSIX::IO::Handle->close() works");

    unlink $file;
}
