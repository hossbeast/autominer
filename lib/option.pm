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

package option;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|option_cmp|;

use Data::Dumper;
use JSON::XS;

use boost;
use release;
use util;

sub option_cmp
{
  my ($a, $b) = @_;

     $$a{miner} <=> $$b{miner}
  || $$a{market} <=> $$b{market}
  || ($$a{algo} || 0) <=> ($$b{algo} || 0)
  || ($$a{pool} || 0) <=> ($$b{pool} || 0)
}

sub option_init
{
  my ($self, %args) = @_;

  @$self{keys %args} = values %args;
  $$self{current} = 0;

  $$self{boost} = get_boost(
      miner => $$self{miner}{name}
    , pool => $$self{pool}{name}
    , algo => $$self{algo}{name}
    , market => $$self{market}{name}
  );

  $self
}

sub new
{
  my $option = bless { };
  option_init($option, @_);
}

sub reset
{
}

sub start
{
  my ($self) = @_;

  $$self{start} = time();
  $$self{hashrate_sum} = 0;
  $$self{hashrate_numrecords} = 0;

  $$self{market}->option_start($self);
}

sub end
{
  my ($self, $results) = @_;

  $$self{end} = time();
  $$self{duration} = $$self{end} - $$self{start};
  $$self{actual_profit} = $$results{profit};
}

sub hashrate_sample
{
  my ($self, @records) = @_;

  return if $#records == -1;

  for my $hashrate (@records)
  {
    $$self{hashrate_sum} += $hashrate;
  }

  $$self{hashrate_numrecords} += $#records + 1;
  $$self{hashrate} = $$self{hashrate_sum} / $$self{hashrate_numrecords};
}

sub record
{
  my ($self) = @_;

  my %record = (
      start                     => $$self{start}
    , end                       => $$self{end}
    , duration                  => $$self{duration}
    , version                   => $release::number
    , market                    => $$self{market}{name}
    , pool                      => $$self{pool}{name}
    , miner                     => $$self{miner}{name}
    , algo                      => $$self{algo}{name}
    , hashrate                  => $$self{hashrate}
    , hashrate_numrecords       => $$self{hashrate_numrecords} || 0
    , predicted_profit          => $$self{predicted_profit}
    , predicted_profit_noboost  => $$self{predicted_profit_noboost}
    , actual_profit             => $$self{actual_profit}
  );

  if($boost::boost_enabled)
  {
    $record{boost_modifier} = $$self{boost}{modifier};
    $record{boost_samples} = $#{$$self{boost}{samples}} + 1;
    if($#{$$self{boost}{samples}} >= 0)
    {
      $record{boost_window_start} = $$self{boost}{samples}[-1]{start};
      $record{boost_window_end} = $$self{boost}{samples}[0]{end};
    }
  }

  # additional params from the market
  my %params = $$self{market}->option_record_params($self);
  @record{keys %params} = values %params;

  tojson(\%record) . "\n";
}

1
