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

package test_util;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|mocked_calls mocked_args print_mocked_calls|;

use Test::MockObject;

# returns the number of mocked calls recorded
sub mocked_calls
{
  my ($mock) = @_;

  $#{Test::MockObject::_calls($mock)} + 1
}

# returns the number of arguments to the mocked call, including $self
sub mocked_args
{
  my ($mock, $pos) = @_;

  my $call = Test::MockObject::_calls($mock)->[$pos - 1];

  $#{$$call[1]} + 1
}

sub print_mocked_calls
{
  my ($mock) = @_;

  for(my $x = 1; $x <= mocked_calls($mock); $x++)
  {
    print("$x ", $mock->call_pos($x) || '', "\n");
    for my $y (1 .. mocked_args($mock, $x))
    {
      print(" $y ", $mock->call_args_pos($x, $y) || '', "\n");
    }
  }
}

1
