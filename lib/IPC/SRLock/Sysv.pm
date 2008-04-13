package IPC::SRLock::Sysv;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use IPC::SysV qw(IPC_CREAT);
use Time::HiRes qw(usleep);

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

# Private methods

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
   my ($found, $line, $lock_no, $lock_set, $lpid, $ltime, $ltimeout, $rec);
   my ($semid, $start, $shmid, $text);

   $semid = $me->_get_semid(); $start = time;

   while (!$lock_set) {
      unless (semop $semid, pack q(s!s!s!), 0, -1, 0) {
         $me->throw( error => q(eCannotSetSemaphore), arg1 => $me->lockfile );
      }

      $shmid = $me->_get_shmid();
      $rec   = $key.q(,).$pid.q(,).time.q(,).$timeout.q(,);
      $found = 0;

      for $lock_no (0 .. $me->num_locks - 1) {
         shmread $shmid, $line, $me->size * $lock_no, $me->size;

         if ($line =~ m{ \A EOF, }mx) {
            shmwrite $shmid, $rec, $me->size * $lock_no, $me->size
               unless ($lock_set);
            shmwrite $shmid, q(EOF,), $me->size * ($lock_no + 1), $me->size;
            $lock_set = 1;
            last;
         }

         next if ($line !~ m{ \A $key [,] }mx);
         (undef, $lpid, $ltime, $ltimeout) = split m{ [,] }mx, $line;
         if (time < $ltime + $ltimeout) { $found = 1; last }

         shmwrite $shmid, $rec, $me->size * $lock_no, $me->size;
         $text = $me->timeout_error( $key, $lpid, $ltime, $ltimeout );
         $me->log->error( $text );
         $lock_set = 1;
      }

      unless (semop $semid, pack q(s!s!s!), 0, 1, 0) {
         $me->throw( error => q(eCannotReleaseSemaphore),
                     arg1  => $me->lockfile );
      }

      if ($me->patience && time - $start > $me->patience) {
         $me->throw( error => q(ePatienceExpired), arg1 => $key );
      }

      usleep( 1_000_000 * $me->nap_time ) if ($found);
   }

   return 1;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
