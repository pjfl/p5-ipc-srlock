package IPC::SRLock::Memcached;

use namespace::autoclean;

use IPC::SRLock::Constants qw( EXCEPTION_CLASS );
use IPC::SRLock::Utils     qw( hash_from loop_until throw );
use Cache::Memcached;
use English                qw( -no_match_vars );
use File::DataClass::Types qw( ArrayRef NonEmptySimpleStr Object );
use Unexpected::Functions  qw( Unspecified );
use Moo;

extends q(IPC::SRLock::Base);

# Public attributes
has 'lockfile' => is => 'ro', isa => NonEmptySimpleStr, default => '_lockfile';

has 'servers'  => is => 'ro', isa => ArrayRef,
   default     => sub { [ 'localhost:11211' ] };

has 'shmfile'  => is => 'ro', isa => NonEmptySimpleStr, default => '_shmfile';

# Private attributes
has '_memd' =>
   is      => 'lazy',
   isa     => Object,
   reader  => 'memd',
   builder => sub {
      my $self = shift;

      return Cache::Memcached->new(
         debug     => $self->debug,
         namespace => $self->name,
         servers   => $self->servers
      )
   };

# Public methods
sub list {
   my $self = shift;

   return loop_until(\&_list)->($self, { k => 'dummy' });
}

sub reset {
   my ($self, @args) = @_;

   return loop_until(\&_reset)->($self, @args);
}

sub set {
   my ($self, @args) = @_;

   return loop_until(\&_set)->($self, @args);
}

# Private methods
sub _expire_lock {
   my ($self, $data, $key, @fields) = @_;

   $self->log->error(
      $self->_timeout_error($key, $fields[0], $fields[1], $fields[2])
   );

   delete $data->{$key};
   return 0;
}

sub _unlock_share {
   my $self = shift;

   $self->memd->delete($self->lockfile);
   return 1;
}

sub _list {
   my $self = shift;

   return 0 unless $self->memd->add($self->lockfile, 1, $self->patience + 30);

   my $shm_content = $self->memd->get($self->shmfile) // {};
   my $list        = [];

   $self->_unlock_share;

   for my $key (sort keys %{$shm_content}) {
      my @fields = split m{ , }mx, $shm_content->{$key};

      push @{$list}, {
         key     => $key,
         pid     => $fields[0],
         stime   => $fields[1],
         timeout => $fields[2],
      };
   }

   return $list;
}

sub _reset {
   my ($self, $args, $now) = @_;

   my $key = $args->{k};
   my $pid = $args->{p};

   return 0 unless $self->memd->add($self->lockfile, 1, $self->patience + 30);

   my $shm_content = $self->memd->get($self->shmfile) // {};

   my $lock;

   if (exists $shm_content->{$key}) {
      $lock = $shm_content->{$key}

      if ((split m{ , }mx, $lock)[ 0 ] != $pid) {
         $self->_unlock_share;
         throw 'Lock [_1] set by another process', [$key];
      }
   }

   unless (delete $shm_content->{$key}) {
      $self->_unlock_share
      throw 'Lock [_1] not set', [$key];
   }

   $self->memd->set($self->shmfile, $shm_content);
   $self->_unlock_share;
   return 1;
};

sub _set {
   my ($self, $args, $now) = @_;

   my $key     = $args->{k};
   my $pid     = $args->{p};
   my $timeout = $args->{t};

   return 0 unless $self->memd->add($self->lockfile, 1, $self->patience + 30);

   my $shm_content = $self->memd->get($self->shmfile) // {};
   my $lock;

   if ($lock = $shm_content->{$key}) {
      my @fields = split m{ , }mx, $lock;

      $lock = $self->_expire_lock($shm_content, $key, @fields)
         if $fields[2] and $now > $fields[1] + $fields[2];
   }

   if ($lock) {
      $self->_unlock_share;
      return 0;
   }

   $shm_content->{$key} = "${pid},${now},${timeout}";
   $self->memd->set($self->shmfile, $shm_content);
   $self->_unlock_share;
   $self->log->debug("Lock ${key} set by ${pid}");
   return 1;
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

=item L<File::DataClass::Types>

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

Copyright (c) 2021 Peter Flanigan. All rights reserved

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
