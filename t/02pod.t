# @(#)$Id: 02pod.t 287 2008-11-22 14:45:33Z pjf $

use strict;
use warnings;
use File::Spec::Functions;
use FindBin ();
use lib catfile( $FindBin::Bin, updir, q(lib) );
use Test::More;

BEGIN {
   if (!-e catfile( $FindBin::Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'POD test only for developers';
   }
}

eval { use Test::Pod 1.14; };

plan skip_all => 'Test::Pod 1.14 required' if ($@);

all_pod_files_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
