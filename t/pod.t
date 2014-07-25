#!perl -T
#===============================================================================
#
#         FILE: pod.t
#
#       AUTHOR: Trevor S. Cornpropst (tsc), tscornpropst@gmail.com
#      VERSION: 1.0
#      CREATED: 07/24/2014 23:53:56
#     REVISION: ---
#===============================================================================

use strict;
use warnings FATAL => 'all';

use Test::More;

my $min_tp = 1.22;
eval "use Test::Pod $min_tp";

plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;

all_pod_files_ok();

