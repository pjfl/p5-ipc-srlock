package IPC::SRLock::Fcntl;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use Data::Serializer;
use File::Spec;
use File::Spec::Functions;
use Fcntl qw(:flock);
use IO::AtomicFile;
use IO::File;
use Readonly;
use Time::HiRes qw(usleep);

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

Readonly my %ATTRS => ( lockfile   => undef,
                        mode       => oct q(0666),
                        serializer => undef,
                        shmfile    => undef,
                        tempdir    => File::Spec->tmpdir,
                        umask      => 0, );

__PACKAGE__->mk_accessors( keys %ATTRS );

# Private methods

sub _init {
   my $me = shift; my $path;

   $me->{ $_ } = $ATTRS{ $_ } for (grep { ! defined $me->{ $_ } } keys %ATTRS);

   unless ($me->lockfile) {
      $path = catfile( $me->tempdir, $me->name.q(.lck) );
      $me->lockfile( $path =~ m{ \A ([ -\.\/\w.]+) \z }mx ? $1 : q() );
   }

   unless ($me->shmfile) {
      $path = catfile( $me->tempdir, $me->name.q(.shm) );
      $me->shmfile( $path =~ m{ \A ([ -\.\/\w.]+) \z }mx ? $1 : q() );
   }

   $me->serializer( Data::Serializer->new( serializer => q(Storable) ) );
   return;
}

sub _list {
   my $me   = shift; my ($lock_file, $lock_ref) = $me->_read_shmfile;
   my $self = [];

   for (keys %{ $lock_ref }) {
      push @{ $self }, { key     => $_,
                         pid     => $lock_ref->{ $_ }->{spid},
                         stime   => $lock_ref->{ $_ }->{stime},
                         timeout => $lock_ref->{ $_ }->{timeout} };
   }

   $me->_release( $lock_file );
   return $self;
}

sub _read_shmfile {
   my $me = shift; my ($e, $lock, $ref);

   umask $me->umask;

   unless ($lock = IO::File->new( $me->lockfile, q(w), $me->mode )) {
      $me->throw( error => q(eCannotWrite), arg1 => $me->lockfile );
   }

   flock $lock, LOCK_EX;

   if (-f $me->shmfile) {
      $ref = eval { $me->serializer->retrieve( $me->shmfile ) };

      if ($e = $me->catch) {
         $me->_release( $lock ); $me->throw( $e );
      }
   }
   else { $ref = {} }

   return ($lock, $ref);
}

sub _release {
   my ($me, $lock) = @_; flock $lock, LOCK_UN; $lock->close; return;
}

sub _reset {
   my ($me, $key) = @_; my ($lock_file, $lock_ref) = $me->_read_shmfile;

   unless (exists $lock_ref->{ $key }) {
      $me->_release( $lock_file );
      $me->throw( error => q(eLockNotSet), arg1 => $key );
   }

   delete $lock_ref->{ $key };
   $me->_write_shmfile( $lock_file, $lock_ref );
   return 1;
}

sub _set {
   my ($me, $key, $pid, $timeout) = @_;
   my ($lock, $lock_file, $lock_ref, $now, $start, $text);

   $lock_ref = {}; $start = time;

   while (!$now || $lock_ref->{ $key }) {
      ($lock_file, $lock_ref) = $me->_read_shmfile; $now = time;

      if (($lock = $lock_ref->{ $key })
          && ($now > $lock->{stime} + $lock->{timeout})) {
         $me->log->error( $me->timeout_error( $key,
                                              $lock->{spid   },
                                              $lock->{stime  },
                                              $lock->{timeout} ) );
         delete $lock_ref->{ $key };
         $lock = 0;
      }

      if ($lock) {
         $me->_release( $lock_file );

         if ($me->patience && $now - $start > $me->patience) {
            $me->throw( error => q(ePatienceExpired), arg1 => $key );
         }

         usleep( 1_000_000 * $me->nap_time );
      }
   }

   $lock_ref->{ $key } = { spid    => $pid,
                           stime   => $now,
                           timeout => $timeout };
   $me->_write_shmfile( $lock_file, $lock_ref );
   $text = join q(,), $key, $pid, $now, $timeout;
   $me->log->debug( 'Set lock '.$text."\n" ) if ($me->debug);
   return 1;
}

sub _write_shmfile {
   my ($me, $lock_file, $lock_ref) = @_; my ($e, $wtr);

   unless ($wtr = IO::AtomicFile->new( $me->shmfile, q(w), $me->mode )) {
      $me->_release( $lock_file );
      $me->throw( error => q(eCannotWrite), arg1 => $me->shmfile );
   }

   eval { $me->serializer->store( $lock_ref, $wtr ) };

   if ($e = $me->catch) {
      $wtr->delete; $me->_release( $lock_file ); $me->throw( $e );
   }

   $wtr->close; $me->_release( $lock_file );
   return;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
