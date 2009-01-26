#!/usr/bin/perl

# @(#)$Id: 11lock.t 62 2008-04-11 01:20:52Z pjf $

use strict;
use warnings;
use Test::More;

eval "use Test::Pod 1.14";

plan skip_all => 'Test::Pod 1.14 required' if $@;

all_pod_files_ok();
