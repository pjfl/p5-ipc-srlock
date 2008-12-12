use strict;
use warnings;
use File::Spec::Functions;
use FindBin ();
use lib catfile( $FindBin::Bin, updir, q(lib) );
use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;

all_pod_coverage_ok();
