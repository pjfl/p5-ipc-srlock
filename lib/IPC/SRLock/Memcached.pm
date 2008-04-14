package IPC::SRLock::Memcached;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use Cache::Memcached;
use Time::HiRes qw(usleep);

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

__PACKAGE__->mk_accessors( qw(keys memd servers) );

# Private methods

sub _init {
   my ($me, $app, $config) = @_;

   $me->keys( {} );
   $me->memd( Cache::Memcached->new( debug     => $me->debug,
                                     namespace => $me->name,
                                     servers   => $me->servers ) );
   return;
}

sub _list {
   my $me = shift; my $self = []; my $done;

   while (!$done) {
      if ($me->memd->add( $me->lockfile, 1 )) {
         my $recs = $me->memd->get_multi( keys %{ $me->keys } );

         for my $key (sort keys %{ $recs }) {
            my @flds = split m{ , }mx, $recs->{ $key };
            push @{ $self }, { key     => $key,
                               pid     => $flds[0],
                               stime   => $flds[1],
                               timeout => $flds[2] };
         }

         $me->keys( $recs );
         $me->memd->delete( $me->lockfile );
         $done = 1;
      }

      usleep( 1_000_000 * $me->nap_time ) unless ($done);
   }

   return $self;
}

sub _reset {
   my ($me, $key) = @_; my $done;

   while (!$done) {
      if ($me->memd->add( $me->lockfile, 1 )) {
         delete $me->keys->{ $key };

         $done = 1 if ($me->memd->delete( $key ));

         $me->memd->delete( $me->lockfile );

         $me->throw( error => q(eLockNotSet), arg1 => $key ) unless ($done);
      }

      usleep( 1_000_000 * $me->nap_time ) unless ($done);
   }

   return 1;
}

sub _set {
   my ($me, $key, $pid, $timeout) = @_;
   my (@flds, $lock_set, $now, $rec, $start, $text);

   $start = time;

   while (!$lock_set) {
      $now = time;

      if ($me->memd->add( $me->lockfile, 1 )) {
         $me->keys->{ $key } = 1;

         if ($rec = $me->memd->get( $key )) {
            @flds = split m{ [,] }mx, $rec;

            if ($now > $flds[1] + $flds[2]) {
               $rec = $pid.q(,).$now.q(,).$timeout;
               $me->memd->replace( $key, $rec );
               $text = $me->timeout_error( $key,
                                           $flds[0],
                                           $flds[1],
                                           $flds[2] );
               $me->log->error( $text );
               $lock_set = 1;
            }
         }
         else {
            $rec = $pid.q(,).$now.q(,).$timeout;
            $me->memd->set( $key, $rec );
            $lock_set = 1;
         }

         $me->memd->delete( $me->lockfile );
      }

      if (!$lock_set && $me->patience && $now - $start > $me->patience) {
         $me->throw( error => q(ePatienceExpired), arg1 => $key );
      }

      usleep( 1_000_000 * $me->nap_time ) unless ($lock_set);
   }

   return 1;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
