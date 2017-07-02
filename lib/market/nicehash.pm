#!/bin/env perl

package nicehash;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|nicecurl stats_global_current stats_global_24h niceport|;

use util;
use JSON::XS;
use Data::Dumper;

my $algomap = {
	  "axiom" =>          { units => 'KH/s'  , port => 3346 }
	, "blake256r14" =>    { units => 'TH/s'  , port => 3350 }
	, "blake256r8" =>     { units => 'TH/s'  , port => 3349 }
	, "blake256r8vnl" =>  { units => 'TH/s'  , port => 3351 }
	, "blake2s" =>        { units => 'TH/s'  , port => 3361 }
	, "cryptonight" =>    { units => 'MH/s'  , port => 3355 }
	, "daggerhashimoto" =>{ units => 'GH/s'  , port => 3353 }
	, "decred" =>         { units => 'TH/s'  , port => 3354 }
	, "equihash" =>       { units => 'MSol/s', port => 3357 }
	, "hodl" =>           { units => 'KH/s'  , port => 3352 }
	, "keccak" =>         { units => 'GH/s'  , port => 3338 }
	, "lbry" =>           { units => 'TH/s'  , port => 3356 }
	, "lyra2re" =>        { units => 'GH/s'  , port => 3342 }
	, "lyra2rev2" =>      { units => 'GH/s'  , port => 3347 }
	, "neoscrypt" =>      { units => 'GH/s'  , port => 3341 }
	, "nist5" =>          { units => 'GH/s'  , port => 3340 }
	, "pascal" =>         { units => 'TH/s'  , port => 3358 }
	, "quark" =>          { units => 'GH/s'  , port => 3345 }
	, "qubit" =>          { units => 'GH/s'  , port => 3344 }
	, "sha256" =>         { units => 'PH/s'  , port => 3334 }
	, "sia" =>            { units => 'TH/s'  , port => 3360 }
	, "x11" =>            { units => 'GH/s'  , port => 3336 }
	, "x11gost" =>        { units => 'GH/s'  , port => 3359 }
	, "x13" =>            { units => 'GH/s'  , port => 3337 }
	, "x15" =>            { units => 'GH/s'  , port => 3339 }
  , "scrypt" =>         { units => 'GH/s'  , port => 3333 }
};

my %algonames = (
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

  $$algomap{$algo}{port}
}

sub nicecurl
{
  my $res = curl "https://api.nicehash.com/api?method=$_[0]";

  my $js;
  eval {
    $js = decode_json($res) or die $!;
  };
  if($@)
  {
    print Dumper [ "nicehash failed", $@, $res ];
    return undef;
  }

  $$js{result}
}

sub stats_global
{
  my $api_method = $_[0];
  my %rates;

  my $js = nicecurl $api_method;
  if(!$js)
  {
    print "NICEHASH API IS DOWN\n";
    return undef;
  }

  for my $offer (@{$$js{stats}})
  {
    my $algonum = $$offer{algo};
    my $algoname = $algonames{$algonum};
    my $config = $$algomap{$algoname};

    next unless $config;

    my $price = $$offer{price};
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

    $rates{$algoname} = $price;
  }

  \%rates;
}

sub stats_global_24h
{
  stats_global 'stats.global.24h'
}

sub stats_global_current
{
  stats_global 'stats.global.current'
}

1
