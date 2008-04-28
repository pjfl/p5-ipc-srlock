package IPC::SRLock;

# @(#)$Id$

use strict;
use warnings;
use base qw(Class::Accessor::Fast);
use Class::Inspector;
use Class::Null;
use Date::Format;
use English qw(-no_match_vars);
use IPC::SRLock::ExceptionClass;
use Time::Elapsed qw(elapsed);
use Readonly;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

Readonly my %ATTRS =>
   ( debug     => 0,
     log       => undef,
     name      => (lc join q(_), split m{ :: }mx, __PACKAGE__),
     nap_time  => 0.5,
     patience  => 0,
     pid       => undef,
     time_out  => 300,
     type      => q(fcntl), );

__PACKAGE__->mk_accessors( keys %ATTRS );

my $_lock_obj;

sub new {
   my ($me, @rest) = @_;

   unless ($_lock_obj) {
      my $args   = $me->_arg_list( @rest );
      my $attrs  = $me->_hash_merge( \%ATTRS, $args );
      my $class  = __PACKAGE__.q(::).(ucfirst $attrs->{type});
      $me->_ensure_class_loaded( $class );
      $_lock_obj = bless $attrs, $class;
      $_lock_obj->log(   $_lock_obj->log || Class::Null->new() );
      $_lock_obj->pid(   $PID );
      $_lock_obj->_init( $args );
   }

   return $_lock_obj;
}

sub catch {
   my ($me, @rest) = @_; return IPC::SRLock::ExceptionClass->catch( @rest );
}

sub clear_lock_obj {
   # Only for the test suite to re-initialise the lock instance
   $_lock_obj = 0; return;
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
   my $me = shift; return $me->_list;
}

sub reset {
   my ($me, @rest) = @_; my $args = $me->_arg_list( @rest );

   $me->throw( q(eNoKey) ) unless (my $key = $args->{k});

   return $me->_reset( $key );
}

sub set {
   my ($me, @rest) = @_; my $args = $me->_arg_list( @rest );

   $me->throw( q(eNoKey) )       unless (my $key = $args->{k});
   $me->throw( q(eNoProcessId) ) unless (my $pid = $args->{p} || $me->pid);

   return $me->_set( $key, $pid, $args->{t} || $me->time_out );
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
   my ($me, @rest) = @_; return IPC::SRLock::ExceptionClass->throw( @rest );
}

sub timeout_error {
   my ($me, $key, $pid, $when, $after) = @_; my $text;

   $text  = 'Timed out '.$key.' set by '.$pid;
   $text .= ' on '.time2str( q(%Y-%m-%d at %H:%M), $when );
   $text .= ' after '.$after.' seconds'."\n";
   return $text;
}

# Private methods

sub _arg_list {
   my ($me, @rest) = @_;

   return $rest[0] && ref $rest[0] ? $rest[0] : { @rest };
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

sub _hash_merge {
   my ($me, $l, $r) = @_; return { %{ $l }, %{ $r || {} } };
}

sub _init {
   return;
}

sub _list {
   my $me = shift;

   $me->throw( error => q(eNotOverridden), arg1 => q(list) );
   return;
}

sub _reset {
   my $me = shift;

   $me->throw( error => q(eNotOverridden), arg1 => q(reset) );
   return;
}

sub _set {
   my $me = shift;

   $me->throw( error => q(eNotOverridden), arg1 => q(set) );
   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { tempdir => q(path_to_tmp_directory), type => q(fcntl) };

   my $lock_obj = IPC::SRLock->new( $config );

   $lock_obj->set( k => q(some_resource_identfier) );

   # This critical region of code is guaranteed to be single threaded

   $lock_obj->reset( k => q(some_resource_identfier) );

=head1 Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

=head1 Subroutines/Methods

=head2 new

Implements the singleton pattern. The B<type> attribute determines
which factory subclass is loaded. This package contains three
subclasses; B<fcntl>, B<memcached> and B<sysv>

=head3 fcntl

Uses L<Fcntl> to lock access to a disk based file which is
read/written by L<XML::Simple>. This is the default type. Files are in
B<tempdir> which defaults to I</tmp>

=head3 memcached

Uses L<Cache::Memcached> to implement a distributed lock manager. The
B<servers> attribute defaults to I<localhost:11211>

=head3 sysv

Uses System V semaphores to lock access to a shared memory file

=head2 catch

Expose the C<catch> method in L<IPC::SRLock::ExceptionClass>

=head2 clear_lock_obj

Sets the internal variable that holds the self referential object to
false. This lets the test script create multiple lock objects with
different factory subclasses

=head2 get_table

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
L<HTML::FormWidgets>

=head2 list

Returns an array of hash refs that represent the current lock table

=head2 reset

Resets the lock referenced by the B<k> attribute.

=head2 set

Sets the specified lock. Attributes are:

=over 3

=item B<k>

Unique key to identify the lock. Mandatory no default

=item B<p>

Explicitly set the process id associated with the lock. Defaults to
the current process id

=item B<t>

Set the time to live for this lock. Defaults to five minutes. Setting
it to zero makes the lock last indefinitely

=back

=head2 table_view

   $lock_obj->table_view( $stash, $model );

The C<$model> object's methods store the result of calling
C<$lock_obj-E<gt>get_table> on the C<$stash> hash ref

=head2 throw

Expose the C<throw> method in C<IPC::SRLock::ExceptionClass>

=head2 timeout_error

Return the text of the the timeout message

=head2 _arg_list

   my $args = $me->_arg_list( @rest );

Returns a hash ref containing the passed parameter list. Enables
methods to be called with either a list or a hash ref as it's input
parameters

=head2 _ensure_class_loaded

   $me->_ensure_class_loaded( $some_class );

Require the requested class, throw an error if it doesn't load

=head2 _hash_merge

   my $hash = $me->_hash_merge( { key1 => val1 }, { key2 => val2 } );

Simplistic merging of two hashes

=head2 _init

Called by the constructor. Optionally overridden in the factory
subclass. This allows subclass specific initialisation

=head2 _list

Should be overridden in the factory subclass

=head2 _reset

Should be overridden in the factory subclass

=head2 _set

Should be overridden in the factory subclass

=head1 Diagnostics

Setting C<$app-E<gt>debug> to true will cause the C<set> methods to log
the lock record at the debug level, calls C<$app-E<gt>log-E<gt>debug>

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Cache::Memcached>

=item L<Class::Accessor::Fast>

=item L<Class::Inspector>

=item L<Class::Null>

=item L<Date::Format>

=item L<IO::AtomicFile>

=item L<IO::File>

=item L<IPC::SRLock::ExceptionClass>

=item L<IPC::SysV>

=item L<Readonly>

=item L<Time::Elapsed>

=item L<Time::HiRes>

=item L<XML::Simple>

=back

=head1 Incompatibilities

Testing of the B<sysv> subclass is skiped on: cygwin, freebsd, netbsd
and solaris because CPAN testing on these platforms fails

Testing of the B<memcached> subclass is skipped on all platforms as it
requires C<memcached> to be listening on the localhost's default
memcached port

Automated testing of B<sysv> has been stopped because the testing
platforms produce inconsistant results

Reduced testing further due to inconsistant CPAN testing results. Last try
after this will just exit 0 if $ENV{AUTOMATED_TESTING}

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2008 Peter Flanigan. All rights reserved.

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
