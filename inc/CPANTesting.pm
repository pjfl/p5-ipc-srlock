# @(#)$Id$
# Bob-Version: 1.7

package CPANTesting;

use strict;
use warnings;

use Sys::Hostname; my $host = lc hostname; my $osname = lc $^O;

# Is this an attempted install on a CPAN testing platform?
sub is_testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                 || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

sub should_abort {
   is_testing() or return 0;

   $host eq q(xphvmfred)
      and return "Stauner ${host} - cc06993e-a5e9-11e2-83b7-87183f85d660";
   return 0;
}

sub test_exceptions {
   my $p = shift; is_testing() or return 0;

   $p->{stop_tests}      and return 'CPAN Testing stopped in Build.PL';
   $osname eq q(mirbsd)  and return 'Mirbsd OS unsupported';
   $host   eq q(slack64) and return "Bingos ${host} - No space left on device";
   $host   eq q(falco)   and return "Bingos ${host} - No space left on device";
   return 0;
}

1;

__END__
