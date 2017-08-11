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

package miningpoolhub;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw||;

use Data::Dumper;
use JSON::XS;

use child_commands;
use option;
use perf;
use util;
use logger;

# miningpoolhub pools configuration
our %pools = (
    'adzcoin'          => { coin => 'ADZ'  , port => 20529, algo => 'x11'            , domain => 'adzcoin'                 }
  , 'bitcoin-gold'     => { coin => 'BTG'  , port => 20595, algo => 'equihash'       , domain => 'us-east.equihash-hub'    }
  , 'dash'             => { coin => 'DASH' , port => 20465, algo => 'x11'            , domain => 'hub'                     }
  , 'digibyte-groestl' => { coin => 'DGB'  , port => 20499, algo => 'myriad-groestl' , domain => 'hub'                     }
  , 'electroneum'      => { coin => 'ETN'  , port => 20596, algo => 'cryptonight'    , domain => 'us-east.cryptonight-hub' }
  , 'ethereum'         => { coin => 'ETH'  , port => 20535, algo => 'ethash'         , domain => 'us-east.ethash-hub'      }
  , 'ethereum-classic' => { coin => 'ETC'  , port => 20555, algo => 'ethash'         , domain => 'us-east.ethash-hub'      }
  , 'expanse'          => { coin => 'EXP'  , port => 20565, algo => 'ethash'         , domain => 'us-east.ethash-hub'      }
  , 'feathercoin'      => { coin => 'FTC'  , port => 20510, algo => 'neoscrypt'      , domain => 'hub'                     }
  , 'geocoin'          => { coin => 'GEO'  , port => 20524, algo => 'qubit'          , domain => 'hub'                     }
  , 'globalboosty'     => { coin => 'BSTY' , port => 20543, algo => 'yescrypt'       , domain => 'hub'                     }
  , 'groestlcoin'      => { coin => 'GRS'  , port => 20486, algo => 'groestl'        , domain => 'hub'                     }
  , 'litecoin'         => { coin => 'LTC'  , port => 20460, algo => 'scrypt'         , domain => 'hub'                     }
  , 'maxcoin'          => { coin => 'MAX'  , port => 20461, algo => 'keccak'         , domain => 'hub'                     }
  , 'monacoin'         => { coin => 'MONA' , port => 20593, algo => 'lyra2rev2'      , domain => 'hub'                     }
  , 'monero'           => { coin => 'XMR'  , port => 20580, algo => 'cryptonight'    , domain => 'us-east.cryptonight-hub' }
  , 'musicoin'         => { coin => 'MUSIC', port => 20585, algo => 'ethash'         , domain => 'us-east.ethash-hub'      }
  , 'vertcoin'         => { coin => 'VTC'  , port => 20507, algo => 'lyra2rev2'      , domain => 'hub'                     }
  , 'zcash'            => { coin => 'ZEC'  , port => 20570, algo => 'equihash'       , domain => 'us-east.equihash-hub'    }
  , 'zclassic'         => { coin => 'ZCL'  , port => 20575, algo => 'equihash'       , domain => 'us-east.equihash-hub'    }
  , 'zcoin'            => { coin => 'XZC'  , port => 20581, algo => 'lyra2z'         , domain => 'us-east.lyra2z-hub'      }
  , 'zencash'          => { coin => 'ZEN'  , port => 20594, algo => 'equihash'       , domain => 'us-east.equihash-hub'    }
);

while(my($name, $pool) = each %pools)
{
  $$pool{name} = $name
}

#
# for pplns, you have to wait at least an hour
#

sub new
{
  my %args = @_;

  bless {
      name => "miningpoolhub"
    , "cache-dir" => $args{"cache-dir"}
    , "mph-apikey" => $args{"mph-apikey"}
    , "mph-username" => $args{"mph-username"}
    , "mph-switching-period" => $args{"mph-switching-period"}
    , "mph-round-duration-limit" => $args{"mph-round-duration-limit"} || 0xffffffff
  }
}

sub switching_period
{
  my ($self) = @_;

  $$self{"mph-switching-period"} || 0
}

#
# calculate price per hash for each mining pool
#
sub load_rates
{
  my ($self, $coinstats) = @_;

  while(my($coin, $stats) = each %$coinstats)
  {
    next unless $$stats{mining};
    for my $mining (@{$$stats{mining}})
    {
      while(my($name, $pool) = each %pools)
      {
        next unless $$pool{coin} eq $coin and $$pool{algo} eq $$mining{algorithm};

        my $dayreward = $$mining{blockreward} * ((60 * 60 * 24) / $$mining{blocktime});
        my $dayreward_btc = $dayreward * $$stats{price_btc};
        my $rate = $dayreward_btc / $$mining{nethash};

        $$self{rates}{$name} = $rate;
      }
    }
  }

  # load aggregated pool stats
  my $path = sprintf("%s/miningpoolhub/present", $$self{"cache-dir"});
  open(my $fh, "<$path") or die "open($path) : $!";
  my $text = do { local $/ = undef ; <$fh> };
  close $fh;
  $$self{poolstats} = decode_json($text);
}

