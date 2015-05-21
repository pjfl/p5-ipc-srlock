<div>
    <a href="https://travis-ci.org/pjfl/p5-ipc-srlock"><img src="https://travis-ci.org/pjfl/p5-ipc-srlock.svg?branch=master" alt="Travis CI Badge"></a>
    <a href="http://badge.fury.io/pl/IPC-SRLock"><img src="https://badge.fury.io/pl/IPC-SRLock.svg" alt="CPAN Badge"></a>
    <a href="http://cpants.cpanauthors.org/dist/IPC-SRLock"><img src="http://cpants.cpanauthors.org/dist/IPC-SRLock.png" alt="Kwalitee Badge"></a>
</div>

# Name

IPC::SRLock - Set / reset locking semantics to single thread processes

# Version

This documents version v0.25.$Rev: 3 $ of [IPC::SRLock](https://metacpan.org/pod/IPC::SRLock)

# Synopsis

    use IPC::SRLock;

    my $config   = { tempdir => 'path_to_tmp_directory', type => 'fcntl' };

    my $lock_obj = IPC::SRLock->new( $config );

    $lock_obj->set( k => 'some_resource_identfier' );

    # This critical region of code is guaranteed to be single threaded

    $lock_obj->reset( k => 'some_resource_identfier' );

# Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

Implements a factory pattern, three implementations are provided. The
LCD option [IPC::SRLock::Fcntl](https://metacpan.org/pod/IPC::SRLock::Fcntl) which works on non Unixen,
[IPC::SRLock::Sysv](https://metacpan.org/pod/IPC::SRLock::Sysv) which uses System V IPC, and
[IPC::SRLock::Memcached](https://metacpan.org/pod/IPC::SRLock::Memcached) which uses `libmemcache` to implement a
distributed lock manager

# Configuration and Environment

Defines the following attributes;

- `type`

    Determines which factory subclass is loaded. Defaults to `fcntl`, can
    be; `fcntl`, `memcached`, or `sysv`

# Subroutines/Methods

## BUILDARGS

Extracts the `type` attribute from those passed to the factory subclass

## BUILD

Called after an instance is created this subroutine triggers the lazy
evaluation of the concrete subclass

## get\_table

    my $data = $lock_obj->get_table;

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
[HTML::FormWidgets](https://metacpan.org/pod/HTML::FormWidgets)

## list

    my $array_ref = $lock_obj->list;

Returns an array of hash refs that represent the current lock table

## reset

    $lock_obj->reset( k => 'some_resource_key' );

Resets the lock referenced by the `k` attribute.

## set

    $lock_obj->set( k => 'some_resource_key' );

Sets the specified lock. Attributes are:

- `k`

    Unique key to identify the lock. Mandatory no default

- `p`

    Explicitly set the process id associated with the lock. Defaults to
    the current process id

- `t`

    Set the time to live for this lock. Defaults to five minutes. Setting
    it to zero makes the lock last indefinitely

# Diagnostics

Setting `debug` to true will cause the `set` methods to log
the lock record at the debug level

# Dependencies

- [File::DataClass](https://metacpan.org/pod/File::DataClass)
- [Moo](https://metacpan.org/pod/Moo)
- [Type::Tiny](https://metacpan.org/pod/Type::Tiny)

# Incompatibilities

The `sysv` subclass type will not work on `MSWin32` and `cygwin` platforms

# Bugs and Limitations

Testing of the `memcached` subclass type is skipped on all platforms as it
requires `memcached` to be listening on the localhost's default
memcached port `localhost:11211`

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
