package IPC::SRLock::Sysv;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use IPC::SysV qw(IPC_CREAT);
use Readonly;
use Time::HiRes qw(usleep);

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

Readonly my %ATTRS => ( lockfile  => 195_911_405,
                        mode      => oct q(0666),
                        num_locks => 100,
                        shmfile   => 195_911_405,
                        size      => 300, );

__PACKAGE__->mk_accessors( keys %ATTRS );

# Private methods

sub _init {
   my $self = shift;

   for (grep { ! defined $self->{ $_ } } keys %ATTRS) {
      $self->{ $_ } = $ATTRS{ $_ };
   }

   return;
}

sub _get_semid {
   my $self = shift; my $semid = semget $self->lockfile, 1, 0;

   return $semid if (defined $semid);

   $semid = semget $self->lockfile, 1, IPC_CREAT | $self->mode;

   unless (defined $semid) {
      $self->throw( error => q(eCannotCreateSemaphore),
                    arg1  => $self->lockfile );
   }

   unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
      $self->throw( error => q(eCannotPrimeSemaphore),
                    arg1  => $self->lockfile );
   }

   return $semid;
}

sub _get_shmid {
   my $self = shift; my ($shmid, $size);

   $size  = $self->size * $self->num_locks;
   $shmid = shmget $self->shmfile, $size, 0;

   return $shmid if (defined $shmid);

   $shmid = shmget $self->shmfile, $size, IPC_CREAT | $self->mode;

   unless (defined $shmid) {
      $self->throw( error => q(eCannotCreateMemorySegment),
                    arg1  => $self->shmfile );
   }

   shmwrite $shmid, q(EOF,), 0, $self->size;
   return $shmid;
}

sub _list {
   my $self = shift; my (@flds, $line, $list, $lock_no, $semid, $shmid);

   $list  = [];
   $semid = $self->_get_semid();

   unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
      $self->throw( error => q(eCannotSetSemaphore), arg1 => $self->lockfile );
   }

   $shmid = $self->_get_shmid();

   for $lock_no (0 .. $self->num_locks - 1) {
      shmread $shmid, $line, $self->size * $lock_no, $self->size;

      last if ($line =~ m{ \A EOF, }mx);

      @flds = split m{ , }mx, $line;
      push @{ $list }, { key     => $flds[0],
                         pid     => $flds[1],
                         stime   => $flds[2],
                         timeout => $flds[3] };
   }

   unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
      $self->throw( error => q(eCannotReleaseSemaphore),
                    arg1  => $self->lockfile );
   }

   return $list;
}

sub _reset {
   my ($self, $key) = @_; my ($found, $line, $lock_no, $semid, $shmid);

   $semid = $self->_get_semid();

   unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
      $self->throw( error => q(eCannotSetSemaphore),
                    arg1  => $self->lockfile );
   }

   $shmid = $self->_get_shmid();
   $found = 0;

   for $lock_no (0 .. $self->num_locks - 1) {
      shmread $shmid, $line, $self->size * $lock_no, $self->size;

      if ($found) {
         shmwrite $shmid, $line, $self->size * ($lock_no - 1), $self->size;
      }

      last       if ($line =~ m{ \A EOF, }mx);
      $found = 1 if ($line =~ m{ \A $key , }mx);
   }

   unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
      $self->throw( error => q(eCannotReleaseSemaphore),
                    arg1  => $self->lockfile );
   }

   $self->throw( error => q(eLockNotSet), arg1 => $key ) unless ($found);

   return 1;
}

sub _set {
   my ($self, $key, $pid, $timeout) = @_;
   my ($found, $line, $lock_no, $lock_set, $lpid, $ltime, $ltimeout, $now);
   my ($rec, $semid, $start, $shmid, $text);

   $semid = $self->_get_semid();
   $shmid = $self->_get_shmid();
   $start = time;

   while (!$lock_set) {
      unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
         $self->throw( error => q(eCannotSetSemaphore),
                       arg1  => $self->lockfile );
      }

      $found = 0; $now = time;

      for $lock_no (0 .. $self->num_locks - 1) {
         shmread $shmid, $line, $self->size * $lock_no, $self->size;

         if ($line =~ m{ \A EOF, }mx) {
            $rec = $key.q(,).$pid.q(,).$now.q(,).$timeout.q(,);
            shmwrite $shmid, $rec, $self->size * $lock_no, $self->size
               unless ($lock_set);
            shmwrite $shmid, q(EOF,),
                     $self->size * ($lock_no + 1), $self->size;
            $self->log->debug( 'Set lock '.$rec."\n" ) if ($self->debug);
            $lock_set = 1;
            last;
         }

         next if ($line !~ m{ \A $key [,] }mx);
         (undef, $lpid, $ltime, $ltimeout) = split m{ [,] }mx, $line;
         if ($now < $ltime + $ltimeout) { $found = 1; last }

         $rec = $key.q(,).$pid.q(,).$now.q(,).$timeout.q(,);
         shmwrite $shmid, $rec, $self->size * $lock_no, $self->size;
         $text = $self->timeout_error( $key, $lpid, $ltime, $ltimeout );
         $self->log->error( $text );
         $lock_set = 1;
      }

      unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
         $self->throw( error => q(eCannotReleaseSemaphore),
                     arg1  => $self->lockfile );
      }

      if (!$lock_set && $self->patience && $now - $start > $self->patience) {
         $self->throw( error => q(ePatienceExpired), arg1 => $key );
      }

      usleep( 1_000_000 * $self->nap_time ) if ($found);
   }

   return 1;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Sysv - Set/reset locks using semop and shmop

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { tempdir => q(path_to_tmp_directory), type => q(sysv) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses System V semaphores to lock access to a shared memory file

=head1 Configuration and Environment

This class defines accessors and mutators for these attributes:

=over 3

=item lockfile

The key the the semaphore. Defaults to 195_911_405

=item mode

Mode to create the shared memory file. Defaults to 0666

=item num_locks

Maximum number of simultaneous locks. Defaults to 100

=item shmfile

The key to the shared memory file. Defaults to 195_911_405

=item size

Maximum size of a lock record. Limits the lock key to 255
bytes. Defaults to 300

=back

=head1 Subroutines/Methods

=head2 _init

Initialise the object

=head2 _get_semid

Return the semaphore reference

=head2 _get_shmid

Return the shared memory reference

=head2 _list

List the contents of the lock table

=head2 _reset

Delete a lock from the lock table

=head2 _set

Set a lock in the lock table

=head1 Diagnostics

None

=head1 Dependencies

=over 4

=item L<IPC::SRLock>

=item L<IPC::SysV>

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
