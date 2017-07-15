#!/bin/env perl

# Copyright (c) 2017 Todd Freed <todd.freed@gmail.com>
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

package profitability;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|profitability|;

sub profitability
{
  my ($miners, $rates) = @_;

  # calculate profit for benchmarked algos
  my @list;

  while(my($minername, $miner) = each %$miners)
  {
    while(my($algoname, $algo) = each %{$$miner{algos}})
    {
      my $rate = $$rates{$algoname};
      next unless $$rates{$algoname};

  #      my $variance = ($profit_cur / (($profit_cur + $profit_24h) / 2)) * 100;
  #      my $delta = $profit_24h - $profit_cur;
  #      $variance = ($delta / $profit_cur) * 100;
  #      $variance *= -1;

      push @list, {
          miner => $miner
        , algo => $algo
        , rate => $$rates{$algoname}
        , profit => $$algo{speed} * $$rates{$algoname}
  #        , profit_24h => $profit_24h
  #        , variance => $variance
      };
    }
  }

  @list
}

1
