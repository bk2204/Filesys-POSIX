use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 20);
use Test::Exception;


{
    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);

    $fs->mkdir('/mnt');
    $fs->mount(Filesys::POSIX::Mem->new, '/mnt');

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

    lives_ok {
        $fs->link('bar', 'eins');
        $fs->rename('eins', 'bar');
    } "Filesys::POSIX->rename() can replace non-directory entries with other non-directory entries";

    throws_ok {
        $fs->link('foo', 'bar')
    } qr/^File exists/, "Filesys::POSIX->link() dies when destination already exists";

    $fs->rename('bar', 'baz');
    ok($inode eq $fs->stat('baz'), "Filesys::POSIX->rename() does not modify inode reference in directory entry");

    throws_ok {
        $fs->rename('baz', '/mnt/boo')
    } qr/^Cross-device link/, "Filesys::POSIX->rename() dies whe renaming inodes across different devices";

    $fs->unlink('baz');

    throws_ok {
        $fs->stat('baz')
    } qr/^No such file or directory/, "Filesys::POSIX->unlink() removes reference to inode from directory entry";

    throws_ok {
        $fs->unlink('baz')
    } qr/^No such file or directory/, "Filesys::POSIX->unlink() dies when its target does not exist";
    
    ok($inode eq $fs->stat('foo'), "Filesys::POSIX->unlink() does not actually destroy inode");

    throws_ok {
        $fs->rmdir('foo')
    } qr/^Not a directory/, "Filesys::POSIX->rmdir() prevents removal of non-directory inodes";
}

{
    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
    $fs->mkdir('meow');

    my $inode = $fs->stat('meow');

    ok($inode->dir, "Filesys::POSIX->mkdir() creates directory inodes in the expected manner");

    throws_ok {
        $fs->unlink('meow')
    } qr/^Is a directory/, "Filesys::POSIX->unlink() prevents removal of directory inodes";

    throws_ok {
        $fs->link('meow', 'cats')
    } qr/^Is a directory/, "Filesys::POSIX->link() prevents linking of directory inodes";

    throws_ok {
        $fs->rmdir('meow');
        $fs->stat('meow');
    } qr/^No such file or directory/, "Filesys::POSIX->rmdir() actually functions";

    lives_ok {
        $fs->mkdir('cats');
        $fs->rename('cats', 'meow');
    } "Filesys::POSIX->rename() can replace empty directories with other empty directories";

    $fs->touch('foo');

    throws_ok {
        $fs->rename('meow', 'foo')
    } qr/^Not a directory/, "Filesys::POSIX->rename() prevents replacing directories with non-directories";

    throws_ok {
        $fs->rename('foo', 'meow')
    } qr/^Is a directory/, "Filesys::POSIX->rename() prevents replacing non-directories with directories";
}
