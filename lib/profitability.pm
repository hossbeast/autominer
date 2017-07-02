#!/bin/env perl

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
