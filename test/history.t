#!/usr/bin/env perl

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

use strict;
use warnings;

use Carp;
$SIG{__WARN__} = sub { die @_ };
$SIG{__DIE__} = \&confess;

use Test::More;
use Test::MockObject::Extends;

use lib "lib";
use history;

use lib "test/lib";
use asserts;
use test_util;

my $head = 42;

my $dir = '(dir)';
my $profile = '(profile)';
my $retention = 5;
my $worker = '(worker)';
my $text = '(text)';
my $service = '(service)';
my $pool = '(pool)';
my $address = '(address)';
my $path = '(path)';
my $algo = '(algo)';
my $miner = '(miner)';

my @streams;
sub mocked_stream
{
  my $stream = bless { }, 'stream';
  $stream = Test::MockObject::Extends->new($stream);
  $stream->set_true('write');
  $stream->set_true('append');
  $stream->set_always('get_path_to_base', $path);
  $stream->set_true('set_path_to_base');
  $stream->set_bound('get_head', \$head);
  push @streams, $stream;
  $stream
}

sub mocked_history
{
  $#streams = -1;
  my $history = bless { }, 'history';
  $history = Test::MockObject::Extends->new($history);
  $history->mock('_stream_new', \&mocked_stream);

  $history
}

sub test_write_zero
{
  my $history = mocked_history();

  # act
  history_init($history, $dir, $retention, $profile);
  $history->write($text);

  # assert
  is_mocked_call($history, '_stream_new', '(dir)/profile/(profile)', 5);
  is_all_mocked_calls($history);

  is_mocked_call($streams[0], 'set_path_to_base', '../../profile/(profile)');
  is_mocked_call($streams[0], 'write', '(text)');
  is_mocked_call($streams[0], 'get_head');
  is_all_mocked_calls($streams[0]);
}

sub test_write_one
{
  my $history = mocked_history();

  # act
  history_init($history, $dir, $retention, $profile);
  $history->push(worker => $worker);
  $history->write($text);

  # assert
  is_mocked_call($history, '_stream_new', '(dir)/profile/(profile)', 5);
  is_mocked_call($history, '_stream_new', '(dir)/worker/(worker)/(profile)', 5);
  is_all_mocked_calls($history);

  is_mocked_call($streams[0], 'set_path_to_base', '../../profile/(profile)');
  is_mocked_call($streams[0], 'write', '(text)');
  is_mocked_call($streams[0], 'get_head');
  is_all_mocked_calls($streams[0]);

  is_mocked_call($streams[1], 'set_path_to_base', '../../../profile/(profile)');
  is_mocked_call($streams[1], 'get_path_to_base');
  is_mocked_call($streams[1], 'append', '(path)/00042');
  is_all_mocked_calls($streams[1]);
}

sub test_write_many
{
  my $history = mocked_history();

  # act
  history_init($history, $dir, $retention, $profile);
  $history->push(address => $address);
  $history->push(service => $service, pool => $pool);
  $history->write($text);

  # assert
  is_mocked_call($history, '_stream_new', '(dir)/profile/(profile)', 5);
  is_mocked_call($history, '_stream_new', '(dir)/address/(address)/(profile)', 5);
  is_mocked_call($history, '_stream_new', '(dir)/pool/(pool)/service/(service)/(profile)', 5);
  is_all_mocked_calls($history);

  is_mocked_call($streams[0], 'set_path_to_base', '../../profile/(profile)');
  is_mocked_call($streams[0], 'write', '(text)');
  is_mocked_call($streams[0], 'get_head');
  is_all_mocked_calls($streams[0]);

  is_mocked_call($streams[1], 'set_path_to_base', '../../../profile/(profile)');
  is_mocked_call($streams[1], 'get_path_to_base');
  is_mocked_call($streams[1], 'append', '(path)/00042');
  is_all_mocked_calls($streams[1]);

  is_mocked_call($streams[2], 'set_path_to_base', '../../../../../profile/(profile)');
  is_mocked_call($streams[2], 'get_path_to_base');
  is_mocked_call($streams[2], 'append', '(path)/00042');
  is_all_mocked_calls($streams[2]);
}

sub test_write_rewind
{
  my $history = mocked_history();

  # act
  history_init($history, $dir, $retention, $profile);
  $history->push(address => $address);
  $history->mark();
  $history->push(service => $service);
  $history->rewind();
  $history->push(algo => $algo);
  $history->write($text);

  # assert
  is_mocked_call($history, '_stream_new', '(dir)/profile/(profile)', 5);
  is_mocked_call($history, '_stream_new', '(dir)/address/(address)/(profile)', 5);
  is_mocked_call($history, '_stream_new', '(dir)/service/(service)/(profile)', 5);
  is_mocked_call($history, '_stream_new', '(dir)/algo/(algo)/(profile)', 5);
  is_all_mocked_calls($history);

  # base profile stream
  is_mocked_call($streams[0], 'set_path_to_base', '../../profile/(profile)');
  is_mocked_call($streams[0], 'write', '(text)');
  is_mocked_call($streams[0], 'get_head');
  is_all_mocked_calls($streams[0]);

  # address stream
  is_mocked_call($streams[1], 'set_path_to_base', '../../../profile/(profile)');
  is_mocked_call($streams[1], 'get_path_to_base');
  is_mocked_call($streams[1], 'append', '(path)/00042');
  is_all_mocked_calls($streams[1]);

  # service stream - skipped
  is_mocked_call($streams[2], 'set_path_to_base', '../../../profile/(profile)');
  is_all_mocked_calls($streams[2]);

  # algo stream
  is_mocked_call($streams[3], 'set_path_to_base', '../../../profile/(profile)');
  is_mocked_call($streams[3], 'get_path_to_base');
  is_mocked_call($streams[3], 'append', '(path)/00042');
  is_all_mocked_calls($streams[3]);
}

test_write_zero();
test_write_one();
test_write_many();
test_write_rewind();
done_testing();
