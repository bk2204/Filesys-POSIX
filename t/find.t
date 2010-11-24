use strict;
use warnings;

use Filesys::POSIX ();
use Filesys::POSIX::Mem ();
use Filesys::POSIX::Bits;

use Test::More ('tests' => 3);
use Test::NoWarnings;

my %files = (
    '/foo'          => 'dir',
    '/foo/bar'      => 'dir',
    '/foo/bar/baz'  => 'file',
    '/foo/boo'      => 'file',
    '/bleh'         => 'dir',
    '/bleh/cats'    => 'file'
);

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
$fs->import_module('Filesys::POSIX::Userland::Find');

foreach (sort keys %files) {
    if ($files{$_} eq 'dir') {
        $fs->mkdir($_);
    } elsif ($files{$_} eq 'file') {
        $fs->touch($_);
    }
}

$fs->symlink('/bleh', '/foo/bar/meow');

{
    my $found = 0;

    $fs->find(sub {
        my ($path, $inode) = @_;
        $found++ if $files{$path->full};
    }, '/');

    ok($found == keys %files, "Filesys::POSIX->find() found each file in hierarchy");
}

{
    my %expected = (
        %files,
        '/foo/bar/meow'         => 1,
        '/foo/bar/meow/cats'    => 1
    );

    my $found = 0;

    $fs->find(sub {
        my ($path, $inode) = @_;
        $found++ if $expected{$path->full};
    }, {'follow' => 1}, '/');

    ok($found == keys %expected, "Filesys::POSIX->find() resolves and recurses into directory symlinks fine");
}
