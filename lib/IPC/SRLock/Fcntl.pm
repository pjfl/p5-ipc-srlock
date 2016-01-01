package IPC::SRLock::Fcntl;

use namespace::autoclean;

use English                    qw( -no_match_vars );
use File::DataClass::Constants qw( LOCK_BLOCKING LOCK_NONBLOCKING );
use File::DataClass::Types     qw( Directory NonEmptySimpleStr
                                   OctalNum Path PositiveInt RegexpRef );
use File::Spec;
use IPC::SRLock::Functions     qw( Unspecified hash_from loop_until throw );
use Storable                   qw( nfreeze thaw );
use Try::Tiny;
use Moo;

extends q(IPC::SRLock::Base);

# Attribute constructors
my $_build__lockfile = sub {
   my $self = shift; my $path = $self->_lockfile_name;

   $path ||= $self->tempdir->catfile( $self->name.'.lck' );
   $path  =~ $self->pattern or throw 'Path [_1] cannot untaint', [ $path ];

   return $path;
};

my $_build__shmfile = sub {
   my $self = shift; my $path = $self->_shmfile_name;

   $path ||= $self->tempdir->catfile( $self->name.'.shm' );
   $path  =~ $self->pattern or throw 'Path [_1] cannot untaint', [ $path ];

   return $path;
};

# Public attributes
has 'mode'    => is => 'ro', isa => OctalNum, coerce => 1, default => '0666';

has 'pattern' => is => 'ro', isa => RegexpRef,
   default    => sub { qr{ \A ([ ~:+./\-\\\w]+) \z }msx };

has 'tempdir' => is => 'ro', isa => Directory, coerce => 1,
   default    => sub { File::Spec->tmpdir };

has 'umask'   => is => 'ro', isa => PositiveInt, default => 0;

# Private attributes
has '_lockfile'      => is => 'lazy', isa => Path, coerce => 1,
   builder           => $_build__lockfile;

has '_lockfile_name' => is => 'ro',   isa => NonEmptySimpleStr,
   init_arg          => 'lockfile';

has '_shmfile'       => is => 'lazy', isa => Path, coerce => 1,
   builder           => $_build__shmfile;

has '_shmfile_name'  => is => 'ro',   isa => NonEmptySimpleStr,
   init_arg          => 'shmfile';

# Private methods
my $_expire_lock = sub {
   my ($self, $content, $key, $lock) = @_;

   $self->log->error
      ( $self->_timeout_error
        ( $key, $lock->{spid}, $lock->{stime}, $lock->{timeout} ) );

   delete $content->{ $key };
   return 0;
};

my $_read_shmfile = sub {
   my ($self, $async) = @_; my ($file, $content);

   my $old_umask = umask $self->umask;
   my $mode      = $async ? LOCK_NONBLOCKING : LOCK_BLOCKING;
   my $shmfile   = $self->_shmfile;

   try {
      $file = $self->_lockfile->lock( $mode )->assert_open( 'w', $self->mode );
   }
   catch { umask $old_umask; throw $_ };

   if ($file->have_lock and $shmfile->exists) {
      try   { $content = thaw $shmfile->all }
      catch { $file->close; umask $old_umask; throw $_ };
   }
   else { $content = {} }

   $shmfile->close; umask $old_umask;
   return ($file, $content);
};

my $_write_shmfile = sub {
   my ($self, $file, $content) = @_; my $wtr;

   try   { $wtr = $self->_shmfile->assert_open( 'w', $self->mode ) }
   catch { $file->close; throw $_ };

   try   { $wtr->print( nfreeze $content ) }
   catch { $wtr->delete; $file->close; throw $_ };

   $wtr->close; $file->close;
   return;
};

my $_set = sub {
   my ($self, $args, $now) = @_; my $key = $args->{k}; my $pid = $args->{p};

   my ($lock_file, $shm_content) = $self->$_read_shmfile( $args->{async} );

   if ($lock_file->have_lock) {
      my $lock; exists $shm_content->{ $key }
         and $lock = $shm_content->{ $key }
         and $lock->{timeout}
         and $now > $lock->{stime} + $lock->{timeout}
         and $lock = $self->$_expire_lock( $shm_content, $key, $lock );

      unless ($lock) {
         $shm_content->{ $key }
            = { spid => $pid, stime => $now, timeout => $args->{t} };
         $self->$_write_shmfile( $lock_file, $shm_content );
         $self->log->debug( "Lock ${key} set by ${pid}" );
         return 1;
      }
   }

   $lock_file->close;
   return 0;
};

# Public methods
sub list {
   my $self = shift; my $list = [];

   my ($lock_file, $shm_content) = $self->$_read_shmfile; $lock_file->close;

   while (my ($key, $info) = each %{ $shm_content }) {
      push @{ $list }, { key     => $key,
                         pid     => $info->{spid},
                         stime   => $info->{stime},
                         timeout => $info->{timeout} };
   }

   return $list;
}

sub reset {
   my $self  = shift;
   my $args  = hash_from @_;
   my $key   = $args->{k} or throw Unspecified, [ 'key' ]; $key = "${key}";
   my ($lock_file, $shm_content) = $self->$_read_shmfile;
   my $found = delete $shm_content->{ $key };

   $found and $self->$_write_shmfile( $lock_file, $shm_content );
   $lock_file->close; $found or throw 'Lock [_1] not set', [ $key ];
   return 1;
}

sub set {
   my ($self, @args) = @_; return loop_until( $_set )->( $self, @args );
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

IPC::SRLock::Fcntl - Set / reset locks using fcntl

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

=head2 list

List the contents of the lock table

=head2 _read_shmfile

Read the file containing the lock table from disk

=head2 reset

Delete a lock from the lock table

=head2 set

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

Copyright (c) 2016 Peter Flanigan. All rights reserved

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
