# @(#)$Id$
# Bob-Version: 1.7

use Pod::Select;

sub ACTION_distmeta {
   my $self = shift;

   $self->notes->{create_readme_pod} and podselect( {
      -output => q(README.pod) }, $self->dist_version_from );

   return $self->SUPER::ACTION_distmeta;
}

sub _normalize_prereqs {
   my $self = shift; my $osname = lc $^O;

   my $prereqs = $self->SUPER::_normalize_prereqs;

   ($osname eq 'mswin32' or $osname eq 'cygwin')
      and delete $prereqs->{requires}->{ 'IPC::ShareLite' };

   return $prereqs;
}
