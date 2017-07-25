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

package miner;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|enumerate_miners enumerate_algos miner_env_setup|;

use Data::Dumper;

use util;
use market::nicehash;

#
# normalize algorithm names to what nicehash accepts
#
sub normalize_algorithm
{
  my $name = $_[0];

  my %map = (
      "lyra2" => "lyra2re"
    , "lyra2v2" => "lyra2rev2"
  );

  return $map{$name} if $map{$name};
  return $name;
}

sub enumerate_miners
{
  my $miners_dir = shift;

  my %miners;

  chdir($miners_dir) or die "chdir($miners_dir) : $!";
  opendir(my $dh, ".") or die $!;
  while(readdir $dh)
  {
    next unless /^autominer-([a-z0-9-_]+)$/;

    my $path = "$miners_dir/$_";
    my $name = $1;

    my @cmd = ($path, "configured");
    miner_env_setup(miner => $_);
    my $output = filter(\@cmd);

    if($output eq "yes")
    {
      $miners{$1}{path} = $path;
      $miners{$1}{name} = $name;
    }
    else
    {
      print("not configured autominer-$name\n");
    }
  }
  closedir $dh;

  return %miners;
}

sub enumerate_algos
{
  my $miner = shift;

  miner_env_setup(miner => $$miner{name});

  my $output = run($$miner{path}, "algos");

  for my $line (split(/\n/, $output))
  {
    if($line =~ /^[a-z0-9-_]+$/i)
    {
      my $algo = normalize_algorithm($&);

      # default to max speed to cause autominer to select algorithms for which there is no benchmark data
      $$miner{algos}{$algo} = { name => $algo, perf => [ ], speed => 0xffffffff };
    }
  }
}

sub miner_env_setup
{
  my %params = @_;

  $ENV{AUTOMINER_MINER} = $params{miner};

  if($params{algo})
  {
    $ENV{AUTOMINER_ALGO} = $params{algo};
    $ENV{AUTOMINER_PORT} = nicehash::niceport($params{algo});
  }

  $ENV{AUTOMINER_PAYOUT_ADDRESS} = $::opts{payout_address};
  $ENV{AUTOMINER_USERNAME} = $::opts{payout_address};
  $ENV{AUTOMINER_WORKER} = $::opts{worker};
  $ENV{AUTOMINER_USERNAME} .= "." . $::opts{worker} if $::opts{worker};
  $ENV{AUTOMINER_CARDS_SPACES} = $::opts{"space-cards"};
  $ENV{AUTOMINER_CARDS_COMMAS} = $::opts{"comma-cards"};
  $ENV{AUTOMINER_PROFILE} = $::opts{profile};

  if($params{market})
  {
    $ENV{AUTOMINER_MARKET} = "nicehash";
    $ENV{AUTOMINER_NICEHASH_REGION} = "usa" if $params{market} eq "nicehash-usa";
    $ENV{AUTOMINER_NICEHASH_REGION} = "eu" if $params{market} eq "nicehash-eu";
  }

  $ENV{AUTOMINER_CCMINER_PATH} = $::opts{ccminer_path};
  $ENV{AUTOMINER_CCMINER_CRYPTONIGHT_PATH} = $::opts{"ccminer_cryptonight_path"};
  $ENV{AUTOMINER_ETHMINER_PATH} = $::opts{ethminer_path};
  $ENV{AUTOMINER_NHEQMINER_CUDA_PATH} = $::opts{nheqminer_cuda_path};
  $ENV{AUTOMINER_SGMINER_PATH} = $::opts{sgminer_path};

  my @env;
  while(my($k, $v) = each %ENV)
  {
    push @env, "$k=$v" if substr($k, 0, 9) eq "AUTOMINER";
  }
  @env = sort @env;
# print Dumper \@env;
}
