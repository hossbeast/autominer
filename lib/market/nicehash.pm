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

package nicehash;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|orders_summarize|;

use JSON::XS;
use Data::Dumper;

use child_commands;
use hashrate;
use option;
use util;

# nicehash region config
our %regions = (
    "eu" =>       { code => 0 }
  , "usa" =>      { code => 1 }
);

our %regions_by_market = (
    "nicehash-eu"   => "eu"
  , "nicehash-usa"  => "usa"
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
  , "keccak" =>         { code => 5  , units => 'TH/s'  , port => 3338 }
  , "lbry" =>           { code => 23 , units => 'TH/s'  , port => 3356 }
# , "lyra2re" =>        { code => 9  , units => 'GH/s'  , port => 3342 } out of order
  , "lyra2rev2" =>      { code => 14 , units => 'TH/s'  , port => 3347 }
  , "neoscrypt" =>      { code => 8  , units => 'GH/s'  , port => 3341 }
  , "nist5" =>          { code => 7  , units => 'GH/s'  , port => 3340 }
  , "pascal" =>         { code => 25 , units => 'TH/s'  , port => 3358 }
  , "quark" =>          { code => 12 , units => 'TH/s'  , port => 3345 }
  , "qubit" =>          { code => 11 , units => 'TH/s'  , port => 3344 }
  , "sha256" =>         { code => 1  , units => 'PH/s'  , port => 3334 }
  , "sia" =>            { code => 27 , units => 'TH/s'  , port => 3360 }
  , "x11" =>            { code => 3  , units => 'TH/s'  , port => 3336 }
  , "x11gost" =>        { code => 26 , units => 'GH/s'  , port => 3359 }
  , "x13" =>            { code => 4  , units => 'GH/s'  , port => 3337 }
  , "x15" =>            { code => 6  , units => 'GH/s'  , port => 3339 }
  , "scrypt" =>         { code => 0  , units => 'TH/s'  , port => 3333 }
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

sub normalize_algo_price
{
  my ($algo, $price) = @_;

  my $config = $algos{$algo};
  my $units = lc($$config{units});

  normalize_profitability($units, $price)
}

# returns true if all algos were updated
sub orders_summarize
{
  my ($region, $rates, $opportunities) = @_;

  my $failures = 0;

  for my $algo (keys %algos)
  {
    my $rest = rest_prep(
        "https://api.nicehash.com/api"
      , method => 'orders.get'
      , location => $regions{$region}{code}
      , algo => $algos{$algo}{code}
    );
    my $js;
    while(not defined $js and $$rest{sleep} < 60)
    {
      my $response = rest_get($rest);
      (undef, $js) = try { $$response{result} } if $response;
    }

    my @orders = sort { $$a{price} <=> $$a{price} } @{$$js{orders}};

    my $total_accepted_speed = 0;
    for my $order (@orders)
    {
      $total_accepted_speed += $$order{accepted_speed};
    }

    # opportunity in switching
    my $opportunity_price = 0;
    my $opportunity_speed = 0;
    for my $order (@orders)
    {
      my $remaining_speed = ($total_accepted_speed * .1) - $opportunity_speed;
      my $available_speed;
      if($$order{limit_speed} == 0)
      {
        $available_speed = $remaining_speed;
      }
      else
      {
        $available_speed = $$order{limit_speed} - $$order{accepted_speed};
        $available_speed = $remaining_speed if $available_speed > $remaining_speed;
      }

      $available_speed = 0 if $available_speed < 0;
      $opportunity_speed += $available_speed;
      $opportunity_price += $$order{price} * $available_speed;

      last if $opportunity_speed >= ($total_accepted_speed * .1);
    }

    my $price = 0;
    if($total_accepted_speed && ($opportunity_speed >= ($total_accepted_speed * .1)))
    {
      $price = $opportunity_price / $opportunity_speed;
    }
    $price = normalize_algo_price($algo, $price);

    my $size_pct = 0;
    $size_pct = $opportunity_speed / $total_accepted_speed if $total_accepted_speed;
    $size_pct *= 100;

    $$opportunities{$algo}{total} = $total_accepted_speed;
    $$opportunities{$algo}{size} = $opportunity_speed;
    $$opportunities{$algo}{size_pct} = $size_pct * 100;
    $$opportunities{$algo}{price} = $price;

    # average price paid per hashrate
    my $sum = 0;
    for my $order (@orders)
    {
      $sum += $$order{price} * $$order{accepted_speed};
    }

    $price = 0;
    $price = $sum / $total_accepted_speed if $total_accepted_speed;
    $$rates{$algo} = normalize_algo_price($algo, $price);
  }

  !$failures
}

sub new
{
  my (%opts) = @_;

  my $self = bless {
      name => "nicehash-$opts{region}"
    , region => $opts{region}
  };

  my @keys = qw|nh-switching-period nh-price-method nh-trailing-sma-window nh-address cache-dir|;
  @{$self}{@keys} = @opts{@keys};
  $self
}

sub switching_period
{
  my ($self) = @_;

  $$self{"nh-switching-period"} || 0
}

sub assemble_mining_options
{
  my ($self, $miners) = @_;

  my @options;
  for my $miner (@$miners)
  {
    while(my($algoname, $algo) = each %{$$miner{algos}})
    {
      next unless $algos{$algoname};

      push @options, option::new(
          miner => $miner
        , algo => $algo
        , pool => $algo
        , market => $self
      )
    }
  }

  return @options;
}

sub evaluate_option
{
  my ($self, $option) = @_;

  # extra data to persist
  for my $period (qw|s30 m1 m5 m10 h1 h3|)
  {
    $$option{"price_trailing_sma_$period"} = $self->_price_trailing_sma($option, $period);
  }

  $$option{price_opportunity} = $self->_price_opportunity($option);

  my $price = $$option{price_opportunity};
  if($$self{"nh-price-method"} eq "trailing-sma")
  {
    $price = $$option{"price_trailing_sma_" . $$self{"nh-trailing-sma-window"}};
  }

  $$option{predicted_profit_noboost} = $price * $$option{algo}{hashrate};
  $$option{predicted_profit} = $$option{predicted_profit_noboost} * $$option{boost}{modifier};
}

sub show_prediction
{
  my ($self, $option) = @_;

  printf("%s/%s/%s/%s\n"
    , $$option{market}{name}
    , $$option{pool}{name}
    , $$option{miner}{name}
    , $$option{algo}{name}
  );

  my $price;
  if($$self{"nh-price-method"} eq "trailing-sma")
  {
    $price = $$option{"price_trailing_sma_" . $$self{"nh-trailing-sma-window"}};
    printf("   %20s %14.8f BTC/MH/day\n"
      , "trailing-" . $$self{"nh-trailing-sma-window"} . " price"
      , $price
    );
  }
  else
  {
    $price = $$option{price_opportunity};
    printf("   %20s %14.8f BTC/MH/day\n"
      , "opportunity price"
      , $price
    );
  }

  printf(" * %20s %14.8f MH/s (average observed over %s)\n"
    , "algo hashrate"
    , $$option{algo}{hashrate}
    , durationstring($$option{algo}{hashrate_duration})
  );
  printf(" = %20s %14.8f\n", "", $$option{predicted_profit_noboost});

  printf(" * %20s %14.8f\n"
    , "boost"
    , $$option{boost}{modifier}
  );
  printf(" = %20s %14.8f BTC/day\n", "predicted profit", $$option{predicted_profit});
}

sub load_rates
{
  my ($self) = @_;

  for my $period (qw|s30 m1 m5 m10 h1 h3|)
  {
    my $path = sprintf("%s/%s/rates/%s", $$self{"cache-dir"}, $$self{name}, $period);
    open(my $fh, "<$path") or die "open($path) : $!";
    my $text = do { local $/ = undef ; <$fh> };
    close $fh;
    $$self{rates}{$period} = decode_json($text);
  }

  my $path = sprintf("%s/%s/opportunities/present", $$self{"cache-dir"}, $$self{name});
  open(my $fh, "<$path") or die "open($path) : $!";
  my $text = do { local $/ = undef ; <$fh> };
  close $fh;
  $$self{opportunities} = decode_json($text);
}

sub option_start
{
}

# check back after 6 minutes
sub get_mining_interval
{
  60 * 6
}

#
# this nicehash api doesnt report accurate accepted rate until the miner has
# been submitting shares over a period of 5 minutes
#
# in addition the data for the current algorithm seems to reflect only the
# previous 5 minutes, regardless of the from parameter
#
# it should be called every 5 minutes
#
sub get_mining_results
{
  my ($self, $option) = @_;

  my $rest = rest_prep(
      "https://api.nicehash.com/api"
    , method => 'stats.provider.ex'
    , addr => $$self{"nh-address"}
    , from => (time() - (60 * 5))
  );
  my $data;
  while(not defined $data && $$rest{sleep} < 60)
  {
    my $response = rest_get($rest);
    (undef, $data) = try { $$response{result}{current} } if $response;
  }

  my $results = { actual_price => 0, accepted_speed => 0 };
  if($data)
  {
    my $x;
    for($x = 0; $x <= $#$data; $x++)
    {
      my $result = $$data[$x];
      if($$result{algo} == $algos{$$option{algo}{name}}{code})
      {
        my $price = normalize_profitability($$result{suffix}, $$result{profitability});
        my $accepted;
        $accepted = $$result{data}[0]{"a"} if $#{$$result{data}} >= 0;
        $accepted = normalize_hashrate($$result{suffix}, $accepted) if $accepted;
        $accepted ||= 0;

        $$results{actual_price} = $price;
        $$results{accepted_speed} = $accepted;
        last;
      }
    }

    if($x > $#$data)
    {
      print STDERR ("no results from nicehash for $$option{algo}{name}\n");
    }
  }
  else
  {
    print STDERR ("unable to get results from nicehash\n");
  }

  return $results;
}

sub accumulate_mining_results
{
  my ($self, $results, $interval_results) = @_;

  push @{$$results{records}}, $interval_results;

  $$results{actual_price} = average(map { $$_{actual_price} } @{$$results{records}});
  $$results{accepted_speed} = average(map { $$_{accepted_speed} } @{$$results{records}});
  $$results{profit} = $$results{actual_price} * $$results{accepted_speed};
}

sub _price_trailing_sma
{
  my ($self, $option, $period) = @_;

  $$self{rates}{$period}{$$option{algo}{name}}
}

sub _price_opportunity
{
  my ($self, $option) = @_;

  my (undef, $price) = try { $$self{opportunities}{$$option{algo}{name}}{price} };
  $price || 0
}

sub miner_env_params
{
  my ($self, $option) = @_;

  my $algo_name = $$option{algo}{name};
  my $port = $algos{$$option{algo}{name}}{port};
  my $region = $$self{region};

  my %params;
  $params{AUTOMINER_ALGO} = $algo_name;
  $params{AUTOMINER_PORT} = $port;
  $params{AUTOMINER_NICEHASH_REGION} = $region;
  $params{AUTOMINER_URL_AUTHORITY} = "$algo_name.$region.nicehash.com:$port";
  $params{AUTOMINER_USERNAME} = $::opts{"nh-address"};
  $params{AUTOMINER_USERNAME} .= "." . $::opts{worker} if $::opts{worker};
  %params;
}

# additional data to store with the option record
sub option_record_params
{
  my ($self, $option) = @_;

  my %params;
  for my $period (qw|s30 m1 m5 m10 h1 h3|)
  {
    $params{"price_trailing_sma_$period"} = $$option{"price_trailing_sma_$period"};
  }

  $params{price_opportunity} = $$option{price_opportunity};
  $params{actual_price}      = $$option{actual_price};
  $params{accepted_speed}    = $$option{accepted_speed};
  %params
}

1
