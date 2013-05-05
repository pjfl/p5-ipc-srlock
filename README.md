# Name

IPC::SRLock - Set/reset locking semantics to single thread processes

# Version

This documents version v0.10.$Rev: 2 $ of [IPC::SRLock](https://metacpan.org/module/IPC::SRLock)

# Synopsis

    use IPC::SRLock;

    my $config   = { tempdir => q(path_to_tmp_directory), type => q(fcntl) };

    my $lock_obj = IPC::SRLock->new( $config );

    $lock_obj->set( k => q(some_resource_identfier) );

    # This critical region of code is guaranteed to be single threaded

    $lock_obj->reset( k => q(some_resource_identfier) );

# Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

# Configuration and Environment

This class defines accessors and mutators for these attributes:

- `debug`

    Turns on debug output. Defaults to 0

- `log`

    If set to a log object, it's `debug` method is called if debugging is
    turned on. Defaults to [Class::Null](https://metacpan.org/module/Class::Null)

- `name`

    Used as the lock file names. Defaults to `ipc_srlock`

- `nap_time`

    How long to wait between polls of the lock table. Defaults to 0.5 seconds

- `patience`

    Time in seconds to wait for a lock before giving up. If set to 0 waits
    forever. Defaults to 0

- `pid`

    The process id doing the locking. Defaults to this processes id

- `time_out`

    Time in seconds before a lock is deemed to have expired. Defaults to 300

- `type`

    Determines which factory subclass is loaded. Defaults to `fcntl`

# Subroutines/Methods

## new

This constructor implements the singleton pattern, ensures that the
factory subclass is loaded in initialises it

## catch

Expose the `catch` method in [IPC::SRLock::ExceptionClass](https://metacpan.org/module/IPC::SRLock::ExceptionClass)

## get\_table

    my $data = $lock_obj->get_table;

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
[HTML::FormWidgets](https://metacpan.org/module/HTML::FormWidgets)

## list

    my $array_ref = $lock_obj->list;

Returns an array of hash refs that represent the current lock table

## reset

    $lock_obj->reset( k => q(some_resource_key) );

Resets the lock referenced by the `k` attribute.

## set

    $lock_obj->set( k => q(some_resource_key) );

Sets the specified lock. Attributes are:

- `k`

    Unique key to identify the lock. Mandatory no default

- `p`

    Explicitly set the process id associated with the lock. Defaults to
    the current process id

- `t`

    Set the time to live for this lock. Defaults to five minutes. Setting
    it to zero makes the lock last indefinitely

## throw

Expose the `throw` method in `IPC::SRLock::ExceptionClass`

## timeout\_error

Return the text of the the timeout message

## \_arg\_list

    my $args = $self->_arg_list( @rest );

Returns a hash ref containing the passed parameter list. Enables
methods to be called with either a list or a hash ref as it's input
parameters

## \_ensure\_class\_loaded

    $self->_ensure_class_loaded( $some_class );

Require the requested class, throw an error if it doesn't load

## \_init

Called by the constructor. Optionally overridden in the factory
subclass. This allows subclass specific initialisation

## \_list

Should be overridden in the factory subclass

## \_reset

Should be overridden in the factory subclass

## \_set

Should be overridden in the factory subclass

## \_\_hash\_merge

    my $hash = __hash_merge( { key1 => val1 }, { key2 => val2 } );

Simplistic merging of two hashes

# Diagnostics

Setting `debug` to true will cause the `set` methods to log
the lock record at the debug level

# Dependencies

- [Class::Accessor::Fast](https://metacpan.org/module/Class::Accessor::Fast)
- [Class::MOP](https://metacpan.org/module/Class::MOP)
- [Class::Null](https://metacpan.org/module/Class::Null)
- [Date::Format](https://metacpan.org/module/Date::Format)
- [IPC::SRLock::ExceptionClass](https://metacpan.org/module/IPC::SRLock::ExceptionClass)
- [Time::Elapsed](https://metacpan.org/module/Time::Elapsed)

# Incompatibilities

The `Sysv` subclass will not work on `MSWin32` and `cygwin` platforms

# Bugs and Limitations

Testing of the `memcached` subclass is skipped on all platforms as it
requires `memcached` to be listening on the localhost's default
memcached port `localhost:11211`

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/module/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
