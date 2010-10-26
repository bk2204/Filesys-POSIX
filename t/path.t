use Test::More ('tests' => 50);

use Filesys::POSIX::Path ();

my %TEST_DATA = (
    '.'             => {
        'full'      => '.',
        'dirname'   => '.',
        'basename'  => '.',
        'parts'     => ['.']
    },

    '..'            => {
        'full'      => '..',
        'dirname'   => '.',
        'basename'  => '..',
        'parts'     => ['..']
    },

    'meow'          => {
        'full'      => 'meow',
        'dirname'   => '.',
        'basename'  => 'meow',
        'parts'     => ['meow']
    },

    '/foo/bar/baz'  => {
        'full'      => '/foo/bar/baz',
        'dirname'   => '/foo/bar',
        'basename'  => 'baz',
        'parts'     => ['', qw/foo bar baz/]
    },

    'foo/bar/baz'   => {
        'full'      => 'foo/bar/baz',
        'dirname'   => 'foo/bar',
        'basename'  => 'baz',
        'parts'     => [qw/foo bar baz/]
    },

    '../foo/bar'    => {
        'full'      => '../foo/bar',
        'dirname'   => '../foo',
        'basename'  => 'bar',
        'parts'     => [qw/.. foo bar/]
    },

    '///borked'     => {
        'full'      => '/borked',
        'dirname'   => '/',
        'basename'  => 'borked',
        'parts'     => ['', 'borked']
    },

    './././cats'    => {
        'full'      => './cats',
        'dirname'   => '.',
        'basename'  => 'cats',
        'parts'     => ['.', 'cats']
    },

    'foo/../bar'    => {
        'full'      => 'foo/../bar',
        'basename'  => 'bar',
        'dirname'   => 'foo/..',
        'parts'     => [qw/foo .. bar/]
    },

    './foo/../bar'  => {
        'full'      => './foo/../bar',
        'basename'  => 'bar',
        'dirname'   => './foo/..',
        'parts'     => [qw/. foo .. bar/]
    }
);

foreach my $input (keys %TEST_DATA) {
    my $item = $TEST_DATA{$input};
    my $path = Filesys::POSIX::Path->new($input);

    ok($path->full eq $item->{'full'},              "Full name of '$input' should be $item->{'full'}");
    ok($path->basename eq $item->{'basename'},      "Base name of '$input' should be $item->{'basename'}");
    ok($path->dirname eq $item->{'dirname'},        "Directory name of '$input' should be $item->{'dirname'}");
    ok($path->count == scalar @{$item->{'parts'}},  "Parsed the correct number of items for '$input'");

    my $left = $path->count;
    while ($path->count) {
        $left-- if $path->pop eq pop @{$item->{'parts'}};
    }

    ok($left == 0,                                  "Each component of '$input' held internally parsed as expected");
}
