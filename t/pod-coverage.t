#!perl -T
#===============================================================================
#
#         FILE: pod-coverage.t
#
#       AUTHOR: Trevor S. Cornpropst (tsc), tscornpropst@gmail.com
#      VERSION: 0.0.8
#      CREATED: 07/24/2014 23:59:18
#     REVISION: ---
#===============================================================================

use strict;
use warnings FATAL => 'all';

use Test::More;

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";

plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage" if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

my $trust_me = { trustme => [qr/^(BUILD|DEMOLISH|AUTOMETHOD|START)$/] };

all_pod_coverage_ok($trust_me);
