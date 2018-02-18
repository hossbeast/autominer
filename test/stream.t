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
use stream;

use lib "test/lib";
use asserts;
use test_util;

my $dir = "(dir)";
my $retention = 5;
my $text = "(text)";
my $path = "(path)";
sub mocked_stream
{
  my $stream = bless { }, 'stream';
  $stream = Test::MockObject::Extends->new($stream);
  $stream->set_true('_symlinkf');
  $stream->set_true('_uxunlink');
  $stream->set_true('_mkdirp');
  $stream->set_true('_write_to');
  $stream->set_true('_readable');
  $stream->set_always('_readlink', undef);

  $stream
}

sub test_init_empty
{
  my $stream = mocked_stream();

  # act
  stream_init($stream, $dir, $retention);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_all_mocked_calls($stream);
}

sub test_init_cleanup
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 45, 35);
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/45');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/35');

  is_mocked_call($stream, '_uxunlink', '(dir)/00035');
  is_mocked_call($stream, '_uxunlink', '(dir)/00036');
  is_mocked_call($stream, '_uxunlink', '(dir)/00037');
  is_mocked_call($stream, '_uxunlink', '(dir)/00038');
  is_mocked_call($stream, '_uxunlink', '(dir)/00039');
  is_mocked_call($stream, '_uxunlink', '(dir)/00040');
  is_mocked_call($stream, '_symlinkf', '00041', '(dir)/tail');
  is_mocked_call($stream, '_symlinkf', '00042', '(dir)/tail+1');
  is_mocked_call($stream, '_symlinkf', '00043', '(dir)/tail+2');
  is_mocked_call($stream, '_symlinkf', '00044', '(dir)/tail+3');
  is_mocked_call($stream, '_symlinkf', '00045', '(dir)/tail+4');
  is_all_mocked_calls($stream);
}

sub test_write_empty
{
  my $stream = mocked_stream();
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);
  $stream->write($text);
  $stream->set_always('_head_sync', undef);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_write_to', '(dir)/00001', '(text)');
  is_mocked_call($stream, '_head_sync');
  is_all_mocked_calls($stream);
}

sub test_write_single
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 5, 5);
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);
  $stream->write($text);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/5');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/5');
  is_mocked_call($stream, '_write_to', '(dir)/00006', '(text)');
  is_mocked_call($stream, '_head_sync');
  is_all_mocked_calls($stream);
}

sub test_write_few
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 5, 4);
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);
  $stream->write($text);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/5');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/4');
  is_mocked_call($stream, '_write_to', '(dir)/00006', '(text)');
  is_mocked_call($stream, '_head_sync');
  #is_mocked_call($stream, '_symlinkf', '00006', '(dir)/head');
  #is_mocked_call($stream, '_symlinkf', '00005', '(dir)/head-1');
  #is_mocked_call($stream, '_symlinkf', '00004', '(dir)/head-2');
  is_all_mocked_calls($stream);
}

sub test_append_empty
{
  my $stream = mocked_stream();
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);
  $stream->append($path);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_symlinkf', '(path)', '(dir)/00001');
  is_mocked_call($stream, '_head_sync');
  is_all_mocked_calls($stream);
}

sub test_append_notempty
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 12, 9);
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);
  $stream->append($path);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/12');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/9');
  is_mocked_call($stream, '_symlinkf', '(path)', '(dir)/00013');
  is_mocked_call($stream, '_head_sync');
  is_all_mocked_calls($stream);
}

sub test_append_boundary
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 12, 8);
  $stream->set_always('_head_sync', undef);

  # act
  stream_init($stream, $dir, $retention);
  $stream->append($path);

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/12');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/8');
  is_mocked_call($stream, '_symlinkf', '(path)', '(dir)/00013');
  is_mocked_call($stream, '_head_sync');
  is_all_mocked_calls($stream);
}

sub test_sync_few
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 12, 8);

  # act
  stream_init($stream, $dir, $retention);
  $stream->_head_sync();

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/12');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/8');
  is_mocked_call($stream, '_symlinkf', '00012', '(dir)/head');
  is_mocked_call($stream, '_symlinkf', '00011', '(dir)/head-1');
  is_mocked_call($stream, '_symlinkf', '00010', '(dir)/head-2');
  is_mocked_call($stream, '_symlinkf', '00009', '(dir)/head-3');
  is_mocked_call($stream, '_symlinkf', '00008', '(dir)/head-4');
  is_all_mocked_calls($stream);
}

sub test_sync_boundary
{
  my $stream = mocked_stream();
  $stream->set_series('_readlink', 12, 7);

  # act
  stream_init($stream, $dir, $retention);
  $stream->_head_sync();

  # assert
  is_mocked_call($stream, '_mkdirp', '(dir)');
  is_mocked_call($stream, '_readlink', '(dir)/head');
  is_mocked_call($stream, '_readable', '(dir)/12');
  is_mocked_call($stream, '_readlink', '(dir)/tail');
  is_mocked_call($stream, '_readable', '(dir)/7');
  is_mocked_call($stream, '_uxunlink', '(dir)/00007');
  is_mocked_call($stream, '_symlinkf', '00008', '(dir)/tail');
  is_mocked_call($stream, '_symlinkf', '00009', '(dir)/tail+1');
  is_mocked_call($stream, '_symlinkf', '00010', '(dir)/tail+2');
  is_mocked_call($stream, '_symlinkf', '00011', '(dir)/tail+3');
  is_mocked_call($stream, '_symlinkf', '00012', '(dir)/tail+4');
  is_mocked_call($stream, '_symlinkf', '00012', '(dir)/head');
  is_mocked_call($stream, '_symlinkf', '00011', '(dir)/head-1');
  is_mocked_call($stream, '_symlinkf', '00010', '(dir)/head-2');
  is_mocked_call($stream, '_symlinkf', '00009', '(dir)/head-3');
  is_mocked_call($stream, '_symlinkf', '00008', '(dir)/head-4');
  is_all_mocked_calls($stream);
}

test_init_empty();
test_init_cleanup();
test_write_empty();
test_write_single();
test_write_few();
test_append_empty();
test_append_notempty();
test_append_boundary();
test_sync_few();
test_sync_boundary();
done_testing();
