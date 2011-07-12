use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More qw/no_plan/;

my $fs = Filesys::POSIX->new( Filesys::POSIX::Mem->new,
    'noatime' => 1
);

$fs->import_module('Filesys::POSIX::Userland::Test');

$fs->mkdir('/bin');
$fs->mkdir('/dev');
$fs->mkdir('/tmp');

my %TESTS = (
    # Inode format tests
    'is_file' => {
        'init' => sub { $fs->touch(shift) },
        'test' => sub { $fs->is_file(shift) },
        'file' => '/tmp/file',
        'type' => 'regular file'
    },

    'is_dir' => {
        'init' => sub { $fs->mkdir(shift) },
        'test' => sub { $fs->is_dir(shift) },
        'file' => '/tmp/dir',
        'type' => 'directory'
    },

    'is_link' => {
        'init' => sub { $fs->symlink('foo', shift) },
        'test' => sub { $fs->is_link(shift) },
        'file' => '/tmp/link',
        'type' => 'symbolic link'
    },

    'is_char' => {
        'init' => sub { $fs->mknod(shift, $S_IFCHR | 0644, 0x0103) },
        'test' => sub { $fs->is_char(shift) },
        'file' => '/dev/null',
        'type' => 'character device'
    },

    'is_block' => {
        'init' => sub { $fs->mknod(shift, $S_IFBLK | 0644, 0x0800) },
        'test' => sub { $fs->is_block(shift) },
        'file' => '/dev/sda',
        'type' => 'block device'
    },

    'is_fifo' => {
        'init' => sub { $fs->mkfifo(shift, 0644) },
        'test' => sub { $fs->is_fifo(shift) },
        'file' => '/tmp/fifo',
        'type' => 'FIFO buffer'
    },

    # Permissions tests 
    'is_readable' => {
        'init' => sub {
            my $fd = $fs->open(shift, $O_CREAT, 0600);
            $fs->close($fd);
        },

        'test' => sub { $fs->is_readable(shift) },
        'file' => '/tmp/readable',
        'type' => 'readable file'
    },

    'is_writable' => {
        'init' => sub {
            my $fd = $fs->open(shift, $O_CREAT, 0200);
            $fs->close($fd);
        },

        'test' => sub { $fs->is_writable(shift) },
        'file' => '/tmp/writable',
        'type' => 'writable file'
    },

    'is_executable' => {
        'init' => sub {
            my $fd = $fs->open(shift, $O_CREAT, 0100);
            $fs->close($fd);
        },

        'test' => sub { $fs->is_executable(shift) },
        'file' => '/bin/sh',
        'type' => 'executable file'
    },

    'is_setuid' => {
        'init' => sub {
            my $fd = $fs->open(shift, $O_CREAT, 0644 | $S_ISUID);
            $fs->close($fd);
        },

        'test' => sub { $fs->is_setuid(shift) },
        'file' => '/tmp/setuid',
        'type' => 'setuid file'
    },

    'is_setgid' => {
        'init' => sub {
            my $fd = $fs->open(shift, $O_CREAT, 0644 | $S_ISGID);
            $fs->close($fd);
        },

        'test' => sub { $fs->is_setgid(shift) },
        'file' => '/tmp/setgid',
        'type' => 'setgid file'
    }
);

foreach my $test_name (sort keys %TESTS) {
    my $test = $TESTS{$test_name};

    my $test_file = $test->{'file'};
    my $test_type = $test->{'type'};

    $test->{'init'}->($test_file);

    my $test_result = $test->{'test'}->($test_file);

    ok( $test_result, "\$fs->$test_name returns true when given a $test_type ($test_file)" );
}
