package IPC::SRLock::Memcached;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use Cache::Memcached;
use NEXT;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

# Private methods

sub _init {
   my ($me, $app, $config) = @_;
   return;
}

sub _list {
   my $me = shift;
   my $self = [];

   return $self;
}

sub _reset {
   my ($me, $key) = @_;

   return 1;
}

sub _set {
   my ($me, $key, $pid, $timeout) = @_;


   return 1;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
