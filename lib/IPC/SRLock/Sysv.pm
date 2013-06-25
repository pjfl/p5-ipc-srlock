# @(#)$Ident: Sysv.pm 2013-06-21 01:01 pjf ;

package IPC::SRLock::Sysv;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.12.%d', q$Rev: 1 $ =~ /\d+/gmx );

use English                 qw( -no_match_vars );
use IPC::ShareLite          qw( :lock );
use Moo;
use Storable                qw( nfreeze thaw );
use Time::HiRes             qw( usleep );
use Try::Tiny;
use Unexpected::Types       qw( NonEmptySimpleStr Object PositiveInt );

extends q(IPC::SRLock::Base);

# Public attributes
has 'lockfile' => is => 'ro',   isa => PositiveInt,       default  => 12244237;

has 'mode'     => is => 'ro',   isa => NonEmptySimpleStr, default  => q(0666);

has 'size'     => is => 'ro',   isa => PositiveInt,       default  => 65_536;

# Private attributes
has '_share'   => is => 'lazy', isa => Object,            init_arg => undef;

# Private methods
sub _build__share {
   my $self = shift; my $share;

   try   { $share = IPC::ShareLite->new( '-key'    => $self->lockfile,
                                         '-create' => 1,
                                         '-mode'   => oct $self->mode,
                                         '-size'   => $self->size ) }
   catch { $self->throw( "${_}: ${OS_ERROR}" ) };

   return $share;
}

sub _fetch_share_data {
   my ($self, $for_update) = @_; my $data;

   defined $self->_share->lock( $for_update ? LOCK_EX : LOCK_SH )
      or $self->throw( 'Failed to set semaphore' );

   try   { $data = $self->_share->fetch; $data = $data ? thaw( $data ) : {} }
   catch { $self->throw( "${_}: ${OS_ERROR}" ) };

   not $for_update and $self->_unlock_share;
   return $data;
}

sub _list {
   my $self = shift; my $data = $self->_fetch_share_data; my $list = [];

   while (my ($key, $info) = each %{ $data }) {
      push @{ $list }, { key     => $key,
                         pid     => $info->{pid    },
                         stime   => $info->{stime  },
                         timeout => $info->{timeout} };
   }

   return $list;
}

sub _reset {
   my ($self, $key) = @_; my $data = $self->_fetch_share_data( 1 );

   my $found = delete $data->{ $key } and $self->_store_share_data( $data );

   $self->_unlock_share;

   $found or $self->throw( error => 'Lock [_1] not set', args => [ $key ] );
   return 1;
}

sub _set {
   my ($self, $args) = @_; my $lock_set; my $start = time;

   my $key = $args->{k}; my $pid = $args->{p}; my $timeout = $args->{t};

   while (not $lock_set) {
      my ($lock, $lpid, $ltime, $ltimeout);
      my $found = 0; my $now = time; my $timedout = 0;
      my $data  = $self->_fetch_share_data( 1 );

      if (exists $data->{ $key } and $lock = $data->{ $key }) {
         $lpid     = $lock->{pid    };
         $ltime    = $lock->{stime  };
         $ltimeout = $lock->{timeout};

         if ($now > $ltime + $ltimeout) {
            $data->{ $key } = { pid     => $pid,
                                stime   => $now,
                                timeout => $timeout };
            $lock_set = $self->_store_share_data( $data );
            $timedout = 1;
         }
         else { $found = 1 }
      }
      else {
         $data->{ $key } = { pid => $pid, stime => $now, timeout => $timeout };
         $lock_set = $self->_store_share_data( $data );
      }

      $self->_unlock_share;

      not $lock_set and $args->{async} and return 0;

      if ($timedout) {
         my $text = $self->timeout_error( $key, $lpid, $ltime, $ltimeout );
         $self->log->error( $text );
      }

      if (!$lock_set && $self->patience && $now - $start > $self->patience) {
         $self->throw( error => 'Lock [_1] timed out', args => [ $key ] );
      }

      $found and usleep( 1_000_000 * $self->nap_time );
   }

   $self->debug and $self->log->debug( "Lock ${key} set by ${pid}\n" );
   return 1;
}

sub _store_share_data {
   my ($self, $data) = @_;

   try   { $self->_share->store( nfreeze $data ) }
   catch { $self->throw( "${_}: ${OS_ERROR}" ) };

   return 1;
}

sub _unlock_share {
   my $self = shift;

   defined $self->_share->unlock or $self->throw( 'Failed to unset semaphore' );

   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Sysv - Set/reset locks using System V IPC

=head1 Version

This documents version v0.12.$Rev: 1 $

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { type => q(sysv) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses System V semaphores to lock access to a shared memory file

=head1 Configuration and Environment

This class defines accessors for these attributes:

=over 3

=item C<lockfile>

The key the the semaphore. Defaults to 12_244_237

=item C<mode>

Mode to create the shared memory file. Defaults to 0666

=item C<size>

Maximum size of a shared memory segment. Defaults to 65_536

=back

=head1 Subroutines/Methods

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

=item L<IPC::ShareLite>

=item L<IPC::SRLock::Base>

=item L<Moo>

=item L<Storable>

=item L<Time::HiRes>

=item L<Try::Tiny>

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
