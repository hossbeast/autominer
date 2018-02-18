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

package algo;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|algo_init|;

use logger;
use util;

sub algo_init
{
  my ($self, $name, $miner, %opts) = @_;

  $$self{name} = $name;
  $$self{miner} = $miner;
  $$self{"algo-trailing-window-seconds"} = $opts{"algo-trailing-window-seconds"};
  $$self{"hashrate"} = 0;
  $$self{"hashrate_duration"} = 0;
  $$self{"samples"} = [];
  $self
}

sub new
{
  my $algo = bless { };
  algo_init($algo, @_);
}

sub report
{
  my ($self) = @_;

  logf("hashrate for %-20s %-20s %14.8f MH/s over %s"
    , $$self{miner}{name}
    , $$self{name}
    , $$self{hashrate}
    , durationstring($$self{hashrate_duration})
  );
}

#
# parameters
#  duration - length of the period in seconds
#  hashrate - observed hashrate over the period
#
sub sample
{
  my ($self, $duration, $hashrate) = @_;

  # prepend the new sample
  unshift @{$$self{samples}}, {
      duration => $duration
    , hashrate => $hashrate
  };

  my $total_duration = 0;

  # age out old samples
  my $x;
  for($x = 0; $x <= $#{$$self{samples}}; $x++)
  {
    $total_duration += $$self{samples}[$x]{duration};
    if($total_duration > $$self{"algo-trailing-window-seconds"})
    {
      $#{$$self{samples}} = $x;
      last;
    }
  }

  my $sum = 0;
  $$self{hashrate_duration} = 0;
  for my $sample (@{$$self{samples}})
  {
    $sum += $$sample{hashrate} * $$sample{duration};
    $$self{hashrate_duration} += $$sample{duration};
  }

  $$self{hashrate} = 0;
  $$self{hashrate} = $sum / $$self{hashrate_duration} if $$self{hashrate_duration};

  # whether the trailing window is full
  $x == $#{$$self{samples}}
}

1
