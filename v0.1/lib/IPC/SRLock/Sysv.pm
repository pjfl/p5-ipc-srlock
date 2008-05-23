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
   my $me = shift;

   $me->{ $_ } = $ATTRS{ $_ } for (grep { ! defined $me->{ $_ } } keys %ATTRS);

   return;
}

sub _get_semid {
   my $me = shift; my $semid = semget $me->lockfile, 1, 0;

   return $semid if (defined $semid);

   $semid = semget $me->lockfile, 1, IPC_CREAT | $me->mode;

   unless (defined $semid) {
      $me->throw( error => q(eCannotCreateSemaphore), arg1 => $me->lockfile );
   }

   unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
      $me->throw( error => q(eCannotPrimeSemaphore), arg1 => $me->lockfile );
   }

   return $semid;
}

sub _get_shmid {
   my $me = shift; my ($shmid, $size);

   $size  = $me->size * $me->num_locks;
   $shmid = shmget $me->shmfile, $size, 0;

   return $shmid if (defined $shmid);

   $shmid = shmget $me->shmfile, $size, IPC_CREAT | $me->mode;

   unless (defined $shmid) {
      $me->throw( error => q(eCannotCreateMemorySegment),
                  arg1  => $me->shmfile );
   }

   shmwrite $shmid, q(EOF,), 0, $me->size;
   return $shmid;
}

sub _list {
   my $me = shift; my (@flds, $line, $lock_no, $self, $semid, $shmid);

   $self  = [];
   $semid = $me->_get_semid();

   unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
      $me->throw( error => q(eCannotSetSemaphore), arg1 => $me->lockfile );
   }

   $shmid = $me->_get_shmid();

   for $lock_no (0 .. $me->num_locks - 1) {
      shmread $shmid, $line, $me->size * $lock_no, $me->size;

      last if ($line =~ m{ \A EOF, }mx);

      @flds = split m{ , }mx, $line;
      push @{ $self }, { key     => $flds[0],
                         pid     => $flds[1],
                         stime   => $flds[2],
                         timeout => $flds[3] };
   }

   unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
      $me->throw( error => q(eCannotReleaseSemaphore), arg1 => $me->lockfile );
   }

   return $self;
}

sub _reset {
   my ($me, $key) = @_; my ($found, $line, $lock_no, $semid, $shmid);

   $semid = $me->_get_semid();

   unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
      $me->throw( error => q(eCannotSetSemaphore), arg1 => $me->lockfile );
   }

   $shmid = $me->_get_shmid();
   $found = 0;

   for $lock_no (0 .. $me->num_locks - 1) {
      shmread $shmid, $line, $me->size * $lock_no, $me->size;

      if ($found) {
         shmwrite $shmid, $line, $me->size * ($lock_no - 1), $me->size;
      }

      last       if ($line =~ m{ \A EOF, }mx);
      $found = 1 if ($line =~ m{ \A $key , }mx);
   }

   unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
      $me->throw( error => q(eCannotReleaseSemaphore), arg1 => $me->lockfile );
   }

   $me->throw( error => q(eLockNotSet), arg1 => $key ) unless ($found);

   return 1;
}

sub _set {
   my ($me, $key, $pid, $timeout) = @_;
   my ($found, $line, $lock_no, $lock_set, $lpid, $ltime, $ltimeout, $now);
   my ($rec, $semid, $start, $shmid, $text);

   $semid = $me->_get_semid();
   $shmid = $me->_get_shmid();
   $start = time;

   while (!$lock_set) {
      unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
         $me->throw( error => q(eCannotSetSemaphore), arg1 => $me->lockfile );
      }

      $found = 0; $now = time;

      for $lock_no (0 .. $me->num_locks - 1) {
         shmread $shmid, $line, $me->size * $lock_no, $me->size;

         if ($line =~ m{ \A EOF, }mx) {
            $rec = $key.q(,).$pid.q(,).$now.q(,).$timeout.q(,);
            shmwrite $shmid, $rec, $me->size * $lock_no, $me->size
               unless ($lock_set);
            shmwrite $shmid, q(EOF,), $me->size * ($lock_no + 1), $me->size;
            $me->log->debug( 'Set lock '.$rec."\n" ) if ($me->debug);
            $lock_set = 1;
            last;
         }

         next if ($line !~ m{ \A $key [,] }mx);
         (undef, $lpid, $ltime, $ltimeout) = split m{ [,] }mx, $line;
         if ($now < $ltime + $ltimeout) { $found = 1; last }

         $rec = $key.q(,).$pid.q(,).$now.q(,).$timeout.q(,);
         shmwrite $shmid, $rec, $me->size * $lock_no, $me->size;
         $text = $me->timeout_error( $key, $lpid, $ltime, $ltimeout );
         $me->log->error( $text );
         $lock_set = 1;
      }

      unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
         $me->throw( error => q(eCannotReleaseSemaphore),
                     arg1  => $me->lockfile );
      }

      if (!$lock_set && $me->patience && $now - $start > $me->patience) {
         $me->throw( error => q(ePatienceExpired), arg1 => $key );
      }

      usleep( 1_000_000 * $me->nap_time ) if ($found);
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
