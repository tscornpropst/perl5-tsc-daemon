#!perl -T
#===============================================================================
#
#         FILE: load.t
#
#       AUTHOR: Trevor S. Cornpropst (tsc), tscornpropst@gmail.com
#      VERSION: 1.0
#      CREATED: 07/25/2014 00:08:15
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use Test::More tests => 1;

BEGIN
{
    use_ok('TSC::Daemon') || print "Bail out!\n";
}

diag( "Testing $TSC::Daemon::VERSION, Perl $], $^X" );

