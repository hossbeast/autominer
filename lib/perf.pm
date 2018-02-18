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

package perf;

use strict;
use warnings;

use Data::Dumper;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|perf_readline|
);

use hashrate;

# reads the output from the perf pipe
sub perf_readline
{
  my ($time_base_ref, $line) = @_;

  my $re = qr/
       ([0-9]+)        # 1 time-offset
    \s+([0-9.]+)       # 2 speed
    \s+(k|m|g|t|p)?    # 3 units
    \s*(?:h|s|sol)\/s
  /xi;

  my @records;
  if($line !~ $re)
  {
    print "malformed perf line '$line'\n" # if $::verbose;
  }
  else
  {
    my $time = int($1);
    my $rate = normalize_hashrate(($3 || '') . 'h', $2);

    # one record per second
    while($$time_base_ref < $time)
    {
      unshift @records, $rate;
      $$time_base_ref++;
    }
  }

  @records
}
