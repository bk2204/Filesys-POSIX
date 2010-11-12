use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'Filesys::POSIX',
    'VERSION_FROM'  => 'lib/Filesys/POSIX.pm', # finds \$VERSION
    'AUTHOR'        => 'Erin Schoenhals (erin@cpanel.net)',
    'ABSTRACT'      => 'Provides POSIX filesystem semantics in pure Perl',
    'PREREQ_PM'     => {
        'Test::Simple'      => '0.44',
        'Test::Exception'   => '0.26',
        'Test::NoWarnings'  => '0.081'
    }
);
