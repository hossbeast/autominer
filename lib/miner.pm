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

package miner;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|miners_load miner_env_setup|;

use Data::Dumper;
use JSON::XS;

use algo;
use child_commands;
use ring;
use util;

#
# normalize algorithm names to what nicehash accepts
#
sub _normalize_algorithm
{
  my $name = $_[0];

  my %map = (
      "lyra2" => "lyra2re"
    , "lyra2v2" => "lyra2rev2"
  );

  return $map{$name} if $map{$name};
  return $name;
}

sub enumerate_supported_algos
{
  my ($miner, %args) = @_;

  miner_env_setup($$miner{name});

  my @cmd = ($$miner{path}, "algos");
  my ($status, $output) = run(@cmd);

  die "@cmd failed : re-run with -v" if $status != 0;

  my @algos;
  for my $line (split(/\n/, $output))
  {
    if($line =~ /^[a-z0-9-_]+$/i)
    {
      my $algo_name = _normalize_algorithm($&);

      # default to max speed to cause autominer to select algorithms for which there is no benchmark data
      push @algos, algo::new($algo_name, $miner, %args);
    }
  }

  @algos
}

sub new
{
  my ($name, $path) = @_;

  bless {
      name => $name
    , path => $path
  }
}

sub miners_load
{
  my ($miners_dir, $history_dir, %args) = @_;

  my @miners;

  chdir($miners_dir) or die "chdir($miners_dir) : $!";
  opendir(my $dh, ".") or die $!;
  while(readdir $dh)
  {
    next unless /^autominer-([a-z0-9-_]+)$/;

    my $path = "$miners_dir/$_";
    my $name = $1;

    my @cmd = ($path, "configured");
    miner_env_setup($_);
    my ($status, $output) = filter(\@cmd);

    die "@cmd failed : re-run with -v" if $status != 0;

    if($output ne "yes")
    {
      print("IGNORING $name - miner not configured\n");
      next;
    }

    my $miner = {
        name => $name
      , path => $path
      , algos => {}
    };

    # get list of algos supported by the miner
    my @algos = enumerate_supported_algos($miner, %args);
    for my $algo (@algos)
    {
      $$miner{algos}{$$algo{name}} = $algo;

      # initialize the algo stats from its history
      my $dir = "$history_dir/algo/$$algo{name}/miner/$$miner{name}/$args{profile}";
      my $stream = stream::new($dir);
      next unless defined $$stream{head};

      my $x = $$stream{head};
      while(1)
      {
        my $text = $stream->read($x);
        if($text)
        {
          my $record = decode_json($text);

          # read until the window is full
          last if $algo->sample($$record{duration}, $$record{hashrate});
        }

        last if defined $$stream{tail} and $x == $$stream{tail};
        $x = ring_sub($x, 1, 0xffff);
      }

      $algo->report() if $args{"show-hashrate"};
    }

    push @miners, $miner;
  }
  closedir $dh;

  return @miners;
}

sub miner_env_setup
{
  my ($miner_name, $option) = @_;

  my %params;
  $params{AUTOMINER_MINER} = $miner_name;
  $params{AUTOMINER_CCMINER_PATH} = $::opts{"ccminer-path"};
  $params{AUTOMINER_CCMINER_CRYPTONIGHT_PATH} = $::opts{"ccminer-cryptonight-path"};
  $params{AUTOMINER_ETHMINER_PATH} = $::opts{"ethminer-path"};
  $params{AUTOMINER_NHEQMINER_CUDA_PATH} = $::opts{"nheqminer-cuda-path"};
  $params{AUTOMINER_SGMINER_PATH} = $::opts{"sgminer-path"};
  $params{AUTOMINER_EQM_PATH} = $::opts{"eqm-path"};
  $params{AUTOMINER_NH_ADDRESS} = $::opts{"nh-address"} if $::opts{"nh-address"};
  $params{AUTOMINER_MPH_USERNAME} = $::opts{"mph-username"} if $::opts{"mph-username"};
  $params{AUTOMINER_WORKER} = $::opts{worker} if $::opts{worker};
  $params{AUTOMINER_CARDS_SPACES} = $::opts{"space-cards"};
  $params{AUTOMINER_CARDS_COMMAS} = $::opts{"comma-cards"};
  $params{AUTOMINER_PROFILE} = $::opts{profile};
  $params{AUTOMINER_VERBOSE} = $::opts{verbose};

  if($option)
  {
    $params{AUTOMINER_MARKET} = $$option{market}{name};

    my %market_params = $$option{market}->miner_env_params($option);
    @params{keys %market_params} = values %market_params;
  }

  @ENV{keys %params} = values %params;
}
