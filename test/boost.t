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

use lib "lib";
use boost;

use lib "test/lib";
use asserts;
use test_util;

my $boost_key = "(dir)";

sub test_nosamples
{
  # arrange
  $boost::boost_enabled = 1;
  $boost::boost_trailing_window_samples = 10;
  $boost::boost_trailing_window_seconds = 0xffffffff;
  $boost::boost_trailing_window_pad = 2;
  my $boost = bless { }, 'boost';

  # act
  boost_init($boost, $boost_key);

  # assert
  cmp_ok($$boost{modifier}, '==', 1);
  cmp_ok($#{$$boost{samples}} + 1, '==', 0);
  is_all_mocked_calls($boost);
}

sub test_fewsamples
{
  # arrange
  $boost::boost_enabled = 1;
  $boost::boost_trailing_window_samples = 10;
  $boost::boost_trailing_window_seconds = 0xffffffff;
  $boost::boost_trailing_window_pad = 2;
  my $boost = bless { }, 'boost';

  # act
  my @samples = (
      { time => 0 , variance => 1 }
    , { time => 0 , variance => 1 }
    , { time => 0 , variance => .5 }
  );
  boost_init($boost, $boost_key, @samples);

  # assert
  cmp_ok($$boost{modifier}, '==', 11.5 / 12);
  cmp_ok($#{$$boost{samples}} + 1, '==', 3);
  is_all_mocked_calls($boost);
}

sub test_windowsize_samples_init
{
  # arrange
  $boost::boost_enabled = 1;
  $boost::boost_trailing_window_samples = 2;
  $boost::boost_trailing_window_seconds = 0xffffffff;
  $boost::boost_trailing_window_pad = 2;
  my $boost = bless { }, 'boost';

  # act
  my @samples = (
      { time => 0 , variance => 1 }
    , { time => 0 , variance => 1 }
    , { time => 0 , variance => .5 } # sample outside the window
  );
  boost_init($boost, $boost_key, @samples);

  # assert
  cmp_ok($$boost{modifier}, '==', 12 / 12);
  cmp_ok($#{$$boost{samples}} + 1, '==', 2);
  is_all_mocked_calls($boost);
}

sub test_windowsize_samples_sample
{
  # arrange
  $boost::boost_enabled = 1;
  $boost::boost_trailing_window_seconds = 0xffffffff;
  $boost::boost_trailing_window_samples = 3;
  $boost::boost_trailing_window_pad = 2;
  my $boost = bless { }, 'boost';

  # act
  boost_init($boost, $boost_key);

  $boost->sample(0 , 1); # sample outside the window
  $boost->sample(0 , 2);
  $boost->sample(0 , 3);
  $boost->sample(0 , 4);

  # assert
  cmp_ok($$boost{modifier}, '==', 11 / 5);
  cmp_ok($#{$$boost{samples}} + 1, '==', 3);
  is_all_mocked_calls($boost);
}

test_nosamples();
test_fewsamples();
test_windowsize_samples_init();
test_windowsize_samples_sample();
done_testing();
