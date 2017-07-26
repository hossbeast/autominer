#!/bin/env perl

# Copyright (c) 2017 Todd Freed <todd.freed@gmail.com>
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

package util;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|run killfast curl filter override_warn_and_die|
  , qw|ring_sub ring_add|
);

use File::Temp;
use Errno ':POSIX';
use Fcntl;
use Fcntl 'SEEK_SET';
use POSIX;
use MIME::Base64;
use Data::Dumper;

use xlinux;

sub override_warn_and_die
{
  $SIG{__WARN__} = sub { die @_ };
  $SIG{__DIE__} = sub {
    die @_ if $^S;
    die @_ unless $_[0] =~ /(.*) at .* line.*$/m;
    die "$1\n"
  };
}

# presumes a SIGCHLD which zeroes the pidref
sub killfast
{
  my $pidrefs = shift;

  for my $pidref (@$pidrefs)
  {
    kill 15, $$pidref if $$pidref;
  }

  LOOP : while(1)
  {
    select undef, undef, undef, .01;
    for my $pidref (@$pidrefs)
    {
      next LOOP if $$pidref;
    }
    last;
  }

  for my $pidref (@$pidrefs)
  {
    kill 9, $$pidref if $$pidref;
  }
}

sub curl
{
  my $url = shift;
  my %params = @_;

  my $query = '';
  while(my($k, $v) = each %params)
  {
    $query .= "&" if $query;
    $query .= "?" if not $query;

    $query .= $k;
    $query .= "=";
    $query .= $v;
  }

  my($read_fd, $write_fd) = POSIX::pipe() or die;
  my $pid = fork;
  if(!$pid)
  {
    POSIX::close($read_fd);

    open(my $wh, "<&=$write_fd") or die;
    my $flags = fcntl $wh, F_GETFD, 0 or die $!;
    fcntl $wh, F_SETFD, $flags &= ~FD_CLOEXEC or die $!;

    my @cmd = (
        "curl"
      , "${url}${query}"
      , "-s"
      , "-o", "/dev/fd/$write_fd" # . fileno($wh)
    );

    print STDERR (" > @cmd\n") if $::verbose;
    exec { $cmd[0] } @cmd;
  }

  POSIX::close($write_fd) or die $!;

  my $output = '';
  while(1)
  {
    my $data;
    my $r = POSIX::read($read_fd, $data, 0xffff);
    die "read($read_fd) : $!" unless defined $r;
    last if $r == 0;
    $output .= $data;
  }

  chomp $output if $output;
  POSIX::close($read_fd) or die $!;

  $output
}

sub run
{
  my @cmd = @_;
  print STDERR (" > @cmd\n") if $::verbose;

  my($read_fd, $write_fd) = POSIX::pipe() or die;
  my $pid = fork;
  if(!$pid)
  {
    POSIX::close($read_fd);

    open(STDIN, "</dev/null");
    open(STDOUT, ">&=$write_fd") or die;
    chdir("/") or die;

    exec { $cmd[0] } @cmd;
  }

  POSIX::close($write_fd) or die $!;

  my $output = '';
  while(1)
  {
    my $data;
    my $r = POSIX::read($read_fd, $data, 0xffff);
    die "read($read_fd) : $!" unless defined $r;
    last if $r == 0;
    $output .= $data;
  }

  chomp $output if $output;
  POSIX::close($read_fd) or die $!;

  $output
}

sub filter
{
  my ($cmd, $text) = @_;

  my($in_reader, $in_writer) = POSIX::pipe() or die;
  my($out_reader, $out_writer) = POSIX::pipe() or die;
  my $pid = fork;
  if($pid == 0)
  {
    POSIX::close($in_writer) or die;
    POSIX::dup2($in_reader, 0) or die;
    POSIX::close($in_reader) or die;

    POSIX::close($out_reader) or die;
    POSIX::dup2($out_writer, 1) or die;
    POSIX::close($out_writer) or die;

    pr_set_pdeathsig(9);

    exec { $$cmd[0] } @$cmd;
  }

  print(" [$pid] @$cmd\n") if $::verbose;

  POSIX::close($in_reader) or die;
  POSIX::close($out_writer) or die;

  if($text)
  {
    POSIX::write($in_writer, $text, length($text)) or die $!;
  }
  POSIX::close($in_writer) or die;

  my $output = '';
  while(1)
  {
    my $data;
    my $r = POSIX::read($out_reader, $data, 0xffff);
    die "read($out_reader) : $!" unless defined $r;
    last if $r == 0;
    $output .= $data;
  }

  chomp $output if $output;

  POSIX::close($out_reader);
  $output;
}

sub ring_add
{
  my ($a, $b, $ring) = @_;

  ($a + $b) % $ring
}

sub ring_sub
{
  my ($a, $b, $ring) = @_;

  ($a - $b) % $ring
}

1
