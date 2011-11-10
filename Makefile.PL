use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Filesys::POSIX',
    'VERSION_FROM' => 'lib/Filesys/POSIX.pm',
    'AUTHOR'       => 'Erin Schoenhals <erin@cpanel.net>',
    'LICENSE'      => 'perl',
    'ABSTRACT'     => 'Provides POSIX filesystem semantics in pure Perl',

    'PREREQ_PM' => {
        'Carp'        => 0,
        'Digest::SHA' => 0
    },

    'BUILD_REQUIRES' => {
        'Test::Simple'     => '0.44',
        'Test::Exception'  => '0.26',
        'Test::NoWarnings' => '0.081'
    }
);
