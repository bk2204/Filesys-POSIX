use strict;
use warnings;

use Filesys::POSIX;

use File::Temp qw/tempdir/;
use File::Path qw/mkpath/;

use Test::More ('tests' => 3);
use Test::Exception;

my $fs = Filesys::POSIX->new( Filesys::POSIX::Mem->new );

throws_ok {
    $fs->foo
} qr/^No module imported for method/, "Filesys::POSIX dies when unknown method is called";

dies_ok {
    $fs->import_module('Filesys::POSIX::Does::Not::Exist');
} "Filesys::POSIX->import_module() dies when passed nonexistent module";

{
    my $dir = File::Temp::tempdir(
        'CLEANUP' => 1
    );

    unshift @INC, $dir;

    mkdir("$dir/Foo");
    open(my $fh, '>', "$dir/Foo/Tar.pm");

    print {$fh} <<END;
package Foo::Tar;

sub EXPORT {
    qw/tar/;
}

1;
END

    close $fh;

    $fs->import_module('Filesys::POSIX::Userland::Tar');

    throws_ok {
        $fs->import_module('Foo::Tar');
    }
    qr/^Module Filesys::POSIX::Userland::Tar already imported/,
    "Filesys::POSIX->import_module() dies when module has existing method";

    shift @INC;
}
