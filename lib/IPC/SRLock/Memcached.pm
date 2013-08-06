# @(#)$Ident: Memcached.pm 2013-06-21 00:55 pjf ;

package IPC::SRLock::Memcached;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.13.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Cache::Memcached;
use Moo;
use Unexpected::Types       qw( ArrayRef NonEmptySimpleStr Object );
use Time::HiRes             qw( usleep );

extends q(IPC::SRLock::Base);

# Public attributes
has 'lockfile' => is => 'ro', isa => NonEmptySimpleStr, default => '_lockfile';

has 'servers'  => is => 'ro', isa => ArrayRef,
   default     => sub { [ q(localhost:11211) ] };

has 'shmfile'  => is => 'ro', isa => NonEmptySimpleStr, default => '_shmfile';

# Private attributes
has '_memd'    => is => 'lazy', isa => Object,
   init_arg    => undef,     reader => 'memd';

# Private methods
sub _build_memd {
   return Cache::Memcached->new( debug     => $_[ 0 ]->debug,
                                 namespace => $_[ 0 ]->name,
                                 servers   => $_[ 0 ]->servers );
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
   my ($self, $args) = @_; my $start = time;

   my $key = $args->{k}; my $pid = $args->{p}; my $timeout = $args->{t};

   my (@flds, $lock_set, $now, $rec, $recs, $text);

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
            $self->debug and $self->log->debug( "Lock ${key} set by ${pid}\n" );
            return 1;
         }
         elsif ($args->{async}) { return 0 }
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

This documents version v0.13.$Rev: 1 $

=head1 Synopsis

   use IPC::SRLock;

   my $config = { type => q(memcached) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses L<Cache::Memcached> to implement a distributed lock manager

=head1 Configuration and Environment

This class defines accessors for these attributes:

=over 3

=item C<lockfile>

Name of the key to the lock file record. Defaults to C<_lockfile>

=item C<servers>

An array ref of servers to connect to. Defaults to C<localhost:11211>

=item C<shmfile>

Name of the key to the lock table record. Defaults to C<_shmfile>

=back

=head1 Subroutines/Methods

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

=item L<Cache::Memcached>

=item L<IPC::SRLock::Base>

=item L<Moo>

=item L<Time::HiRes>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
