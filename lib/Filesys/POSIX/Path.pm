package Filesys::POSIX::Path;

use strict;
use warnings;

use Carp;

sub new {
    my ($class, $path) = @_;
    my @components = split(/\//, $path);
    my @ret;

    if (@components && $components[0]) {
        push @ret, $components[0];
    }

    if (@components > 1) {
        push @ret, grep {
            $_ && $_ ne '.'
        } @components[1..$#components]
    }

    confess('Empty path') unless @components || $path;

    my @hier = $components[0]? @ret: ('', @ret);

    if (@hier == 0) {
        @hier = ('.');
    } elsif (@hier == 1 && !$hier[0]) {
        @hier = ('/');
    }

    return bless \@hier, $class;
}

sub _proxy {
    my ($context, @args) = @_;

    unless (ref $context eq __PACKAGE__) {
        return $context->new(@args);
    }

    return $context;
}

sub components {
    my $self = _proxy(@_);

    return @$self;
}

sub full {
    my $self = _proxy(@_);
    my @hier = @$self;

    return join('/', @$self);
}

sub dirname {
    my $self = _proxy(@_);
    my @hier = @$self;

    if (scalar @hier > 1) {
        my @parts = @hier[0..$#hier-1];

        if (@parts == 1 && !$parts[0]) {
            return '/';
        }

        return join('/', @parts);
    } elsif (@hier == 1 && $hier[0] eq '/') {
        return '/'
    }

    return '.';
}

sub basename {
    my ($self, $ext) = (_proxy(@_[0..1]), $_[2]);
    my @hier = @$self;

    my $name = $hier[$#hier];
    $name =~ s/$ext$// if $ext;

    return $name;
}

sub shift {
    my ($self) = @_;
    return shift @$self;
}

sub push {
    my ($self, @parts) = @_;
    return push @$self, map { split /\// } @parts;
}

sub concat {
    my ($self, $path) = @_;
    $path = __PACKAGE__->new($path) unless ref $path eq __PACKAGE__;
    
    $path->push(grep { $_ } $self->components);
    return $path;
}

sub append {
    my ($self, $path) = @_;
    $path = __PACKAGE__->new($path) unless ref $path eq __PACKAGE__;

    $self->push(grep { $_ } $path->components);
    return $self;
}

sub pop {
    my ($self) = @_;
    return pop @$self;
}

sub count {
    my ($self) = @_;
    return scalar @$self;
}

1;
