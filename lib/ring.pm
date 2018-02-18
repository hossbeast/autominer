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

package ring;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|ring_init ring_add ring_sub|;

use util;
use xlinux;

sub ring_add
{
  my($a, $b, $ring) = @_;

  ($a + $b) % $ring
}

sub ring_sub
{
  my($a, $b, $ring) = @_;

  ($a - $b) % $ring
}

##
#
# PARAMETERS
#  dir       -
#  retention - samples to retain
#
sub ring_init
{
  my($dir, $retention) = @_;

  my $head = readlink("$dir/head");
  $head = int $head if $head;

  my $tail = readlink("$dir/tail");
  $tail = int $tail if $tail;

  # prune files outside the retention window
  if(defined $head and defined $tail)
  {
    while(ring_sub($head, $tail, 0xffff) > $retention)
    {
      uxunlink(sprintf("%s/%05u", $dir, $tail));
      $tail = ring_add($tail, 1, 0xffff);
    }

    symlinkf(sprintf("%05u", $tail), "$dir/tail");
  }

  $head, $tail;
}
