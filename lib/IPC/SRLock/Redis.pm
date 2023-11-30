package IPC::SRLock::Redis;

use IPC::SRLock::Utils     qw( hash_from loop_until throw );
use File::DataClass::Types qw( HashRef NonEmptySimpleStr );
use List::Util             qw( shuffle );
use Type::Utils            qw( class_type );
use Redis;
use Moo;

extends q(IPC::SRLock::Base);

# Public attributes
has 'lockfile' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   default => sub { shift->name . '_lockfile' };

has 'redis' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub { { server => 'localhost:6379' } };

has 'shmfile' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   default => sub { shift->name . '_shmfile' };

# Private attributes
has '_redis' =>
   is      => 'lazy',
   isa     => class_type('Redis'),
   default => sub {
      my $self   = shift;
      my $params = $self->redis;

      throw 'No Redis config' unless scalar keys %{$params};

      throw 'No recognisable Redis config' unless exists $params->{sentinel}
         || exists $params->{server} || exists $params->{socket};

      if (exists $params->{sentinel}) {
         my @sentinels = split m{ , \s* }mx, delete $params->{sentinel};

         @sentinels = shuffle @sentinels if $params->{ordering} eq 'random';

         $params->{sentinels} = \@sentinels;
         delete $params->{ordering};
      }

      $params->{on_connect} = sub {
         my $redis      = shift;
         my $start_time = time;

         while (!$redis->ping) {
            sleep 1; return 0 if time - $start_time > 3600;
         }

         return 1;
      };

      $params->{debug} = $self->debug;
      $params->{name} = $self->name;

      return Redis->new(%{$params});
   };

# Public methods
sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;

    $self->_redis->quit unless $in_global_destruction;
    return;
}

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
   my ($self, $key, @fields) = @_;

   $self->log->error(
      $self->_timeout_error($key, $fields[0], $fields[1], $fields[2])
   );

   $self->_redis->hdel($self->shmfile, $key);
   return 0;
}

sub _list {
   my $self = shift;

   return 0 unless $self->_lock_share;

   my $shm_content = hash_from $self->_redis->hgetall($self->shmfile);

   $self->_unlock_share;

   my $list = [];

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

sub _lock_share {
   my $self = shift;

   $self->_redis->set($self->lockfile, 1, 'EX', $self->patience, 'NX');
   return 1;
}

sub _reset {
   my ($self, $args, $now) = @_;

   my $key = $args->{k};
   my $pid = $args->{p};

   return 0 unless $self->_lock_share;

   my $lock = $self->_redis->hget($self->shmfile, $key);

   if ($lock) {
      if ((split m{ , }mx, $lock)[0] != $pid) {
         $self->_unlock_share;
         throw 'Lock [_1] set by another process', [$key];
      }
   }

   unless ($lock) {
      $self->_unlock_share;
      throw 'Lock [_1] not set', [$key];
   }

   $self->_redis->hdel($self->shmfile, $key);
   $self->_unlock_share;
   return 1;
}

sub _set {
   my ($self, $args, $now) = @_;

   my $key     = $args->{k};
   my $pid     = $args->{p};
   my $timeout = $args->{t};

   return 0 unless $self->_lock_share;

   my $lock = $self->_redis->hget($self->shmfile, $key);

   if ($lock) {
      my @fields = split m{ , }mx, $lock;

      $lock = $self->_expire_lock($key, @fields)
         if $fields[2] and $now > $fields[1] + $fields[2];
   }

   if ($lock) {
      $self->_unlock_share;
      return 0;
   }

   $self->_redis->hset($self->shmfile, $key, "${pid},${now},${timeout}");
   $self->_unlock_share;
   $self->log->debug("Lock ${key} set by ${pid}");
   return 1;
}

sub _unlock_share {
   my $self = shift;

   $self->_redis->del($self->lockfile);
   return 1;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

IPC::SRLock::Redis - Implements the factory lock class using a Redis server

=head1 Synopsis

   use IPC::SRLock::Redis;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

Defines the following public methods;

=over 3

=item C<DEMOLISH>

Quits the L<Redis> session when this instance goes out of scope

=cut

=item C<list>

=item C<reset>

=item C<set>

=back

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Redis>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=IPC-SRLock.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

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
# vim: expandtab shiftwidth=3:
