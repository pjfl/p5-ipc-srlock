#!/usr/bin/perl

# @(#)$Id$

use strict;
use warnings;
use Test::More;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );

BEGIN {
   if (!-e catfile( $FindBin::Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'Kwalitee test only for developers';
   }
}

eval { require Test::Kwalitee; };

plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if ($@);

Test::Kwalitee->import();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
