# @(#)$Id: 03podcoverage.t 428 2009-04-05 17:44:30Z pjf $

use strict;
use warnings;
use File::Spec::Functions;
use English  qw(-no_match_vars);
use FindBin  qw( $Bin );
use lib (catdir( $Bin, updir, q(lib) ));
use Test::More;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 108 $ =~ /\d+/gmx );

BEGIN {
   if (!-e catfile( $Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'POD coverage test only for developers';
   }
}

eval { use Test::Pod::Coverage 1.04; };

plan skip_all => 'Test::Pod::Coverage 1.04 required' if ($EVAL_ERROR);

all_pod_coverage_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
