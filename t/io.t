use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 23);

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
$fs->umask(022);

{
    my $fd = $fs->open('foo', $O_CREAT, 0600);

    ok($fd == 3, 'Filesys::POSIX->open() for new file returns file descriptor 3 upon first call');
    ok($fs->fstat($fd)->file, 'Filesys::POSIX->open() creates regular inode by default with $O_CREAT');
    ok($fs->fstat($fd)->perms == 0600, 'Filesys::POSIX->open() handles mode argument appropriately');

    my $new_fd = $fs->open('bar', $O_CREAT);

    ok($new_fd == 4, 'Filesys::POSIX->open() for second new file returns file descriptor 4');
    $fs->close($fd);

    ok($fs->open('bar', $O_RDONLY) == 3, 'Filesys::POSIX->open() reclaims old file descriptors');
    $fs->close($fd);

    eval {
        $fs->read($fd, my $buf, 512);
    };

    ok(
        $@ =~ /^Invalid file descriptor/,
        'Filesys::POSIX->read() throws "Invalid file descriptor" exception on closed fd'
    );

    $fs->close($fd);
    $fs->close($new_fd);
}

{
    my $fd    = $fs->open('baz', $O_CREAT, $S_IFDIR);
    my $inode = $fs->fstat($fd);

    ok($inode->dir, 'Filesys::POSIX->open() allows for creation of directory inodes when passing $S_IFDIR');
    ok($inode->perms == 0755, 'Filesys::POSIX->open() provides default permissions when only a format is specified');

    $fs->close($fd);
}

{
    my $fd = $fs->open('meow', $O_CREAT | $O_RDWR);

    ok($fs->tell($fd) == 0, 'Filesys::POSIX->tell() reports position 0 on newly-created files');
    ok($fs->write($fd, 'foo', 3) == 3, 'Filesys::POSIX->write() returns 3 for a 3-byte write operation');
    ok($fs->tell($fd) == 3, 'Filesys::POSIX->tell() reports offset 3 after first 3-byte write operation');

    $fs->write($fd, 'bar', 3);
    ok($fs->tell($fd) == 6, 'Filesys::POSIX->tell() reports offset 6 after second 3-byte write operation');

    ok($fs->seek($fd, 0, $SEEK_SET) == 0, 'Filesys::POSIX->seek() returns 0 when seeking to position 0');
    ok($fs->seek($fd, 3, $SEEK_SET) == 3, 'Filesys::POSIX->seek() returns 3 when seeking to position 3');

    ok($fs->read($fd, my $buf, 3) == 3, 'Filesys::POSIX->read() returns 3 when reading 3 bytes');
    ok($fs->tell($fd) == 6, 'Filesys::POSIX->tell() returns 6 after previous read() call');
    ok($buf eq 'bar', 'Filesys::POSIX->read() populated read buffer with expected result');

    ok($fs->seek($fd, 9, $SEEK_SET) == 9, 'Filesys::POSIX->seek() allows seeking beyond file size');
    ok($fs->write($fd, 'baz', 3) == 3, 'Filesys::POSIX->write() allows random access writes');
    ok($fs->fstat($fd)->{'size'} == 12, 'Filesys::POSIX->write() updated inode size to 12 bytes');
    ok($fs->seek($fd, 0, $SEEK_SET) == 0, 'Filesys::POSIX->seek() allows seeking to beginning of file');
    ok($fs->read($fd, $buf, 12) == 12, 'Filesys::POSIX->read() read expected number of bytes');
    ok($buf eq "foobar\x00\x00\x00baz", 'Filesys::POSIX->read() populated buffer with expected results');
}
