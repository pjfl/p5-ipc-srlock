# @(#)$Ident: Exception.pm 2013-05-05 10:02 pjf ;

package IPC::SRLock::Exception;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Exception::Class
   'IPC::SRLock::Exception::Base' => { fields => [qw(args out rv)] };

use base qw(IPC::SRLock::Exception::Base);

use Carp;
use English      qw(-no_match_vars);
use Scalar::Util qw(blessed);
use MRO::Compat;

our $IGNORE = [ __PACKAGE__ ];

my $NUL = q();

sub new {
   my ($self, @rest) = @_;

   return $self->next::method( args           => [],
                               error          => 'Error unknown',
                               ignore_package => $IGNORE,
                               out            => $NUL,
                               rv             => 1,
                               @rest );
}

sub catch {
   my ($self, $e) = @_; $e ||= $EVAL_ERROR;

   $e and blessed $e and $e->isa( __PACKAGE__ ) and return $e;

   return $e ? $self->new( error => $NUL.$e ) : undef;
}

sub full_message {
   my $self = shift; my $text = $self->error or return;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, '[_' and return $text;

   my @args = map { defined $_ ? $_ : '[?]' } @{ $self->args },
              map { '[?]' } 0 .. 9;

   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;

   return $text;
}

sub stacktrace {
   my ($self, $skip) = @_; my ($l_no, @lines, %seen, $subr);

   for my $frame (reverse $self->trace->frames) {
      unless ($l_no = $seen{ $frame->package } and $l_no == $frame->line) {
         $subr and push @lines, join q( ), $subr, 'line', $frame->line;
         $seen{ $frame->package } = $frame->line;
      }

      $subr = $frame->subroutine;
   }

   defined $skip or $skip = 1; pop @lines while ($skip--);

   return (join "\n", reverse @lines)."\n";
}

sub throw {
   my ($self, @rest) = @_; my $e = $rest[ 0 ];

   $e and blessed $e and $e->isa( __PACKAGE__ ) and croak $e;

   croak $self->new( @rest == 1 ? ( error => $NUL.$e ) : @rest );
}

sub throw_on_error {
   my ($self, @rest) = @_; my $e;

   $e = $self->catch( @rest ) and $self->throw( $e );

   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock::Exception - Exception class

=head1 Version

This documents version v0.10.$Rev: 1 $

=head1 Synopsis

=head1 Description

Implements throw and catch error semantics. Inherits from
L<Exception::Class>

=head1 Subroutines/Methods

=head2 new

Create an exception object. You probably do not want to call this directly,
but indirectly through L</catch> and L</throw>

=head2 catch

   $e = IPC::SRLock::Exception->catch( $error );

Catches and returns a thrown exception or generates a new exception if
I<EVAL_ERROR> has been set

=head2 full_message

   $printable_string = $e->full_message

What an instance of this class stringifies to

=head2 stacktrace

   $lines = $e->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping one (the first) line of output

=head2 throw

   IPC::SRLock::Exception->throw( $error );

Create (or re-throw) an exception to be caught by the catch above. If
the passed parameter is a reference it is re-thrown. If a single scalar
is passed it is taken to be an error message code, a new exception is
created with all other parameters taking their default values. If more
than one parameter is passed the it is treated as a list and used to
instantiate the new exception. The 'error' parameter must be provided
in this case

=head2 throw_on_error

   IPC::SRLock::Exception->throw_on_error( $error );

Calls L</catch> and if the was an exception L</throw>s it

=head1 Diagnostics

None

=head1 Configuration and Environment

The C<$IGNORE> package variable is list of methods whose presence
should be suppressed in the stack trace output

=head1 Dependencies

=over 3

=item L<Exception::Class>

=item L<MRO::Compat>

=item L<Scalar::Util>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
The default ignore package list should be configurable.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
