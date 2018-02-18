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

package boost;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|boost_configure boost_init get_boost|;

use JSON::XS;
use Data::Dumper;

use logger;
use ring;
use stream;
use util;

my $boost_disabled_key = '(boost-disabled)';
our $boost_enabled = 0;
our %boosts;
our $boost_trailing_window_samples = 1;
our $boost_trailing_window_seconds = 1;
our $boost_trailing_window_pad = 0;
our $boost_show_boost = 0;
our $history_dir;
our $profile;

#
# internal
#

sub _boost_key
{
  my %tuples = @_;

  my $key = '';
  for my $tag (qw|market pool miner algo|)
  {
    $key .= '/' if $key;
    $key .= $tuples{$tag};
  }

  $key
}

#
# public
#

sub get_boost
{
  my $key = $boost_disabled_key if !$boost_enabled;
  $key = _boost_key(@_) if $boost_enabled;

  if(not exists $boosts{$key})
  {
    $boosts{$key} = boost::new($key);
  }

  $boosts{$key}
}

#
# initialize boosts from the history stream for the profile
#
sub _boosts_initialize
{
  my $T = time();
  my %boost_samples;

  # get the base stream for the profile
  my $stream_path = stream_get_path_frag($profile, profile => $profile);
  my $stream_dir = $history_dir . "/$stream_path";
  die "no such history $stream_dir" unless -d $stream_dir;
  my $stream = stream::new($stream_dir, 0xffff);

  return unless defined $$stream{head};

  # read the stream in reverse order
  my $x = ring_add($$stream{head}, 1, 0xffff);
  while(1)
  {
    last if $x == $$stream{tail};
    $x = ring_sub($x, 1, 0xffff);

    my $text = $stream->read($x);
    next unless $text;
    my $record = decode_json($text);

    last if ($T - $$record{"start"}) > $boost_trailing_window_seconds;

    my $key = _boost_key(%$record);
    push @{$boost_samples{$key}}, {
        "time" => $$record{start}
      , variance => variance2($$record{predicted_profit}, $$record{actual_profit} || 0)
    };
  }

  for my $key (sort keys %boost_samples)
  {
    my $samples = $boost_samples{$key};
    $boosts{$key} = boost::new($key, @$samples);
    $boosts{$key}->report() if $boost_show_boost;
  }
}

sub boost_configure
{
  my %opts = @_;

  return unless $opts{"boost"};

  $boost_enabled = 1;
  $boost_trailing_window_samples = $opts{"boost-trailing-window-samples"};
  $boost_trailing_window_seconds = $opts{"boost-trailing-window-seconds"};
  $boost_trailing_window_pad = $opts{"boost-trailing-window-pad"} || 0;
  $boost_show_boost = $opts{"show-boost"};
  $history_dir = $opts{"history-dir"};
  $profile = $opts{"profile"};

  _boosts_initialize();
}

#
# OOO
#

sub _update
{
  my ($self) = @_;

  # truncate the list to its maximum size
  if($#{$$self{samples}} >= $boost_trailing_window_samples)
  {
    $#{$$self{samples}} = $boost_trailing_window_samples - 1;
  }

  my $sum = 0;
  map { $sum += $$_{variance} } @{$$self{samples}};

  # pad the sum by filling the window with 1s
  $sum += $boost_trailing_window_samples - ($#{$$self{samples}} + 1);
  $sum += $boost_trailing_window_pad;

  my $samples = $boost_trailing_window_samples + $boost_trailing_window_pad;

  $$self{modifier} = $sum / $samples;

  $self
}

sub boost_init
{
  my ($self, $key, @samples) = @_;

  $$self{key} = $key;
  $$self{samples} = [ ];

  @{$$self{samples}} = @samples if @samples;

  $self->_update()
}

sub new
{
  my $boost = bless { };
  boost_init($boost, @_)
}

sub report
{
  my ($self) = @_;

  logf("boost for %-60s %6.2f over %d samples"
    , $$self{key}
    , $$self{modifier}
    , $#{$$self{samples}} + 1
  );
}

# samples are ordered [start of list] -> newer -> older [end of list]
sub sample
{
  my ($self, $time, $variance) = @_;

  return if !$boost_enabled;

  # age out old samples from the end
  while(@{$$self{samples}} && (time() - $$self{samples}[-1]{"time"}) > $boost_trailing_window_seconds)
  {
    pop @{$$self{samples}};
  }

  # prepend the new sample
  unshift @{$$self{samples}}, { "time" => $time, variance => $variance };

  $self->_update();
}

1
