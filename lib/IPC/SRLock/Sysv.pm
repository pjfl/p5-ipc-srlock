# @(#)$Id$

package IPC::SRLock::Sysv;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(IPC::SRLock);

use IPC::ShareLite qw(:lock);
use IPC::SysV      qw(IPC_CREAT);
use Storable       qw(freeze thaw);
use Time::HiRes    qw(usleep);

my %ATTRS = ( lockfile => 12244237, mode => oct q(0666), size => 65_536,
              _share   => undef );

__PACKAGE__->mk_accessors( keys %ATTRS );

# Private methods

sub _init {
   my $self = shift;

   for (grep { ! defined $self->{ $_ } } keys %ATTRS) {
      $self->{ $_ } = $ATTRS{ $_ };
   }

   my $share = IPC::ShareLite->new( '-key'    => $self->lockfile,
                                    '-create' => 1,
                                    '-mode'   => $self->mode,
                                    '-size'   => $self->size );

   unless ($share) {
      $self->throw( error => 'No shared memory [_1]',
                    args  => [ $self->lockfile ] );
   }

   $self->_share( $share );
   return;
}

sub _list {
   my $self = shift; my $list = [];

   $self->_share->lock( LOCK_SH );

   my $data = $self->_share->fetch;

   $self->_share->unlock;

   my $hash = $data ? thaw( $data ) : {};

   while (my ($key, $lock) = each %{ $hash }) {
      push @{ $list }, { key     => $key,
                         pid     => $lock->{pid    },
                         stime   => $lock->{stime  },
                         timeout => $lock->{timeout} };
   }

   return $list;
}

sub _reset {
   my ($self, $key) = @_;

   $self->_share->lock( LOCK_EX );

   my $data  = $self->_share->fetch;
   my $hash  = $data ? thaw( $data ) : {};
   my $found = delete $hash->{ $key };

   $self->_share->store( freeze( $hash ) ) if ($found);

   $self->_share->unlock;

   unless ($found) {
      $self->throw( error => 'Lock [_1] not set', args => [ $key ] );
   }

   return 1;
}

sub _set {
   my ($self, $key, $pid, $timeout) = @_; my $lock_set; my $start = time;

   while (!$lock_set) {
      my ($lock, $lpid, $ltime, $ltimeout);
      my $found = 0; my $now = time; my $timedout = 0;

      $self->_share->lock( LOCK_EX );

      my $data = $self->_share->fetch;
      my $hash = $data ? thaw( $data ) : {};

      if (exists $hash->{ $key } and $lock = $hash->{ $key }) {
         $lpid     = $lock->{pid    };
         $ltime    = $lock->{stime  };
         $ltimeout = $lock->{timeout};

         if ($now > $ltime + $ltimeout) {
            $lock_set = $self->_set_lock( $hash, $key, $pid, $now, $timeout );
            $timedout = 1;
         }
         else { $found = 1 }
      }
      else {
         $lock_set = $self->_set_lock( $hash, $key, $pid, $now, $timeout );
      }

      $self->_share->unlock;

      if ($timedout) {
         my $text = $self->timeout_error( $key, $lpid, $ltime, $ltimeout );
         $self->log->error( $text );
      }

      if (!$lock_set && $self->patience && $now - $start > $self->patience) {
         $self->throw( error => 'Lock [_1] timed out', args => [ $key ] );
      }

      usleep( 1_000_000 * $self->nap_time ) if ($found);
   }

   $self->log->debug( "Lock $key set by $pid\n" ) if ($self->debug);

   return 1;
}

sub _set_lock {
   my ($self, $hash, $key, $pid, $now, $timeout) = @_;

   $hash->{ $key } = { pid => $pid, stime => $now, timeout => $timeout };

   $self->_share->store( freeze( $hash ) );
   return 1;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Sysv - Set/reset locks using semop and shmop

=head1 Version

0.3.$Revision$

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { type => q(sysv) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses System V semaphores to lock access to a shared memory file

=head1 Configuration and Environment

This class defines accessors and mutators for these attributes:

=over 3

=item lockfile

The key the the semaphore. Defaults to 12_244_237

=item mode

Mode to create the shared memory file. Defaults to 0666

=item size

Maximum size of a shared memory segment. Defaults to 65_536

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

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<IPC::SRLock>

=item L<IPC::ShareLite>

=item L<Storable>

=item L<IPC::SysV>

=item L<Time::HiRes>

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
