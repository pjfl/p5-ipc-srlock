# @(#)$Id$

package IPC::SRLock::Memcached;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(IPC::SRLock);

use Cache::Memcached;
use Time::HiRes qw(usleep);

my %ATTRS = ( lockfile  => q(_lockfile),
              memd      => undef,
              servers   => [ q(localhost:11211) ],
              shmfile   => q(_shmfile), );

__PACKAGE__->mk_accessors( keys %ATTRS );

# Private methods

sub _init {
   my $self = shift;

   for (grep { not defined $self->{ $_ } } keys %ATTRS) {
      $self->{ $_ } = $ATTRS{ $_ };
   }

   $self->memd( $self->memd
                || Cache::Memcached->new( debug     => $self->debug,
                                          namespace => $self->name,
                                          servers   => $self->servers ) );
   return;
}

sub _list {
   my $self = shift; my (@flds, $key, $list, $recs, $start);

   $list = []; $start = time;

   while (1) {
      if ($self->memd->add( $self->lockfile, 1, $self->patience + 30 )) {
         $recs = $self->memd->get( $self->shmfile ) || {};

         for $key (sort keys %{ $recs }) {
            @flds = split m{ , }mx, $recs->{ $key };
            push @{ $list }, { key     => $key,
                               pid     => $flds[0],
                               stime   => $flds[1],
                               timeout => $flds[2] };
         }

         $self->memd->delete( $self->lockfile );
         return $list;
      }

      $self->_sleep_or_throw( $start, time, $self->lockfile );
   }

   return;
}

sub _reset {
   my ($self, $key) = @_; my ($found, $recs); my $start = time;

   while (1) {
      if ($self->memd->add( $self->lockfile, 1, $self->patience + 30 )) {
         $recs = $self->memd->get( $self->shmfile ) || {};
         delete $recs->{ $key } and $found = 1;
         $found and $self->memd->set( $self->shmfile, $recs );
         $self->memd->delete( $self->lockfile );
         $found or $self->throw( error => 'Lock [_1] not set',
                                 args  => [ $key ] );
         return 1;
      }

      $self->_sleep_or_throw( $start, time, $self->lockfile );
   }

   return;
}

sub _set {
   my ($self, $key, $pid, $timeout) = @_;
   my (@flds, $lock_set, $now, $rec, $recs, $start, $text);

   $start = time;

   while (1) {
      $now = time;

      if ($self->memd->add( $self->lockfile, 1, $self->patience + 30 )) {
         $recs = $self->memd->get( $self->shmfile ) || {};

         if ($rec = $recs->{ $key }) {
            @flds = split m{ [,] }mx, $rec;

            if ($now > $flds[1] + $flds[2]) {
               $recs->{ $key } = $pid.q(,).$now.q(,).$timeout;
               $self->memd->set( $self->shmfile, $recs );
               $text = $self->timeout_error( $key,
                                             $flds[0],
                                             $flds[1],
                                             $flds[2] );
               $self->log->error( $text );
               $lock_set = 1;
            }
         }
         else {
            $recs->{ $key } = $pid.q(,).$now.q(,).$timeout;
            $self->memd->set( $self->shmfile, $recs );
            $lock_set = 1;
         }

         $self->memd->delete( $self->lockfile );

         if ($lock_set) {
            $self->debug and $self->log->debug( "Lock $key set by $pid\n" );
            return 1;
         }
      }

      $self->_sleep_or_throw( $start, $now, $self->lockfile );
   }

   return;
}

sub _sleep_or_throw {
   my ($self, $start, $now, $key) = @_;

   $self->patience and $now - $start > $self->patience
      and $self->throw( error => 'Lock [_1] timed out', args => [ $key ] );
   usleep( 1_000_000 * $self->nap_time );
   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Memcached - Set/reset locks using libmemcache

=head1 Version

0.7.$Revision$

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
