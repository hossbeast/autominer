#!/bin/env perl

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

  my @cmd = (
      $$miner{path}
    , "algos"
  );

  $ENV{autominer_path} = $$miner{path};

  my $output = run(@cmd);

  for my $line (split(/\n/, $output))
  {
    if($line =~ /^[a-z0-9-_]+$/i)
    {
      my $algo = normalize_algorithm($&);

      $$miner{algos}{$algo} = { name => $algo, perf => [ ], speed => 0xffffffff };
    }
  }
}

sub miner_env_setup
{
  my ($miner, $algo) = @_;

  $ENV{AUTOMINER_MINER} = $$miner{name};
  $ENV{AUTOMINER_ALGO} = $$algo{name};
  $ENV{AUTOMINER_PORT} = nicehash::niceport($$algo{name});
  $ENV{AUTOMINER_MARKET} = "nicehash";
  $ENV{AUTOMINER_USERNAME} = $::opts{username};
  $ENV{AUTOMINER_CARDS_SPACES} = $::opts{"space-cards"};
  $ENV{AUTOMINER_CARDS_COMMAS} = $::opts{"comma-cards"};
}
