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

package history;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|history_init|;

use stream;
use util;
use xlinux;

sub _stream_new { shift ; stream::new(@_) }

sub _make_stream
{
  my ($self, %tuples) = @_;

  my $dir = $$self{history_dir} . "/" . stream_get_path_frag($$self{profile}, %tuples);

  my $path_to_base = sprintf("%s/profile/%s"
    , join("/", map { "../.." } keys %tuples)
    , $$self{profile}
  );

  if(not $tuples{profile})
  {
    $path_to_base = "../$path_to_base";
  }

  my $stream = $self->_stream_new($dir, $$self{retention});
  $stream->set_path_to_base($path_to_base);
  $stream
}

sub history_init
{
  my ($self, $history_dir, $retention, $profile) = @_;

  $$self{history_dir} = $history_dir;
  $$self{profile} = $profile;
  $$self{retention} = $retention;
  $$self{streams} = [];
  $$self{stream} = $self->_make_stream(profile => $profile);
}

sub new
{
  my $history = bless { };
  history_init($history, @_);
  $history
}

sub mark
{
  my ($self) = @_;

  $$self{mark} = $#{$$self{streams}}
}

sub rewind
{
  my ($self) = @_;

  $#{$$self{streams}} = $$self{mark}
}

# add another history stream
sub push
{
  my ($self, %tuples) = @_;

  push @{$$self{streams}}, $self->_make_stream(%tuples);
}

# append the results of the latest period to the history streams
sub write
{
  my ($self, $text) = @_;

  # save this option in the head entry
  $$self{stream}->write($text);

  my $base_head = sprintf("%05u", $$self{stream}->get_head());
  for my $stream (@{$$self{streams}})
  {
    my $path_to_base = $stream->get_path_to_base();
    $stream->append("$path_to_base/$base_head");
  }
}

1
