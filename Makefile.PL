package main;

require 5.008008;
use strict;
use warnings FATAL => 'all';

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'TSC::Daemon',
    AUTHOR              => q{Trevor Cornpropst <tscornpropst@gmail.com>},
    VERSION_FROM        => 'lib/TSC/Daemon.pm',
    ABSTRACT_FROM       => 'lib/TSC/Daemon.pm',
    LICENSE             => 'Artistic_2_0',
    BUILD_REQUIRES      => {},
    MIN_PERL_VERSION    => 5.006,
    CONFIGURE_REQUIRES  => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES      => {
        'Test::More'            => 0,
        'Test::Pod'             => 0,
        'Test::Pod::Coverage'   => 0,
        'Test::Strict'          => 0
    },
    PREREQ_PM           => {
        'Carp'              => 0,
        'Class::InsideOut'  => 0,
        'Cwd'               => 0,
        'File::Basename'    => 0,
        'IO::File'          => 0,
        'POSIX'             => 0,
        'version'           => 0
    },
    DISTNAME => '',
    test => {
        TESTS => 't/*.t',
    },
    dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'TSC-Daemon-*' },
);
