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

package perf;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|perf_readdir perf_startfile perf_readline perf_update perf_endfile|;

use Data::Dumper;
use File::Find;

use util;

sub normalize_hashrate
{
  my ($rate, $units) = @_;

  # no label, assume raw hashes
  $units = "" unless $units;

  if($units eq "p") {
    $rate *= 1000;
    $units = 't';
  }
  if($units eq "t") {
    $rate *= 1000;
    $units = 'g';
  }
  if($units eq "g") {
    $rate *= 1000;
    $units = 'm';
  }
  if($units eq "") {
    $rate /= 1000;
    $units = "k";
  }
  if($units eq "k") {
    $rate /= 1000;
    $units = 'm';
  }

  $rate;
}

sub perf_startfile
{
  my ($miner, $algo) = @_;

  $$algo{perf_time_base} = 0;
}

# reads the output from the perf pipe
sub perf_readline
{
  my ($miner, $algo, $line) = @_;

  # time-offset speed units
  if($line !~ /([0-9]+) ([0-9.]+) (k|m|g|t|p)? ?(h|s)\/s/i)
  {
#    print "malformed $$miner{name}/$$algo{name} perf record $line\n";
  }
  else
  {
    my $time = int($1);
    my $rate = normalize_hashrate($2, $3);

    while($$algo{perf_time_base} < $time)
    {
      unshift @{$$algo{perf}}, $rate;
      $$algo{perf_time_base}++;
    }
  }
}

sub perf_update
{
  my ($miner, $algo) = @_;

  my $speed = 0xFFFFFFFF;
  if(@{$$algo{perf}})
  {
    $speed = 0;
    my $x;
    for($x = 0; $x <= $#{$$algo{perf}} && $x < $::opts{samples}; $x++)
    {
      $speed += $$algo{perf}[$x];
    }

    $speed /= $x;
  }

  printf("%35s", sprintf("%s/%s", $$miner{name}, $$algo{name}));
  if($$algo{speed} == 0xffffffff) {
    printf("%14s", "(no data)");
  } else {
    printf("%14.8fMH/s", $$algo{speed});
  }
  printf(" => ");

  if($speed == 0xffffffff) {
    printf(" %14s", "(no data)");
  } else {
    printf(" %14.8fMH/s", $speed);
  }

  if($$algo{speed} != 0xffffffff && $speed != 0xffffffff)
  {
    my $delta = $speed - $$algo{speed};
    printf(" %%%6.2f", ($delta / $$algo{speed}) * 100);
  }
  print("\n");

  $$algo{speed} = $speed;
}

sub perf_endfile
{
  my ($miner, $algo, $dir, $num) = @_;

  # discard aged out perf records
  $#{$$algo{perf}} = $::opts{samples} if $#{$$algo{perf}} > $::opts{samples};

  # remove the file if it has now aged out
  $$algo{min_file} = $num unless defined $$algo{min_file};
  $$algo{max_file} = $num;

  if(($$algo{max_file} - $$algo{min_file}) >= $::opts{retention})
  {
    unlink sprintf("%s/%05u", $dir, $$algo{min_file});
    $$algo{min_file}++;
  }
}

#
# load all of the perf records for a miner/algo and cat them onto the perf pipe
#
sub perf_readdir
{
  my ($miner, $algo, $benchdir) = @_;

  my $dir = "$benchdir/$$miner{name}/$$algo{name}";

  my $wanted = sub {
    return if $_ eq "." or $_ eq "..";

    # reset the time base for interpreting a new file
    perf_startfile($miner, $algo);

    open(my $fh, "<$dir/$_") or die "open($dir/$_) : $!";

    # discard the header
    my $line = <$fh>; $line = <$fh>;
    while($line = <$fh>)
    {
      perf_readline($miner, $algo, $line);
    }
    close $fh;

    perf_endfile($miner, $algo, $dir, int($_));
  };
  my $preprocess = sub {
    sort { int($a) <=> int($b) } # increasing order
    grep { /^[0-9]+$/ } @_
  };

  if(-d $dir)
  {
    chdir($dir) or die "chdir($dir) : $!";
    finddepth({ wanted => $wanted, preprocess => $preprocess }, ".");
  }

  perf_update($miner, $algo);
}
