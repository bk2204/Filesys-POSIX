use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 6);

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
$fs->umask(022);

my $fd = $fs->open('foo', $O_CREAT, 0600);
ok($fd == 3, 'Filesys::POSIX->open() for new file returns file descriptor 3 upon first call');
ok($fs->fstat($fd)->file, 'Filesys::POSIX->open() creates regular inode by default with $O_CREAT');
ok($fs->fstat($fd)->perms == 0600, 'Filesys::POSIX->open() handles mode argument appropriately');

my $new_fd = $fs->open('bar', $O_CREAT);
ok($new_fd == 4, 'Filesys::POSIX->open() for second new file returns file descriptor 4');
$fs->close($fd);
ok($fs->open('bar', $O_RDONLY) == 3, 'Filesys::POSIX->close(), open() reclaims old file descriptors');
$fs->close($fd);

eval {
    $fs->read($fd, my $buf, 512);
};

ok($@ =~ /^Invalid file descriptor/, 'Filesys::POSIX->read() throws "Invalid file descriptor" exception on closed fd');
