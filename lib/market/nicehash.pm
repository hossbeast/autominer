#!/bin/env perl

package nicehash;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|nicecurl niceport stats_global_current orders_summarize|;

use util;
use JSON::XS;
use Data::Dumper;

# nicehash region config
our %regions = (
    "eu" =>       { code => 0 }
  , "usa" =>      { code => 1 }
);

# nicehash regions by number
our %regions_by_number = (
    0 => "eu"
  , 1 => "usa"
);

our %algos = (
    "axiom" =>          { code => 13 , units => 'KH/s'  , port => 3346 }
  , "blake256r14" =>    { code => 17 , units => 'TH/s'  , port => 3350 }
  , "blake256r8" =>     { code => 16 , units => 'TH/s'  , port => 3349 }
  , "blake256r8vnl" =>  { code => 18 , units => 'TH/s'  , port => 3351 }
  , "blake2s" =>        { code => 28 , units => 'TH/s'  , port => 3361 }
  , "cryptonight" =>    { code => 22 , units => 'MH/s'  , port => 3355 }
  , "daggerhashimoto" =>{ code => 20 , units => 'GH/s'  , port => 3353 }
  , "decred" =>         { code => 21 , units => 'TH/s'  , port => 3354 }
  , "equihash" =>       { code => 24 , units => 'MSol/s', port => 3357 }
  , "hodl" =>           { code => 19 , units => 'KH/s'  , port => 3352 }
  , "keccak" =>         { code => 5  , units => 'GH/s'  , port => 3338 }
  , "lbry" =>           { code => 23 , units => 'TH/s'  , port => 3356 }
  , "lyra2re" =>        { code => 9  , units => 'GH/s'  , port => 3342 }
  , "lyra2rev2" =>      { code => 14 , units => 'GH/s'  , port => 3347 }
  , "neoscrypt" =>      { code => 8  , units => 'GH/s'  , port => 3341 }
  , "nist5" =>          { code => 7  , units => 'GH/s'  , port => 3340 }
  , "pascal" =>         { code => 25 , units => 'TH/s'  , port => 3358 }
  , "quark" =>          { code => 12 , units => 'GH/s'  , port => 3345 }
  , "qubit" =>          { code => 11 , units => 'GH/s'  , port => 3344 }
  , "sha256" =>         { code => 1  , units => 'PH/s'  , port => 3334 }
  , "sia" =>            { code => 27 , units => 'TH/s'  , port => 3360 }
  , "x11" =>            { code => 3  , units => 'GH/s'  , port => 3336 }
  , "x11gost" =>        { code => 26 , units => 'GH/s'  , port => 3359 }
  , "x13" =>            { code => 4  , units => 'GH/s'  , port => 3337 }
  , "x15" =>            { code => 6  , units => 'GH/s'  , port => 3339 }
  , "scrypt" =>         { code => 0  , units => 'GH/s'  , port => 3333 }
);

our %algos_by_number = (
    0 =>  "scrypt"
  , 1 =>  "sha256"
  , 2 =>  "scryptnf"
  , 3 =>  "x11"
  , 4 =>  "x13"
  , 5 =>  "keccak"
  , 6 =>  "x15"
  , 7 =>  "nist5"
  , 8 =>  "neoscrypt"
  , 9 =>  "lyra2re"
  , 10 => "whirlpoolx"
  , 11 => "qubit"
  , 12 => "quark"
  , 13 => "axiom"
  , 14 => "lyra2rev2"
  , 15 => "scryptjanenf16"
  , 16 => "blake256r8"
  , 17 => "blake256r14"
  , 18 => "blake256r8vnl"
  , 19 => "hodl"
  , 20 => "daggerhashimoto"
  , 21 => "decred"
  , 22 => "cryptonight"
  , 23 => "lbry"
  , 24 => "equihash"
  , 25 => "pascal"
  , 26 => "x11gost"
  , 27 => "sia"
  , 28 => "blake2s"
);

sub niceport
{
  my $algo = $_[0];

  $algos{$algo}{port}
}

sub nicecurl
{
  my $method = shift;
  my @params = @_;

  my $res = curl("https://api.nicehash.com/api", method => $method, @params);

  my $js;
  eval {
    $js = decode_json($res) or die $!;
  };
  if($@)
  {
    print STDERR "NICEHASH API QUERY FAILURE (use -v to see the error)\n";

    if($::verbose)
    {
      print STDERR (Dumper [ "nicehash response", $@, $res ]);
    }

    return undef;
  }

  $$js{result}
}

sub normalize_price
{
  my ($algo, $price) = @_;

  my $config = $algos{$algo};

  my $units = lc($$config{units});

  if($units eq 'ph/s')
  {
    $price /= 1000;
    $units = 'th/s';
  }
  if($units eq 'th/s')
  {
    $price /= 1000;
    $units = 'gh/s';
  }
  if($units eq 'gh/s')
  {
    $price /= 1000;
    $units = 'mh/s';
  }
  if($units eq 'kh/s')
  {
    $price *= 1000;
    $units = 'mh/s';
  }

  $price;
}

sub stats_global
{
  my ($api_method, $region) = @_;
  my %rates;

  my $js = nicecurl($api_method, location => $regions{$region}{code});
  return undef unless $js;

  for my $offer (@{$$js{stats}})
  {
    my $algonum = $$offer{algo};
    my $algoname = $algos_by_number{$algonum};

    $rates{$algoname} = normalize_price($algoname, $$offer{price});
  }

  \%rates;
}

sub stats_global_current
{
  stats_global('stats.global.current', 'usa')
}

# returns true if all algos were updated
sub orders_summarize
{
  my ($region, $stats) = @_;

  my $failures = 0;

  for my $algo (keys %algos)
  {
    my $js = nicecurl('orders.get', location => $regions{$region}{code}, algo => $algos{$algo}{code});
    if(!$js)
    {
      $failures++;
      next;
    }

    my $sum = 0;
    my $workers = 0;
    for my $order (@{$$js{orders}})
    {
      $sum += $$order{price} * $$order{workers};
      $workers += $$order{workers};
    }

    my $price = 0;
    $price = $sum / $workers if $workers;

    $$stats{$algo} = normalize_price($algo, $price);
  }

  !$failures
}

1
