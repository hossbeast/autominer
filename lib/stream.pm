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

package stream;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|stream_init stream_get_path_frag|;

use ring;
use util;
use xlinux;

my $edge_links = 4;

sub _symlinkf { shift ; goto &util::symlinkf }
sub _readlink { shift ; goto &CORE::readlink }
sub _readable { shift ; -r $_[0] }
sub _uxunlink { shift ; goto &xlinux::uxunlink }
sub _mkdirp   { shift ; goto &util::mkdirp }
sub _write_to
{
  my ($self, $path, $text) = @_;

  open(my $fh, ">$path") or die ("open($path) : $!");
  syswrite($fh, $text, length($text));
}
sub _read_from
{
  my ($self, $path) = @_;

  my $fh = uxfhopen("$path");
  my $text = undef;
  $text = do { local $/ ; <$fh> } if $fh;
  $text
}

sub get_head          { $_[0]{head} }
sub get_path_to_base  { $_[0]{path_to_base} }
sub set_path_to_base  { $_[0]{path_to_base} = $_[1] }

sub _link_head_edge
{
  my ($self) = @_;

  # recent
  my $x;
  for($x = 1; $x <= $edge_links; $x++)
  {
    last if ring_sub($$self{head}, $$self{tail}, 0xffff) < $x;
    my $num = ring_sub($$self{head}, $x, 0xffff);
    $self->_symlinkf(sprintf("%05u", $num), sprintf("%s/head-%d", $$self{dir}, $x));
  }

  for(; $x <= $edge_links; $x++)
  {
    $self->_uxunlink(sprintf("%s/head-%d", $$self{dir}, $x));
  }
}

sub _link_tail_edge
{
  my ($self) = @_;

  $self->_symlinkf(sprintf("%05u", $$self{tail}), "$$self{dir}/tail");

  # ancient
  my $x;
  for($x = 1; $x <= $edge_links; $x++)
  {
    last if ring_sub($$self{head}, $$self{tail}, 0xffff) < $x;
    my $num = ring_add($$self{tail}, $x, 0xffff);
    $self->_symlinkf(sprintf("%05u", $num), sprintf("%s/tail+%d", $$self{dir}, $x));
  }

  for(; $x <= $edge_links; $x++)
  {
    $self->_uxunlink(sprintf("%s/tail+%d", $$self{dir}, $x));
  }
}

sub _head_sync
{
  my ($self, $dir, $num) = @_;

  # head
  $self->_symlinkf(sprintf("%05u", $$self{head}), "$$self{dir}/head");

  # tail
  if(not defined $$self{tail})
  {
    $$self{tail} = $$self{head};
    $self->_link_tail_edge();
  }
  elsif(ring_sub($$self{head}, $$self{tail}, 0xffff) >= $$self{retention})
  {
    $self->_uxunlink(sprintf("%s/%05u", $$self{dir}, $$self{tail}));
    $$self{tail} = ring_add($$self{tail}, 1, 0xffff);
    $self->_link_tail_edge();
  }
  elsif(ring_sub($$self{head}, $$self{tail}, 0xffff) < $edge_links)
  {
    $self->_link_tail_edge();
  }

  $self->_link_head_edge();
}

sub stream_get_path_frag
{
  my ($profile, %tuples) = @_;

  my $stream_id = '';
  for my $key (sort keys %tuples)
  {
    $stream_id .= "/" if $stream_id;
    $stream_id .= "$key/$tuples{$key}";
  }

  my $dir = $stream_id;
  if(not $tuples{profile})
  {
    $dir .= "/$profile";
  }

  $dir;
}

#
# PARAMETERS
#  dir       -
#  retention - samples to retain
#
sub stream_init
{
  my ($self, $dir, $retention) = @_;

  $retention ||= 0xffff;

  $$self{dir} = $dir;
  $$self{retention} = $retention;

  $self->_mkdirp($$self{dir});

  my $head = $self->_readlink("$dir/head");
  $head = undef if $head and ! $self->_readable("$dir/$head");
  $head = int $head if $head;
  $$self{head} = $head;

  my $tail = $self->_readlink("$dir/tail");
  $tail = undef if $tail and ! $self->_readable("$dir/$tail");
  $tail = int $tail if $tail;
  $$self{tail} = $tail;

  # prune files outside the retention window
  if(defined $$self{head} and defined $$self{tail})
  {
    my $tail_start = $$self{tail};
    while(ring_sub($$self{head}, $$self{tail}, 0xffff) >= $$self{retention})
    {
      $self->_uxunlink(sprintf("%s/%05u", $dir, $$self{tail}));
      $$self{tail} = ring_add($$self{tail}, 1, 0xffff);
    }

    if($tail_start != $$self{tail})
    {
      $self->_link_tail_edge();
    }
  }

  $self
}

sub new
{
  my $stream = bless { };
  stream_init($stream, @_)
}

sub write
{
  my ($self, $text) = @_;

  $$self{head} = 0 unless $$self{head};
  $$self{head} = ring_add($$self{head}, 1, 0xffff);

  my $head_path = sprintf("%s/%05u", $$self{dir}, $$self{head});
  $self->_write_to($head_path, $text);

  $self->_head_sync();
}

sub append
{
  my ($self, $dest) = @_;

  $$self{head} = 0 unless $$self{head};
  $$self{head} = ring_add($$self{head}, 1, 0xffff);

  my $head_path = sprintf("%s/%05u", $$self{dir}, $$self{head});
  $self->_symlinkf($dest, $head_path);

  $self->_head_sync();
}

sub read
{
  my ($self, $num) = @_;

  my $path = sprintf("%s/%05u", $$self{dir}, $num);
  $self->_read_from($path);
}
