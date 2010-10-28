use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 8);

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);

{
    my $fd = $fs->open('foo', $O_CREAT | $O_WRONLY);
    my $inode = $fs->fstat($fd);
    $fs->close($fd);

    $fs->link('foo', 'bar');
    ok($inode eq $fs->stat('bar'), "Filesys::POSIX->link() copies inode reference into directory entry");

    $fs->rename('bar', 'baz');
    ok($inode eq $fs->stat('baz'), "Filesys::POSIX->rename() does not modify inode reference in directory entry");

    $fs->unlink('baz');
    
    eval {
        $fs->stat('baz');
    };

    ok($@ =~ /^No such file or directory/, "Filesys::POSIX->unlink() removes reference to inode from directory entry");
    ok($inode eq $fs->stat('foo'), "Filesys::POSIX->unlink() does not actually destroy inode");

    eval {
        $fs->rmdir('foo');
    };

    ok($@ =~ /^Not a directory/, "Filesys::POSIX->rmdir() prevents removal of non-directory inodes");
}

{
    $fs->mkdir('meow');
    my $inode = $fs->stat('meow');

    ok($inode->dir, "Filesys::POSIX->mkdir() creates directory inodes in the expected manner");

    eval {
        $fs->unlink('meow');
    };

    ok($@ =~ /^Is a directory/, "Filesys::POSIX->unlink() prevents removal of directory inodes");

    $fs->rmdir('meow');

    eval {
        $fs->stat('meow');
    };

    ok($@ =~ /^No such file or directory/, "Filesys::POSIX->rmdir() actually functions");
}
