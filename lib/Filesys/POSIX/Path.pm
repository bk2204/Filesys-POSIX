package Filesys::POSIX::Path;

use strict;
use warnings;

sub components {
    my ($class, $path) = @_;
    my @components = split(/\//, $path);

    my @ret = grep {
        $_ && $_ ne '.'
    } @components;

    return $components[0]? @ret: ('', @ret);
}

sub cleanup {
    my ($class, $path) = @_;

    return join '/', $class->components($path);
}

sub dirname {
    my ($class, $path) = @_;
    my @hier = $class->components($path);

    return $hier[0]? join('/', @hier[0..$#hier-1]): '/';
}

sub basename {
    my ($class, $path, $ext) = @_;
    my @hier = $class->components($path);
    my $name = $hier[$#hier];

    $name =~ s/$ext$// if $ext;

    return $name;
}

1;
