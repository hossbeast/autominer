#!/usr/bin/env perl

# Copyright (c) 2017-2018 Todd Freed <todd.freed@gmail.com>
#
# This file is part of autominer.
#
# autominer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# autominer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License

use strict;
use warnings;

use Carp;
$SIG{__WARN__} = sub { die @_ };
$SIG{__DIE__} = \&confess;

use Test::More;
use Test::MockObject::Extends;

use Data::Dumper;

use lib "lib";
use perf;

use lib "test/lib";
use asserts;
use test_util;

# infer records based on the time base
sub test_few
{
  my $time_base = 0;
  my @records = perf_readline(\$time_base, "2 842.37 MH/s");

  is($#records + 1, 2);
  is($records[0], 842.37);
  is($records[1], 842.37);
}

# normalize to MH
sub test_downscale
{
  my $time_base = 0;
  my @records = perf_readline(\$time_base, "1 842.37 GH/s");

  is($#records + 1, 1);
  is($records[0], 842370);
}

# normalize to MH
sub test_upscale
{
  my $time_base = 0;
  my @records = perf_readline(\$time_base, "1 42000000 H/s");

  is($#records + 1, 1);
  is($records[0], 42);
}

# normalize sols to hashes
sub test_sols
{
  my $time_base = 0;
  my @records = perf_readline(\$time_base, "1 42 MSol/s");

  is($#records + 1, 1);
  is($records[0], 42);
}

test_few();
test_downscale();
test_upscale();
test_sols();
done_testing();
