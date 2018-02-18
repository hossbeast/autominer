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

use Carp;
$SIG{__WARN__} = sub { die @_ };
$SIG{__DIE__} = \&confess;

use Test::More;
use Test::MockObject::Extends;

use lib "lib";
use algo;

use lib "test/lib";
use asserts;
use test_util;

my $name = '(name)';
my $miner = { name => '(miner-name)' };
sub mocked_algo()
{
  my $algo = bless { }, 'algo';
  $algo;
}

sub test_sample_two
{
  my $algo = algo::new($name, $miner, "algo-trailing-window-seconds" => 42);

  $algo->sample(1, 2);  # duration, hashrate
  $algo->sample(3, 4);

  # (2+4+4+4)/4 = 3.5
  is($$algo{hashrate}, 3.5);
}

test_sample_two();
done_testing()
