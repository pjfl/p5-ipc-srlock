#!/usr/bin/perl

# @(#)$Id: 11lock.t 62 2008-04-11 01:20:52Z pjf $

use strict;
use warnings;
use File::Spec::Functions;
use FindBin  qw( $Bin );
use lib (catdir( $Bin, updir, q(lib) ));
use Test::More;

eval "use Test::Pod::Coverage 1.04";

plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;

all_pod_coverage_ok();
