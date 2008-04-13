package IPC::SRLock;

# @(#)$Id: Lock.pm 66 2008-04-13 02:42:19Z pjf $

use strict;
use warnings;
use base qw(Class::Accessor::Fast);
use Class::Inspector;
use Class::Null;
use Date::Format;
use English qw(-no_match_vars);
use Fcntl qw(:flock);
use File::Spec::Functions;
use IO::File;
use IO::AtomicFile;
use IPC::SRLock::Errs;
use IPC::SysV qw(IPC_CREAT);
use Time::Elapsed qw(elapsed);
use Time::HiRes qw(usleep);
use Readonly;
use XML::Simple;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 66 $ =~ /\d+/gmx );

Readonly my %ATTRS =>
   ( debug     => 0,
     lockfile  => 195_911_405,
     log       => undef,
     mode      => oct q(0666),
     name      => (lc join q(_), split m{ :: }mx, __PACKAGE__),
     nap_time  => 0.5,
     num_locks => 100,
     patience  => 0,
     pid       => undef,
     shmfile   => 195_911_405,
     size      => 300,
     time_out  => 300,
     tempdir   => q(/tmp),
     type      => q(fcntl),
     umask     => 0, );

__PACKAGE__->mk_accessors( keys %ATTRS );

my $_lock_obj;

sub new {
   my ($me, @rest) = @_;

   $_lock_obj = $me->_init_singleton( @rest ) unless ($_lock_obj);

   return $_lock_obj;
}

sub catch {
   my ($me, @rest) = @_; return IPC::SRLock::Errs->catch( @rest );
}

sub get_table {
   my $me = shift; my ($count, $data, $flds, $lock, $tleft);

   $count = 0;
   $data  = { align  => { id    => 'left',
                          pid   => 'right',
                          stime => 'right',
                          tleft => 'right'},
              count  => $count,
              flds   => [ qw(id pid stime tleft) ],
              labels => { id    => 'Key',
                          pid   => 'PID',
                          stime => 'Lock Time',
                          tleft => 'Time Left' },
              values => [] };

   for $lock (@{ $me->list }) {
      $flds          = {};
      $flds->{id   } = $lock->{key};
      $flds->{pid  } = $lock->{pid};
      $flds->{stime} = time2str( q(%Y-%m-%d %H:%M:%S), $lock->{stime} );
      $tleft         = $lock->{stime} + $lock->{timeout} - time;
      $flds->{tleft} = $tleft > 0 ? elapsed( $tleft ) : 'Expired';
      $flds->{class}->{tleft}
                     = $tleft < 1 ? q(error dataValue) : q(odd dataValue);
      push @{ $data->{values} }, $flds;
      $count++;
   }

   $data->{count} = $count;
   return $data;
}

sub list {
   my $me = shift;

   return $me->_list_ipc if ($me->type eq q(ipc));

   return $me->_list_fcntl;
}

sub reset {
   my ($me, @rest) = @_; my $args = $me->_arg_list( @rest );

   $me->throw( q(eNoKey) ) unless (my $key = $args->{k});

   return $me->_reset_ipc( $key ) if ($me->type eq q(ipc));

   return $me->_reset_fcntl( $key );
}

sub set {
   my ($me, @rest) = @_; my $args = $me->_arg_list( @rest ); my ($key, $pid);

   $me->throw( q(eNoKey) )       unless ($key = $args->{k});
   $me->throw( q(eNoProcessId) ) unless ($pid = $args->{p} || $me->pid);

   if ($me->type eq q(ipc)) {
      return $me->_set_ipc( $key, $pid, $args->{t} || $me->time_out );
   }

   return $me->_set_fcntl( $key, $pid, $args->{t} || $me->time_out );
}

sub table_view {
   my ($me, $s, $model) = @_; my $data = $me->get_table;

   $model->add_field(    $s, { data   => $data,
                               select => q(left),
                               type   => q(table) } );
   $model->group_fields( $s, { id     => q(lock_table_select), nitems => 1 } );
   $model->add_buttons(  $s, qw(Delete) ) if ($data->{count} > 0);
   return;
}

sub throw {
   my ($me, @rest) = @_; return IPC::SRLock::Errs->throw( @rest );
}

# Private methods

sub _arg_list {
   my ($me, @rest) = @_;

   return $rest[0] && ref $rest[0] ? $rest[0] : { @rest };
}

