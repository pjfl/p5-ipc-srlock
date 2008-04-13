package IPC::SRLock::Fcntl;

# @(#)$Id$

use strict;
use warnings;
use base qw(IPC::SRLock);
use Date::Format;
use Fcntl qw(:flock);
use IO::File;
use IO::AtomicFile;
use NEXT;
use Time::HiRes qw(usleep);
use XML::Simple;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

# Private methods

sub _init_singleton {
   my ($me, $app) = @_; $app ||= Class::Null->new();
   my $self       = $me->NEXT::_init_singleton( $app );
   my $config     = $app->config || {};
   my $path;

   $self->tempdir(  $config->{tempdir} || $self->tempdir );
   $path = catfile( $self->tempdir, $self->name.q(.lck) );
   $self->lockfile( $path =~ m{ \A ([ -\.\/\w.]+) \z }mx ? $1 : q() );
   $path = catfile( $self->tempdir, $self->name.q(.shm) );
   $self->shmfile(  $path =~ m{ \A ([ -\.\/\w.]+) \z }mx ? $1 : q() );
   return $self;
}

sub _list {
   my $me = shift;
   my ($lock_file, $table) = $me->_read_shmfile;
   my $lock_ref = $table->{lock};
   my $self = [];

   if ($lock_ref && ref $lock_ref eq q(HASH)) {
      for (keys %{ $lock_ref }) {
         push @{ $self }, { key     => $_,
                            pid     => $lock_ref->{ $_ }->{spid},
                            stime   => $lock_ref->{ $_ }->{stime},
                            timeout => $lock_ref->{ $_ }->{timeout} };
      }
   }

   $me->_release( $lock_file );
   return $self;
}

sub _read_shmfile {
   my $me = shift; my ($e, $lock, $ref, $xs); umask $me->umask;

   unless ($lock = IO::File->new( $me->lockfile, q(w), $me->mode )) {
      $me->throw( error => q(eCannotWrite), arg1 => $me->lockfile );
   }

   flock $lock, LOCK_EX;

   if (-f $me->shmfile) {
      $xs  = XML::Simple->new( ForceArray => [ q(lock) ], SuppressEmpty => 1 );
      $ref = eval { $xs->xml_in( $me->shmfile ) };

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
   my ($me, $key) = @_; my ($lock_file, $table) = $me->_read_shmfile;

   unless (exists $table->{lock} && exists $table->{lock}->{ $key }) {
      $me->_release( $lock_file );
      $me->throw( error => q(eLockNotSet), arg1 => $key );
   }

   delete $table->{lock}->{ $key };
   $me->_write_shmfile( $lock_file, $table );
   return 1;
}

sub _set {
   my ($me, $key, $pid, $timeout) = @_;
   my ($lock, $lock_file, $lock_ref, $now, $start, $table, $text);

   $table = {}; $start = time;

   while (!$now || ($table->{lock} && $table->{lock}->{ $key })) {
      ($lock_file, $table) = $me->_read_shmfile;
      $lock_ref = $table->{lock} || {};
      $now = time;

      if (($lock = $lock_ref->{ $key })
          && ($now > $lock->{stime} + $lock->{timeout})) {
         $text  = 'Timed out '.$key.' set by '.$lock->{spid}.' on ';
         $text .= time2str( q(%Y-%m-%d at %H:%M), $lock->{stime} );
         $text .= ' after '.$lock->{timeout}.' seconds';
         $me->log->error( $text );
         delete $lock_ref->{ $key };
         $lock  = 0;
      }

      if ($me->patience && $now - $start > $me->patience) {
         $me->_release( $lock_file );
         $me->throw( error => q(ePatienceExpired), arg1 => $key );
      }

      if ($lock) {
         $me->_release( $lock_file ); usleep( 1_000_000 * $me->nap_time );
      }
   }

   $table->{lock}->{ $key } = { spid    => $pid,
                                stime   => $now,
                                timeout => $timeout };
   $me->_write_shmfile( $lock_file, $table );
   return 1;
}

sub _write_shmfile {
   my ($me, $lock_file, $table) = @_; my ($e, $wtr, $xs);

   unless ($wtr = IO::AtomicFile->new( $me->shmfile, q(w), $me->mode )) {
      $me->_release( $lock_file );
      $me->throw( error => q(eCannotWrite), arg1 => $me->shmfile );
   }

   $xs = XML::Simple->new( NoAttr        => 1,
                           SuppressEmpty => 1,
                           RootName      => q(table) );
   eval { $xs->xml_out( $table, OutputFile => $wtr ) };

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
