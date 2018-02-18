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

package asserts;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|is_mocked_call is_all_mocked_calls|;

use Test::More;
use test_util;

sub is_mocked_call
{
  my ($mock, $name, @args) = @_;

  $$mock{_is_mocked_call_pos} ||= 1;
  my $pos = $$mock{_is_mocked_call_pos}++;

  is($mock->call_pos($pos), $name, "mocked call sub name $name");
  my $x;
  for($x = 0; $x <= $#args; $x++)
  {
    is($mock->call_args_pos($pos, $x + 2), $args[$x], "mocked call $name() arg : $x $args[$x]");
  }

  is(mocked_args($mock, $pos) - 1, $x);
}

sub is_all_mocked_calls
{
  my ($mock) = @_;

  $$mock{_is_mocked_call_pos} ||= 1;
  my $pos = $$mock{_is_mocked_call_pos};

  my $calls_len = mocked_calls($mock);
  cmp_ok($calls_len, '==', $pos - 1, "is all mocked calls");
}

1
