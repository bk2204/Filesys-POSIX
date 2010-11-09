use strict;
use warnings;

use Filesys::POSIX ();
use Filesys::POSIX::Mem ();
use Filesys::POSIX::Real ();
use Filesys::POSIX::Bits;

use File::Temp qw/mkdtemp/;
use Test::More ('tests' => 6);

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

    my %members = (
        '.'     => 1,
        '..'    => 1,
        'bar'   => 1,
        'baz'   => 1,
        'bleh'  => 1
    );

    {
        my $dirent = $fs->opendir("$mountpoint/foo");
        my $type = ref $dirent;
        my $found = 0;

        while (my $member = $fs->readdir($dirent)) {
            $found++ if $members{$member};
        }

        $fs->closedir($dirent);

        ok($found == keys %members, "$type\->readdir() found each member");
    }

    {
        my $dirent = $fs->opendir("$mountpoint/foo");
        my $type = ref $dirent;
        my $found = 0;

        foreach ($fs->readdir($dirent)) {
            $found++ if $members{$_};
        }

        $fs->closedir($dirent);

        ok($found == keys %members, "$type\->readdir() returned each member in list context");
    }

    {
        my $dirent = $fs->stat("$mountpoint/foo")->dirent;
        my $type = ref $dirent;
        my $found = 0;

        foreach ($dirent->list) {
            $found++ if $members{$_};
        }

        ok($found == keys %members, "$type\->list() found each member");
    }
}

system qw/rm -rf/, $tmpdir;
