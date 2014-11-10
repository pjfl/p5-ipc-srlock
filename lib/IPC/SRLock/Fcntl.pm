package IPC::SRLock::Fcntl;

use namespace::autoclean;

use Moo;
use English                    qw( -no_match_vars );
use File::DataClass::Constants qw( LOCK_BLOCKING LOCK_NONBLOCKING );
use File::DataClass::Types     qw( Directory NonEmptySimpleStr
                                   Path PositiveInt RegexpRef );
use File::Spec;
use Storable                   qw( nfreeze thaw );
use Time::HiRes                qw( usleep );
use Try::Tiny;

extends q(IPC::SRLock::Base);

# Public attributes
has 'mode'    => is => 'ro', isa => PositiveInt, default => oct '0666';

has 'pattern' => is => 'ro', isa => RegexpRef,
   default    => sub { qr{ \A ([ ~:+./\-\\\w]+) \z }msx };

has 'tempdir' => is => 'ro', isa => Directory, coerce => Directory->coercion,
   default    => sub { File::Spec->tmpdir };

has 'umask'   => is => 'ro', isa => PositiveInt, default => 0;

# Private attributes
has '_lockfile'      => is => 'lazy', isa => Path, coerce => Path->coercion;

has '_lockfile_name' => is => 'ro',   isa => NonEmptySimpleStr,
   init_arg          => 'lockfile';

has '_shmfile'       => is => 'lazy', isa => Path, coerce => Path->coercion;

has '_shmfile_name'  => is => 'ro',   isa => NonEmptySimpleStr,
   init_arg          => 'shmfile';

# Private methods
sub _build__lockfile {
   my $self = shift; my $path = $self->_lockfile_name;

   $path ||= $self->tempdir->catfile( $self->name.'.lck' );
   $path =~ $self->pattern
      or $self->throw( 'Path [_1] cannot untaint', args => [ $path ] );
   return $path;
}

sub _build__shmfile {
   my $self = shift; my $path = $self->_shmfile_name;

   $path ||= $self->tempdir->catfile( $self->name.'.shm' );
   $path =~ $self->pattern
      or $self->throw( 'Path [_1] cannot untaint', args => [ $path ] );
   return $path;
}

sub _list {
   my $self = shift; my $list = [];

   my ($lock_file, $shm_content) = $self->_read_shmfile; $lock_file->close;

   while (my ($key, $info) = each %{ $shm_content }) {
      push @{ $list }, { key     => $key,
                         pid     => $info->{spid},
                         stime   => $info->{stime},
                         timeout => $info->{timeout} };
   }

   return $list;
}

sub _read_shmfile {
   my ($self, $async) = @_; my ($file, $content);

   my $old_umask = umask $self->umask;
   my $mode      = $async ? LOCK_NONBLOCKING : LOCK_BLOCKING;
   my $shmfile   = $self->_shmfile;

   try {
      $file = $self->_lockfile->lock( $mode )->assert_open( 'w', $self->mode );
   }
   catch { umask $old_umask; $self->throw( $_ ) };

   if ($file->have_lock and $shmfile->exists) {
      try   { $content = thaw $shmfile->all }
      catch { $file->close; umask $old_umask; $self->throw( $_ ) };
   }
   else { $content = {} }

   $shmfile->close; umask $old_umask;
   return ($file, $content);
}

sub _reset {
   my ($self, $key) = @_; my $found;

   my ($lock_file, $shm_content) = $self->_read_shmfile;

   $found = exists $shm_content->{ $key } and delete $shm_content->{ $key };
   $found and $self->_write_shmfile( $lock_file, $shm_content );
   $lock_file->close;
   $found or $self->throw( 'Lock [_1] not set', args => [ $key ] );
   return 1;
}

sub _set {
   my ($self, $args) = @_; my $start = time;

   my $key = $args->{k}; my $pid = $args->{p}; my $timeout = $args->{t};

   while (1) {
      my ($lock_file, $shm_content) = $self->_read_shmfile( $args->{async} );

      my $now = time; my $lock;

      if ($lock_file->have_lock) {
         if ($lock = $shm_content->{ $key }
             and $now > $lock->{stime} + $lock->{timeout}) {
            $self->log->error( $self->timeout_error( $key,
                                                     $lock->{spid   },
                                                     $lock->{stime  },
                                                     $lock->{timeout} ) );
            delete $shm_content->{ $key };
            $lock = 0;
         }

         unless ($lock) {
            $shm_content->{ $key }
               = { spid => $pid, stime => $now, timeout => $timeout };
            $self->_write_shmfile( $lock_file, $shm_content );
            $self->log->debug( "Lock ${key} set by ${pid}" );
            return 1;
         }
      }

      $lock_file->close; $args->{async} and return 0;

      $self->patience and $now > $start + $self->patience
         and $self->throw( 'Lock [_1] timed out', args => [ $key ] );

      usleep( 1_000_000 * $self->nap_time );
   }

   return; # Not reached
}

sub _write_shmfile {
   my ($self, $file, $content) = @_; my $wtr;

   try   { $wtr = $self->_shmfile->assert_open( 'w', $self->mode ) }
   catch { $file->close; $self->throw( $_ ) };

   try   { $wtr->print( nfreeze $content ) }
   catch { $wtr->delete; $file->close; $self->throw( $_ ) };

   $wtr->close; $file->close;
   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Fcntl - Set/reset locks using fcntl

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { tempdir => q(path_to_tmp_directory), type => q(fcntl) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses L<Fcntl> to lock access to a disk based file which is
read/written in L<Storable> format. This is the default type for
L<IPC::SRLock>.

=head1 Configuration and Environment

This class defines accessors for these attributes:

=over 3

=item C<lockfile>

Path to the file used by fcntl

=item C<mode>

File mode to use when creating the lock table file. Defaults to 0666

=item C<pattern>

Regexp used to untaint file names

=item C<shmfile>

Path to the lock table file

=item C<tempdir>

Path to the directory where the lock files reside. Defaults to
C<File::Spec-E<gt>tmpdir>

=item C<umask>

The umask to set when creating the lock table file. Defaults to 0

=back

=head1 Subroutines/Methods

=head2 _list

List the contents of the lock table

=head2 _read_shmfile

Read the file containing the lock table from disk

=head2 _reset

Delete a lock from the lock table

=head2 _set

Set a lock in the lock table

=head2 _write_shmfile

Write the lock table to the disk file

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass>

=item L<IPC::SRLock::Base>

=item L<Moo>

=item L<Storable>

=item L<Time::HiRes>

=item L<Try::Tiny>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
