use strict;
use warnings;

use Module::Build::Tiny;

sub testing { $ENV{AUTOMATED_TESTING} || $ENV{PERL_CPAN_REPORTER_CONFIG}
                                      || $ENV{PERL5_CPANPLUS_IS_VERSION} }
sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = ##{ $meta2{prereqs}->{runtime}->{requires}->{perl} ##};

sub Dynamic_Config {
   my $meta = shift; my $prereqs = $meta->{prereqs}; my $osname = lc $^O;

   $osname ne 'mswin32' and $osname ne 'cygwin' and
      $prereqs->{runtime}->{requires}->{ 'IPC::ShareLite' } = '0.17';

   if ($] < $perl_ver) { # Not interested in reports below min perl ver
      testing or whimper "Minimum required Perl version is ${perl_ver}";
      $prereqs->{build}->{requires} = { %{ $prereqs->{configure}->{requires} }};
      $prereqs->{build}->{requires}->{ 'Test::Requires' } = 0.06;
      delete $prereqs->{runtime}->{requires};
   }

   return $meta;
}

Build_PL();

exit 0;
