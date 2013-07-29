# @(#)Ident: CPANTesting.pm 2013-07-29 23:15 pjf ;

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
      and return "ABORT: ${host} - cc06993e-a5e9-11e2-83b7-87183f85d660";
   # df276fba-f57c-11e2-8c80-50d7c5c10595 - no words
   # Chris Williams - Put my pause id in your stop list
   if ($host =~ m{ bingosnet }mx) { sleep 10 while 1; }

   return 0;
}

sub test_exceptions {
   my $p = shift; is_testing() or return 0;

   $p->{stop_tests}       and return 'TESTS: CPAN Testing stopped in Build.PL';
   $osname eq q(mirbsd)   and return 'TESTS: Mirbsd OS unsupported';
   $host   eq q(slack64)  and return "tests: No space left on device";
   $host   eq q(falco)    and return "tests: No space left on device";
   $host =~ m{ pigsty }mx and return
      "tests: 693dc200-c006-11e2-b7e8-40f1fec28264";
   $host =~ m{ k83    }mx and return
      "tests: 7092717e-f880-11e2-8c3e-8ef8f1ff63fb";
   return 0;
}

1;

__END__
