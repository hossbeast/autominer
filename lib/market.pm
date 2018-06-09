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

package market;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|markets_load option_cmp|
);

use market::miningpoolhub;
use market::nicehash;

sub markets_load
{
  my %args = @_;

  my @markets;
  if($args{"nicehash-usa"})
  {
    push @markets, nicehash::new(region => 'usa', %args);
  }
  if($args{"nicehash-eu"})
  {
    push @markets, nicehash::new(region => 'eu', %args);
  }
  if($args{"nicehash-hk"})
  {
    push @markets, nicehash::new(region => 'hk', %args);
  }
  if($args{"nicehash-jp"})
  {
    push @markets, nicehash::new(region => 'jp', %args);
  }
  if($args{miningpoolhub})
  {
    push @markets, miningpoolhub::new(%args);
  }
  @markets;
}

1