sub _clear_lock_obj {
   # Only for the test suite to re-initialise the lock instance
   $_lock_obj = 0; return;
}

sub _config_merge {
   my ($me, $l, $r) = @_; return { %{ $l }, %{ $r || {} } };
}

sub _ensure_class_loaded {
   my ($me, $class) = @_; my $error;

   {
## no critic
      local $@;
      eval "require $class;";
      $error = $@;
## critic
   }

   $me->throw( $error ) if ($error);

   $me->throw( error => q(eUndefinedPackage), arg1 => $class )
        unless (Class::Inspector->loaded( $class ));

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

sub _init_singleton {
   my ($me, $app) = @_;

   $app ||= Class::Null->new();

   my $config = $app->config || {};
   my $attrs  = $me->_config_merge( \%ATTRS, $config->{lock} );
   my $self   = bless $attrs, ref $me || $me;
   my $path;

   $self->debug(   $app->debug || $self->debug );
   $self->log(     $app->log || Class::Null->new() );
   $self->pid(     $PID );
   $self->tempdir( $config->{tempdir} || $self->tempdir );

   if ($self->type eq q(fcntl)) {
      $path = catfile( $self->tempdir, $self->name.q(.lck) );
      $self->lockfile( $path =~ m{ \A ([ -\.\/\w.]+) \z }mx ? $1 : q() );
      $path = catfile( $self->tempdir, $self->name.q(.shm) );
      $self->shmfile(  $path =~ m{ \A ([ -\.\/\w.]+) \z }mx ? $1 : q() );
   }

   return $self;
}

sub _list_fcntl {
   my $me = shift;
   my ($lock_file, $table) = $me->_read_shmfile();
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

sub _list_ipc {
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

sub _reset_fcntl {
   my ($me, $key) = @_; my ($lock_file, $table) = $me->_read_shmfile();

   unless (exists $table->{lock} && exists $table->{lock}->{ $key }) {
      $me->_release( $lock_file );
      $me->throw( error => q(eLockNotSet), arg1 => $key );
   }

   delete $table->{lock}->{ $key };
   $me->_write_shmfile( $lock_file, $table );
   return 1;
}

sub _reset_ipc {
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

sub _set_fcntl {
   my ($me, $key, $pid, $timeout) = @_;
   my ($lock, $lock_file, $lock_ref, $now, $start, $table, $text);

   $table = {}; $start = time;

   while (!$now || ($table->{lock} && $table->{lock}->{ $key })) {
      ($lock_file, $table) = $me->_read_shmfile();
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

sub _set_ipc {
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
         $text  = 'Timed out '.$key.' set by '.$lpid;
         $text .= ' on '.time2str( q(%Y-%m-%d at %H:%M), $ltime );
         $text .= ' after '.$ltimeout.' seconds';
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

=pod

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

0.1.$Revision: 66 $

=head1 Synopsis

   use IPC::SRLock;

   $app->config( tempdir => q(path_to_tmp_directory) );

   my $lock_obj = IPC::SRLock->new( $app );

   $lock_obj->set( k => q(some_resource_identfier) );

   # This critical region of code is guaranteed to by single threaded

   $lock_obj->reset( k => q(some_resource_identfier) );

=head1 Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

=head1 Subroutines/Methods

=head2 new

Implements the singleton pattern. Construction is done by C<_init_singleton>.

=head2 get_table

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
L<HTML::FormWidgets>

=head2 list

Returns an array of hash refs that represent the current lock table

=head2 reset

=head2 set

=head2 table_view

=head2 _clear_lock_obj

=head2 _get_semid

=head2 _get_shmid

=head2 _init_singleton

=head2 _list_fcntl

=head2 _list_ipc

=head2 _read_shmfile

=head2 _release

=head2 _reset_fcntl

=head2 _reset_ipc

=head2 _set_fcntl

=head2 _set_ipc

=head2 _write_shmfile


=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 4

=item L<Class::Accessor::Fast>

=item L<CatalystX::Usul::Class::Time>

=item L<CatalystX::Usul::Class::Utils>

=item L<Class::Null>

=item L<IO::AtomicFile>

=item L<IPC::SysV>

=item L<Time::Elapsed>

=item L<Readonly>

=item L<XML::Simple>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module.

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome.

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2008 Peter Flanigan. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
