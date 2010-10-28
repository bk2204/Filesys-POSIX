use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More qw/no_plan/;

my $mounts = {
    '/'             => Filesys::POSIX::Mem->new,
    '/mnt/mem'      => Filesys::POSIX::Mem->new,
    '/mnt/mem/tmp'  => Filesys::POSIX::Mem->new
};

my $fs = Filesys::POSIX->new($mounts->{'/'});

$fs->mkpath('/mnt/mem/hidden');

foreach (grep { $_ ne '/' } sort keys %$mounts) {
    eval {
        $fs->mkpath($_);
    };

    ok(!$@, "Able to create mount point $_");

    eval {
        $fs->mount($mounts->{$_}, $_,
            'noatime' => 1
        );
    };

    ok(!$@, "Able to mount $mounts->{$_} to $_");
}

eval {
    $fs->stat('/mnt/mem/hidden');
};

ok($@ =~ /^No such file or directory/, "Mounting /mnt/mem sweeps /mnt/mem/hidden under the rug");

{
    my $expected    = $mounts->{'/'};
    my $result      = $fs->{'root'}->{'dev'};

    ok($result eq $expected, "Filesystem root device lists $result");
}

foreach (sort keys %$mounts) {
    my $inode = $fs->stat($_);

    my $expected    = $mounts->{$_};
    my $result      = $inode->{'dev'};

    ok($result eq $expected, "$_ inode lists $result as device");

    my $mount = eval {
        $fs->statfs($_);
    };

    ok(!$@, "Filesys::POSIX->statfs('$_/') returns mount information");
    ok($mount->{'dev'} eq $expected, "Mount object for $_ lists expected device");
}

{
    eval {
        $fs->unmount('/mnt/mem');
    };

    ok($@ =~ /^Device or resource busy/, "Filesys::POSIX->unmount() prevents unmounting busy filesystem /mnt/mem");
}

{
    $fs->unmount('/mnt/mem/tmp');
    $fs->unmount('/mnt/mem');

    eval {
        $fs->stat('/mnt/mem/tmp');
    };

    ok($@ =~ /^No such file or directory/, "/mnt/mem/tmp can no longer be accessed after unmounting /mnt/mem");
}
