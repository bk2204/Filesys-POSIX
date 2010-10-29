use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 37);
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

    throws_ok {
        $fs->rmdir('cats')
    } qr/^No such file or directory/, "Filesys::POSIX->rmdir() dies when target does not exist in its parent";

    throws_ok {
        $fs->rmdir('/mnt')
    } qr/^Device or resource busy/, "Filesys::POSIX->rmdir() dies when removing a mount point";
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

    throws_ok {
        $fs->mkdir('meow');
        $fs->touch('meow/poo');
        $fs->rmdir('meow');
    } qr/^Directory not empty/, "Filesys::POSIX->rmdir() prevents removing populated directories";

    lives_ok {
        $fs->mkdir('cats');
        $fs->rename('cats', 'meow');
    } "Filesys::POSIX->rename() can replace empty directories with other empty directories";

    $fs->touch('foo');

    throws_ok {
        $fs->open('foo', $O_CREAT | $O_WRONLY | $O_EXCL)
    } qr/^File exists/, "Filesys::POSIX->open() prevents clobbering existing inodes with \$O_CREAT | \$O_EXCL";

    throws_ok {
        $fs->rename('meow', 'foo')
    } qr/^Not a directory/, "Filesys::POSIX->rename() prevents replacing directories with non-directories";

    throws_ok {
        $fs->rename('foo', 'meow')
    } qr/^Is a directory/, "Filesys::POSIX->rename() prevents replacing non-directories with directories";
}

{
    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
    my $fd = $fs->open('foo', $O_CREAT | $O_WRONLY, 0644);
    my $inode = $fs->fstat($fd);
    $fs->close($fd);

    $fs->mkpath('eins/zwei/drei');
    $fs->symlink('zwei', 'eins/foo');

    ok($fs->stat('eins/zwei/drei') eq $fs->lstat('eins/foo/drei'), "Filesys::POSIX->lstat() resolves symlinks in tree");

    $fs->symlink('foo', 'bar');
    my $link = $fs->lstat('bar');

    ok($inode eq $fs->stat('bar'), "Filesys::POSIX->stat() works on symlinks");
    ok($fs->readlink('bar') eq 'foo', "Filesys::POSIX->readlink() returns expected result");

    $fs->lchmod('bar', 0600);
    ok(($link->{'mode'} & $S_IPERM) == 0600, "Filesys::POSIX->lchmod() updated symlink inode's permissions properly");
    ok(($inode->{'mode'} & $S_IPERM) == 0644, "Filesys::POSIX->lchown() does not update symlink dest's permissions");

    $fs->lchown('bar', 500, 500);
    ok($link->{'uid'} == 500, "Filesys::POSIX->lchown() updated symlink uid properly");
    ok($inode->{'uid'} == 0, "Filesys::POSIX->lchown() does not update symlink dest's permissions");
    ok($link->{'gid'} == 500, "Filesys::POSIX->lchown() updated symlink gid properly");
    ok($inode->{'gid'} == 0, "Filesys::POSIX->lchown() does not update symlink dest's permissions");
}

{
    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
    my $fd = $fs->open('/foo', $O_CREAT, $S_IFDIR | 0755);
    my $inode = $fs->fstat($fd);

    $fs->fchdir($fd);
    ok($fs->getcwd eq '/foo', "Filesys::POSIX->fchdir() changes current directory when passed a directory fd");

    $fs->fchown($fd, 500, 500);
    ok($inode->{'uid'} == 500, "Filesys::POSIX->fchown() updates inode's uid properly");
    ok($inode->{'gid'} == 500, "Filesys::POSIX->fchown() updates inode's gid properly");

    $fs->fchmod($fd, 0700);
    ok(($inode->{'mode'} & $S_IPERM) == 0700, "Filesys::POSIX->fchmod() updates inode's permissions properly");
}
