use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 9);

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);

my @parts = qw/foo bar baz/;
my @cur;
my $path = join('/', @parts);

$fs->mkpath($path, 0700);

foreach (@parts) {
    push @cur, $_;
    my $subpath = join('/', @cur);

    my $inode = $fs->stat($path);
    ok($inode->dir,           "Filesys::POSIX->mkpath('$path') created '$subpath' as a directory");
    ok($inode->perms == 0700, "Filesys::POSIX->mkpath('$path') created '$subpath' with proper permissions");
}

ok($fs->getcwd eq '/', "Filesys::POSIX->getcwd() reports '/' as current working directory by default");
$fs->chdir($path);
ok($fs->getcwd eq "/$path", "Filesys::POSIX->getcwd() reports /$path as current working directory after chdir()");

my $input       = '../../../././foo/./bar/./';
my $expected    = '/foo/bar';
my $result      = $fs->realpath($input);

ok($result eq $expected, "Filesys::POSIX->realpath('$input') reports $result (expected $expected)");
