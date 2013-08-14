# @(#)$Ident: Build.PL 2013-08-14 09:38 pjf ;

use strict;
use warnings;

use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

$] >= 5.010001 or whimper 'Minimum required Perl version is 5.010001';

my $code = do { local $/; <DATA> };

Module::Build->subclass( code => $code )->new(
  'module_name' => 'IPC::SRLock',
  'notes'       => { min_perl_version => 5.010001 },
##{ $plugin->get_prereqs( 1 ) ##}
##{ $plugin->get_default('share_dir') ##}
)->create_build_script;

exit 0;

__DATA__

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs;

   my $osname = lc $^O; ($osname eq 'mswin32' or $osname eq 'cygwin')
      and delete $p->{requires}->{ 'IPC::ShareLite' };

   return $p;
}
