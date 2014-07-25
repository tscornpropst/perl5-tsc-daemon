#!perl -T

use strict;
use warnings FATAL => 'all';

use File::Spec;
use Test::More;

if ( not $ENV{AUTHOR_TESTING} ) {
    my $msg = "Author test. Set $ENV{AUTHOR_TESTING} to a true value to run.";
    plan( skip_all => $msg );
}

eval { require Test::Perl::Critic; };

if ( $@ ) {
    my $msg = 'Test::Perl::Critic required to criticise code';
    plan( skip_all => $msg );
}

my $rcfile = File::Spec->catfile( 't', 'perlcritic.rc' );

Test::Perl::Critic->import( -profile => $rcfile );

all_critic_ok();
