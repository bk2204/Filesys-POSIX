use strict;
use warnings;

use Filesys::POSIX::Mem;
use Filesys::POSIX::Mem::Inode;
use Filesys::POSIX::Mem::Bucket;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 29);
use Test::Exception;

{
    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'  => 0644,
        'dev'   => Filesys::POSIX::Mem->new
    );

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'inode' => $inode,
        'max'   => 0,
        'dir'   => '.'
    );

    $bucket->open($O_RDWR);

    ok($bucket->write('foo', 3) == 3, "Filesys::POSIX::Mem::Bucket->write() returns expected write length");

    throws_ok {
        $bucket->_flush_to_disk(3)
    } qr/^Already flushed to disk/, "Filesys::POSIX::Mem::Bucket->_flush_to_disk() cannot be repeated";

    my ($file, $handle) = @{$bucket}{qw/file fh/};

    ok(-f $file, "Filesys::POSIX::Mem::Bucket->write() flushes to disk immediately with a max of 0");
    ok($bucket->seek(0, $SEEK_SET) == 0, "Filesys::POSIX::Mem::Bucket->seek() functions and returns expected offset");
    ok($bucket->read(my $buf, 3) == 3, "Filesys::POSIX::Mem::Bucket->read() reports expected read length");
    ok($buf eq 'foo', "Filesys::POSIX::Mem::Bucket->read() populated buffer with expected contents");
    ok($bucket->tell == 3, "Filesys::POSIX::Mem::Bucket->tell() reports expected offset");
    ok($bucket->seek(0, $SEEK_CUR) == 3, "Filesys::POSIX::Mem::Bucket->seek(0, \$SEEK_CUR) operates expectedly");
    ok($bucket->seek(3, $SEEK_CUR) == 6, "Filesys::POSIX::Mem::Bucket->seek(3, \$SEEK_CUR) operates expectedly");

    throws_ok {
        $bucket->open(0);
    } qr/^Already opened/, "Filesys::POSIX::Mem::Bucket->open() will throw 'Already opened' when appropriate";

    $bucket->close;

    ok(!defined fileno($handle), "Filesys::POSIX::Mem::Bucket->close() closes internal file handle");
    ok(!defined $bucket->{'fh'}, "Filesys::POSIX::Mem::Bucket->close() destroys internal file handle");

    $bucket->open($O_APPEND);
    ok($bucket->{'pos'} == $bucket->{'size'}, "Filesys::POSIX::Mem::Bucket->open() honors \$O_APPEND");

    $bucket->close;
    $bucket->open($O_TRUNC);
    ok($bucket->{'pos'} == 0 && $bucket->{'size'} == 0, "Filesys::POSIX::Mem::Bucket->open() honors \$O_TRUNC");

    undef $bucket;

    ok(!-f $file, "Filesys::POSIX::Mem::Bucket->DESTROY() reclaims disk file");
}

{
    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'  => 0644,
        'dev'   => Filesys::POSIX::Mem->new
    );

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'inode' => $inode,
        'max'   => 0,
        'dir'   => '.'
    );

    $bucket->write('foo', 3);

    my ($file, $handle) = @{$bucket}{qw/file fh/};
    undef $bucket;

    ok(!-f $file && !defined fileno($handle), "Filesys::POSIX::Mem::Bucket->DESTROY() calls close()");
}

{
    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'  => 0644,
        'dev'   => Filesys::POSIX::Mem->new
    );

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'inode' => $inode,
        'max'   => 0,
        'dir'   => '.'
    );

    $bucket->write('foo', 3);

    my ($file, $handle) = @{$bucket}{qw/file fh/};

    undef $bucket->{'file'};
    $bucket->close;

    ok(-f $file && !defined fileno($handle), "Filesys::POSIX::Mem::Bucket->close() only removes file it references");

    unlink($file);
}

{
    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'  => 0644,
        'dev'   => Filesys::POSIX::Mem->new
    );

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'inode' => $inode,
        'max'   => 0,
        'dir'   => '.'
    );

    $bucket->write('foo', 3);

    my ($file, $handle) = @{$bucket}{qw/file fh/};

    $bucket->close;
    unlink($file);

    throws_ok {
        $bucket->open;
    } qr/^Unable to reopen bucket/, "Filesys::POSIX::Mem::Bucket->open() will die when reopening missing bucket";
}

{
    my $inode = Filesys::POSIX::Mem::Inode->new(
        'mode'  => 0644,
        'dev'   => Filesys::POSIX::Mem->new
    );

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'inode' => $inode
    );

    $bucket->write('foo', 3);
    $bucket->close;
    $bucket->open($O_TRUNC);

    ok(
        $bucket->{'size'} == 0 && $bucket->{'pos'} == 0 && $inode->{'size'} == 0,
        "Filesys::POSIX::Mem::Bucket->open() respects \$O_TRUNC on memory buckets"
    );
}

{
    my $uid = $<;

    if ($uid == 0) {
        $> = (getpwnam 'nobody')[2];
    }

    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'dir'   => '/',
        'max'   => 0
    );

    dies_ok {
        $bucket->write('foo', 3)
    } "Filesys::POSIX::Mem::Bucket->_flush_to_disk() dies on bad mkstemp()";

    if ($uid == 0) {
        $> = $uid;
    }
}

{
    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'max' => 1024
    );

    foreach (1..192) {
        $bucket->write('meowcats', 8);
    }

    ok($bucket->{'size'} == 192 * 8, "Filesys::POSIX::Mem::Bucket->_flush_to_disk() flushes when size exceeds max");

    {
        my $read = 0;

        $bucket->seek(0, $SEEK_SET);

        while (my $len = $bucket->read(my $buf, 8)) {
            $read += $len if $buf eq 'meowcats';
        }

        ok($read == 192 * 8, "Filesys::POSIX::Mem::Bucket->read() fetches bucket data correctly after seek(0, 0)");
    }

    {
        $bucket->seek(0, $SEEK_SET);

        ok(
          $bucket->read(my $buf, 192 * 9) == 192 * 8,
          "Filesys::POSIX::Mem::Bucket->read() restricts read max to position, minus size"
        );
    }

    close($bucket->{'fh'});

    throws_ok {
        $bucket->read(my $buf, 3);
    } qr/^Unable to read bucket/, "Filesys::POSIX::Mem::Bucket->read() will die if sysread() dies";

    throws_ok {
        $bucket->write('foo', 3);
    } qr/^Unable to write to disk bucket/, "Filesys::POSIX::Mem::Bucket->write() will die if syswrite() dies";
}

{
    my $bucket = Filesys::POSIX::Mem::Bucket->new(
        'max' => 1024
    );

    $bucket->open($O_RDWR);
    $bucket->seek(2048, $SEEK_SET);

    ok(
        $bucket->read(my $buf, 3) == 0,
        "Filesys::POSIX::Mem::Bucket->read() returns 0 when reading beyond size in memory buckets"
    );

    ok(
        $bucket->seek(2048, $SEEK_END) == 2048,
        "Filesys::POSIX::Mem::Bucket->seek() with \$SEEK_END works properly"
    );

    ok($bucket->seek(2048, $SEEK_CUR) == 4096,
        "Filesys::POSIX::Mem::Bucket->seek() with \$SEEK_CUR works properly"
    );

    throws_ok {
        $bucket->seek(2048, 0x04)
    } qr/^Invalid argument/, "Filesys::POSIX::Mem::Bucket->seek() will die with 'Invalid argument' when appropriate";
}
