use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Real;
use Filesys::POSIX::Bits;

use File::Temp qw/mkdtemp/;
use Test::More ('tests' => 10);

my $tmpdir = mkdtemp('/tmp/.filesys-posix-XXXXXX') or die $!;

my %mounts = (
    '/mnt/mem'  => {
        'dev'   => Filesys::POSIX::Mem->new,
        'flags' => {
            'noatime'   => 1
        }
    },

    '/mnt/real' => {
        'dev'   => Filesys::POSIX::Real->new,
        'flags' => {
            'special'   => "real:$tmpdir",
            'noatime'   => 1
        }
    }
);

my %files = (
    'foo'           => 'dir',
    'foo/bar'       => 'file',
    'foo/baz'       => 'dir',
    'foo/bleh'      => 'file'
);

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
$fs->import_module('Filesys::POSIX::Extensions');
$fs->import_module('Filesys::POSIX::Userland::Find');

foreach my $mountpoint (sort keys %mounts) {
    my $mount = $mounts{$mountpoint};

    $fs->mkpath($mountpoint);
    $fs->mount($mount->{'dev'}, $mountpoint, %{$mount->{'flags'}});

    foreach (sort keys %files) {
        my $path = "$mountpoint/$_";

        if ($files{$_} eq 'file') {
            $fs->touch($path);
        } elsif ($files{$_} eq 'dir') {
            $fs->mkdir($path);
        }
    }

    my %found = (
        '.'     => 0,
        '..'    => 0,
        'bar'   => 0,
        'baz'   => 0,
        'bleh'  => 0
    );

    my $dirent = $fs->opendir("$mountpoint/foo");
    my $type = ref $dirent;

    while (my $member = $fs->readdir($dirent)) {
        $found{$member} = 1;
    }

    $fs->closedir($dirent);

    foreach (sort keys %found) {
        ok($found{$_} == 1, "$type\->readdir() found member $_");
    }
}

system qw/rm -rf/, $tmpdir;
