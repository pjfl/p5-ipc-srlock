package IPC::SRLock::Memcached;

use namespace::autoclean;

use Cache::Memcached;
use English                qw( -no_match_vars );
use File::DataClass::Types qw( ArrayRef NonEmptySimpleStr Object );
use IPC::SRLock::Functions qw( Unspecified hash_from throw );
use Moo;

extends q(IPC::SRLock::Base);

# Public attributes
has 'lockfile' => is => 'ro', isa => NonEmptySimpleStr, default => '_lockfile';

has 'servers'  => is => 'ro', isa => ArrayRef,
   default     => sub { [ 'localhost:11211' ] };

has 'shmfile'  => is => 'ro', isa => NonEmptySimpleStr, default => '_shmfile';

# Private attributes
has '_memd'    => is => 'lazy', isa => Object, reader => 'memd',
   builder     => sub { Cache::Memcached->new
                           ( debug     => $_[ 0 ]->debug,
                             namespace => $_[ 0 ]->name,
                             servers   => $_[ 0 ]->servers ) };

# Public methods
sub list {
   my $self = shift; my $list = []; my $start = time;

   do {
      # uncoverable branch true
      $self->memd->add( $self->lockfile, 1, $self->patience + 30 ) or next;

      my $shm_content = $self->memd->get( $self->shmfile ) // {};

      $self->memd->delete( $self->lockfile );

      for my $key (sort keys %{ $shm_content }) {
         my @fields = split m{ , }mx, $shm_content->{ $key };

         push @{ $list }, { key     => $key,
                            pid     => $fields[ 0 ],
                            stime   => $fields[ 1 ],
                            timeout => $fields[ 2 ] };
      }

      return $list;

   } while ($self->sleep_or_throw( $start, $self->lockfile ));

   return; # uncoverable statement
}

sub reset {
   my $self = shift; my $args = hash_from @_; my $start = time;

   my $key = $args->{k} or throw Unspecified, [ 'key' ]; $key = "${key}";

   do {
      # uncoverable branch true
      $self->memd->add( $self->lockfile, 1, $self->patience + 30 ) or next;

      my $shm_content = $self->memd->get( $self->shmfile ) // {};
      my $found = 0; delete $shm_content->{ $key } and $found = 1;

      $found and $self->memd->set( $self->shmfile, $shm_content );
      $self->memd->delete( $self->lockfile );
      $found and return 1;
      throw 'Lock [_1] not set', [ $key ];

   } while ($self->sleep_or_throw( $start, $self->lockfile ));

   return; # uncoverable statement
}

sub set {
   my $self = shift; my $args = $self->_get_args( @_ ); my $start = time;

   my $key = $args->{k}; my $pid = $args->{p}; my $timeout = $args->{t};

   do {
      # uncoverable branch true
      $self->memd->add( $self->lockfile, 1, $self->patience + 30 ) or next;

      my $shm_content = $self->memd->get( $self->shmfile ) // {};

      my $now = time; my $lock;

      if ($lock = $shm_content->{ $key }) {
         my @fields = split m{ , }mx, $lock;

         if ($fields[ 2 ] and $now > $fields[ 1 ] + $fields[ 2 ]) {
            $self->log->error( $self->_timeout_error
               ( $key, $fields[ 0 ], $fields[ 1 ], $fields[ 2 ] ) );
            $lock = 0;
         }
      }

      unless ($lock) {
         $shm_content->{ $key } = "${pid},${now},${timeout}";
         $self->memd->set( $self->shmfile, $shm_content );
         $self->memd->delete( $self->lockfile );
         $self->log->debug( "Lock ${key} set by ${pid}" );
         return 1;
      }

      $self->memd->delete( $self->lockfile ); $args->{async} and return 0;

   } while ($self->sleep_or_throw( $start, $self->lockfile ));

   return; # uncoverable statement
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

IPC::SRLock::Memcached - Set / reset locks using libmemcache

=head1 Synopsis

   use IPC::SRLock;

   my $config = { type => q(memcached) };

   my $lock_obj = IPC::SRLock->new( $config );

=head1 Description

Uses L<Cache::Memcached> to implement a distributed lock manager

=head1 Configuration and Environment

This class defines accessors for these attributes:

=over 3

=item C<lockfile>

Name of the key to the lock file record. Defaults to C<_lockfile>

=item C<servers>

An array ref of servers to connect to. Defaults to C<localhost:11211>

=item C<shmfile>

Name of the key to the lock table record. Defaults to C<_shmfile>

=back

=head1 Subroutines/Methods

=head2 list

List the contents of the lock table

=head2 reset

Delete a lock from the lock table

=head2 set

Set a lock in the lock table

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Cache::Memcached>

=item L<File::DataClass>

=item L<IPC::SRLock::Base>

=item L<Moo>

=item L<Time::HiRes>

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
