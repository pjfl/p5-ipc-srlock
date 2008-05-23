package IPC::SRLock::Memcached;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use Cache::Memcached;
use Readonly;
use Time::HiRes qw(usleep);

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

Readonly my %ATTRS => ( lockfile  => q(_lockfile),
                        memd      => undef,
                        servers   => [ q(localhost:11211) ],
                        shmfile   => q(_shmfile), );

__PACKAGE__->mk_accessors( keys %ATTRS );

# Private methods

sub _init {
   my $me = shift;

   $me->{ $_ } = $ATTRS{ $_ } for (grep { ! defined $me->{ $_ } } keys %ATTRS);

   $me->memd( $me->memd
              || Cache::Memcached->new( debug     => $me->debug,
                                        namespace => $me->name,
                                        servers   => $me->servers ) );
   return;
}

sub _list {
   my $me = shift; my (@flds, $key, $recs, $self, $start);

   $self = []; $start = time;

   while (1) {
      if ($me->memd->add( $me->lockfile, 1, $me->patience + 30 )) {
         $recs = $me->memd->get( $me->shmfile ) || {};

         for $key (sort keys %{ $recs }) {
            @flds = split m{ , }mx, $recs->{ $key };
            push @{ $self }, { key     => $key,
                               pid     => $flds[0],
                               stime   => $flds[1],
                               timeout => $flds[2] };
         }

         $me->memd->delete( $me->lockfile );
         return $self;
      }

      $me->_sleep_or_throw( $start, time, $me->lockfile );
   }

   return;
}

sub _reset {
   my ($me, $key) = @_; my ($found, $recs); my $start = time;

   while (1) {
      if ($me->memd->add( $me->lockfile, 1, $me->patience + 30 )) {
         $recs = $me->memd->get( $me->shmfile ) || {};
         $found = 1 if (delete $recs->{ $key });
         $me->memd->set( $me->shmfile, $recs ) if ($found);
         $me->memd->delete( $me->lockfile );
         $me->throw( error => q(eLockNotSet), arg1 => $key ) unless ($found);
         return 1;
      }

      $me->_sleep_or_throw( $start, time, $me->lockfile );
   }

   return;
}

sub _set {
   my ($me, $key, $pid, $timeout) = @_;
   my (@flds, $lock_set, $now, $rec, $recs, $start, $text);

   $start = time;

   while (1) {
      $now = time;

      if ($me->memd->add( $me->lockfile, 1, $me->patience + 30 )) {
         $recs = $me->memd->get( $me->shmfile ) || {};

         if ($rec = $recs->{ $key }) {
            @flds = split m{ [,] }mx, $rec;

            if ($now > $flds[1] + $flds[2]) {
               $recs->{ $key } = $pid.q(,).$now.q(,).$timeout;
               $me->memd->set( $me->shmfile, $recs );
               $text = $me->timeout_error( $key,
                                           $flds[0],
                                           $flds[1],
                                           $flds[2] );
               $me->log->error( $text );
               $lock_set = 1;
            }
         }
         else {
            $recs->{ $key } = $pid.q(,).$now.q(,).$timeout;
            $text = 'Set lock '.$key.q(,).$recs->{ $key }."\n";
            $me->log->debug( $text ) if ($me->debug);
            $me->memd->set( $me->shmfile, $recs );
            $lock_set = 1;
         }

         $me->memd->delete( $me->lockfile );

         return 1 if ($lock_set);
      }

      $me->_sleep_or_throw( $start, $now, $me->lockfile );
   }

   return;
}

sub _sleep_or_throw {
   my ($me, $start, $now, $key) = @_;

   if ($me->patience && $now - $start > $me->patience) {
      $me->throw( error => q(ePatienceExpired), arg1 => $key );
   }

   usleep( 1_000_000 * $me->nap_time );
   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Memcached - Set/reset locks using libmemcache

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use IPC::SRLock;

   my $config = { tempdir => q(path_to_tmp_directory), type => q(memcached) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses L<Cache::Memcached> to implement a distributed lock manager

=head1 Configuration and Environment

This class defines accessors and mutators for these attributes:

=over 3

=item lockfile

Name of the key to the lock file record. Defaults to I<_lockfile>

=item memd

An instance of L<Cache::Memcached> with it's namespace set to I<ipc_srlock>

=item servers

An array ref of servers to connect to. Defaults to I<localhost:11211>

=item shmfile

Name of the key to the lock table record. Defaults to I<_shmfile>

=back

=head1 Subroutines/Methods

=head2 _init

Initialise the object

=head2 _list

List the contents of the lock table

=head2 _reset

Delete a lock from the lock table

=head2 _set

Set a lock in the lock table

=head2 _sleep_or_throw

Sleep for a bit or throw a timeout exception

=head1 Diagnostics

None

=head1 Dependencies

=over 4

=item L<IPC::SRLock>

=item L<Cache::Memcached>

=item L<Readonly>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2008 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