sub assemble_mining_options
{
  my ($self, $miners) = @_;

  my @options;
  while(my($name, $pool) = each %pools)
  {
    if(!$$self{rates}{$name})
    {
      logf("IGNORING $$self{name}/$name (no mining stats)") if $::verbose;
      next;
    }

    if(!$$self{poolstats}{$name})
    {
      logf("IGNORING $$self{name}/$name (no pool stats)") if $::verbose;
      next;
    }

    if($$self{poolstats}{$name}{timesincelast} > $$self{"mph-round-duration-limit"})
    {
      logf("IGNORING $$self{name}/$name (timesincelast %s)", durationstring($$self{poolstats}{$name}{timesincelast})) if $::verbose;
      next;
    }

    my @pool_options;
    for my $miner (@$miners)
    {
      if($$miner{algos}{$$pool{algo}})
      {
        push @options, option::new(
            market => $self
          , miner => $miner
          , algo => $$miner{algos}{$$pool{algo}}
          , pool => $pool
        );
      }
    }

    if(!@pool_options)
    {
      logf("IGNORING $$self{name}/$name (no miner)") if $::verbose;
    }

    push @options, @pool_options;
  }

  return @options
}

sub evaluate_option
{
  my ($self, $option) = @_;

  # extra data to persist
  my $price = $self->_current_price($option);
  $$option{current_price} = $price;

  $$option{predicted_profit_noboost} = $$option{algo}{hashrate} * $self->_current_price($option);
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

  my $price = $$option{current_price};
  printf("   %20s %14.8f BTC/MH/day\n"
    , "current price"
    , $price
  );

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

sub miner_env_params
{
  my ($self, $option) = @_;

  my $algo = $$option{pool}{algo};
  my $port = $$option{pool}{port};
  my $domain = $$option{pool}{domain};

  my %params;
  $params{AUTOMINER_ALGO} = $algo;
  $params{AUTOMINER_PORT} = $port;
  $params{AUTOMINER_URL_AUTHORITY} = "$domain.miningpoolhub.com:$port";
  $params{AUTOMINER_USERNAME} = $$self{"mph-username"};
  $params{AUTOMINER_USERNAME} .= "." . $::opts{worker} if $::opts{worker};
  %params
}

sub _getuserbalance
{
  my ($self, $pool) = @_;

  my $rest = rest_prep(
      "https://$$pool{name}.miningpoolhub.com/index.php"
    , page => "api"
    , action => "getuserbalance"
    , api_key => $$self{"mph-apikey"}
  );
  my $balance;
  while(not defined $balance && $$rest{sleep} < 60)
  {
    my $response = rest_get($rest);
    $balance = try {
      $$response{getuserbalance}{data}{confirmed} + $$response{getuserbalance}{data}{unconfirmed}
    } if $response;
  }

  $balance
}

sub getpoolstatus
{
  my ($self, $poolname) = @_;

  my $rest = rest_prep(
      "https://$poolname.miningpoolhub.com/index.php"
    , page => "api"
    , action => "getpoolstatus"
    , api_key => $$self{"mph-apikey"}
  );
  my $poolstatus;
  while(not defined $poolstatus && $$rest{sleep} < 60)
  {
    my $response = rest_get($rest);
    $poolstatus = try { $$response{getpoolstatus}{data} } if $response;
  }

  $poolstatus;
}

# returns time to mine this option until the next checkpoint
sub option_start
{
  my ($self, $option) = @_;

  if(!$$option{checkpoint}{lastblock})
  {
    my $balance = $self->_getuserbalance($$option{pool});
    return 0 if not defined $balance;
    $$option{checkpoint}{balance} = $balance;

    my $poolstatus = $self->getpoolstatus($$option{pool}{name});
    return 0 if not defined $poolstatus;
    $$option{checkpoint}{lastblock} = $$poolstatus{lastblock};
    $$option{checkpoint}{difficulty} = $$poolstatus{networkdiff};
  }
}

# no special requirement ; fallback to the global switching period
sub get_mining_interval
{
}

# assume actual = predicted for now
sub get_mining_results
{
  my ($self, $option) = @_;

  return {
    profit => $$option{predicted_profit}
  }
}

sub accumulate_mining_results
{
  my ($self, $results, $interval_results) = @_;

  $$results{profit} = $$interval_results{profit};
}

# data to record in the history for the interval
sub option_record_params
{
  my ($self, $option) = @_;

  my %params;
  $params{current_price} = $$option{current_price};
  $params{starting_balance} = $$option{checkpoint}{balance};
  $params{starting_lastblock} = $$option{checkpoint}{lastblock};
  $params{starting_difficulty} = $$option{checkpoint}{difficulty};
  %params
}

sub _current_price
{
  my ($self, $option) = @_;

  $$self{rates}{$$option{pool}{name}}
}

1
