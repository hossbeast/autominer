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

package hashrate;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|normalize_profitability normalize_hashrate|;

# normalize units/s -> mh/s
#  was normalize_hashrate
sub normalize_hashrate
{
  my ($units, $price) = @_;

  $units = lc($units);
  substr($units, -2) = "" if substr($units, -2) eq "/s";
  substr($units, -3) = "h" if substr($units, -3) eq "sol";

  # downscale to mh
  if($units eq 'ph')
  {
    $price *= 1000;
    $units = 'th';
  }
  if($units eq 'th')
  {
    $price *= 1000;
    $units = 'gh';
  }
  if($units eq 'gh')
  {
    $price *= 1000;
    $units = 'mh';
  }

  # upscale to mh
  if($units eq 'h')
  {
    $price /= 1000;
    $units = 'kh';
  }
  if($units eq 'kh')
  {
    $price /= 1000;
    $units = 'mh';
  }

  $price;
}

# normalize btc/units/day -> btc/mh/day
#  was normalize_price
sub normalize_profitability
{
  my ($units, $price) = @_;

  $units = lc($units);
  substr($units, -2) = "" if substr($units, -2) eq "/s";
  substr($units, -3) = "h" if substr($units, -3) eq "sol";

  # downscale to mh
  if($units eq 'ph')
  {
    $price /= 1000;
    $units = 'th';
  }
  if($units eq 'th')
  {
    $price /= 1000;
    $units = 'gh';
  }
  if($units eq 'gh')
  {
    $price /= 1000;
    $units = 'mh';
  }

  # upscale to mh
  if($units eq 'h')
  {
    $price *= 1000;
    $units = 'kh';
  }
  if($units eq 'kh')
  {
    $price *= 1000;
    $units = 'mh';
  }

  $price;
}

1
