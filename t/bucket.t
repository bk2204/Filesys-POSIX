use strict;
use warnings;

use Filesys::POSIX::Mem;
use Filesys::POSIX::Mem::Inode;
use Filesys::POSIX::Mem::Bucket;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 11);

{
    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'  => 0644,
        'dev'   => Filesys::POSIX::Mem->new
    );

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'inode' => $inode,
        'max'   => 0
    );

    ok($bucket->write('foo', 3) == 3, "Filesys::POSIX::Mem::Bucket->write() returns expected write length");

    my ($file, $handle) = @{$bucket}{qw/file fh/};

    ok(-f $file, "Filesys::POSIX::Mem::Bucket->write() flushes to disk immediately with a max of 0");
    ok($bucket->seek(0, $SEEK_SET) == 0, "Filesys::POSIX::Mem::Bucket->seek() functions and returns expected offset");
    ok($bucket->read(my $buf, 3) == 3, "Filesys::POSIX::Mem::Bucket->read() reports expected read length");
    ok($buf eq 'foo', "Filesys::POSIX::Mem::Bucket->read() populated buffer with expected contents");
    ok($bucket->tell == 3, "Filesys::POSIX::Mem::Bucket->tell() reports expected offset");
    ok($bucket->seek(0, $SEEK_CUR) == 3, "Filesys::POSIX::Mem::Bucket->seek(0, \$SEEK_CUR) operates expectedly");
    ok($bucket->seek(3, $SEEK_CUR) == 6, "Filesys::POSIX::Mem::Bucket->seek(3, \$SEEK_CUR) operates expectedly");

    $bucket->close;

    ok(!defined fileno($handle), "Filesys::POSIX::Mem::Bucket->close() closes internal file handle");
    ok(!defined $bucket->{'fh'}, "Filesys::POSIX::Mem::Bucket->close() destroys internal file handle");

    undef $bucket;

    ok(!-f $file, "Filesys::POSIX::Mem::Bucket->DESTROY() reclaims disk file");
}
