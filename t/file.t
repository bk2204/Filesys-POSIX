use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 12);
use Test::Exception;

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);

$fs->mkdir('/mnt');
$fs->mount(Filesys::POSIX::Mem->new, '/mnt');

{
    ok($fs->stat('/..') eq $fs->{'root'}, "Filesys::POSIX->stat('/..') returns the root vnode");

    my $fd = $fs->open('foo', $O_CREAT | $O_WRONLY);
    my $inode = $fs->fstat($fd);
    $fs->close($fd);

    throws_ok {
        $fs->stat('foo/bar')
    } qr/^Not a directory/, "Filesys::POSIX->stat() will not walk a path with non-directory parent components";

    throws_ok {
        $fs->open('foo/bar', $O_CREAT | $O_WRONLY)
    } qr/^Not a directory/, "Filesys::POSIX->open() prevents attaching children to non-directory inodes";

    throws_ok {
        $fs->link('foo', '/mnt/bar')
    } qr/^Cross-device link/, "Filesys::POSIX->link() prevents cross-device links";

    $fs->link('foo', 'bar');
    ok($inode eq $fs->stat('bar'), "Filesys::POSIX->link() copies inode reference into directory entry");

    $fs->rename('bar', 'baz');
    ok($inode eq $fs->stat('baz'), "Filesys::POSIX->rename() does not modify inode reference in directory entry");

    $fs->unlink('baz');
    
    throws_ok {
        $fs->stat('baz')
    } qr/^No such file or directory/, "Filesys::POSIX->unlink() removes reference to inode from directory entry";

    ok($inode eq $fs->stat('foo'), "Filesys::POSIX->unlink() does not actually destroy inode");

    throws_ok {
        $fs->rmdir('foo')
    } qr/^Not a directory/, "Filesys::POSIX->rmdir() prevents removal of non-directory inodes";
}

{
    $fs->mkdir('meow');
    my $inode = $fs->stat('meow');

    ok($inode->dir, "Filesys::POSIX->mkdir() creates directory inodes in the expected manner");

    throws_ok {
        $fs->unlink('meow')
    } qr/^Is a directory/, "Filesys::POSIX->unlink() prevents removal of directory inodes";

    $fs->rmdir('meow');

    throws_ok {
        $fs->stat('meow')
    } qr/^No such file or directory/, "Filesys::POSIX->rmdir() actually functions";
}
