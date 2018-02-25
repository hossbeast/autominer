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

package child_commands;

#
# Facilities for creating child processes to carry out various tasks, to be used with child_manager
#

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|curl run filter|
  , qw|rest_prep rest_get|
);

use Data::Dumper;
use Errno ':POSIX';
use Fcntl;
use Fcntl 'SEEK_SET';
use POSIX;
use JSON::XS;

use child_manager;
use util;
use xlinux;
use logger;

sub _report_command
{
  return unless $::verbose;

  my ($pid, $cmd, $status, $output) = @_;

  my $exit = $status >> 8;
  my $signal = $status & 127;

  my $result = "exit $exit";
  $result .= " signal $signal" if $signal;

  print(" [pid $pid $result] @$cmd");
  print("\n");
}

sub _consume
{
  my ($pid, $read_fd) = @_;

  my $output = '';
  my $status;
  while(1)
  {
    my $data;
    my $r = aread($read_fd, $data, 0xffff);
    if($r)
    {
      $output .= $data;
      next;
    }
    if(not defined $status)
    {
      $status = childstatus($pid);
    }
    last if defined $status;
    select(undef, undef, undef, 0.25);
  }

  ($status, $output)
}

# execute a command in a child process, return its exit status and collected stdout
sub run
{
  my @cmd = @_;

  my($read_fd, $write_fd) = POSIX::pipe() or die;
  my $pid = fork();
  if(!$pid)
  {
    POSIX::close($read_fd);

    POSIX::close(0) or die "close(0) : $!";
    POSIX::dup2($write_fd, 1) or die "dup2($write_fd, 1) : $!";

    chdir("/") or die "chdir(/) : $!";
    pr_set_pdeathsig(9) or die("pr_set_pdeathsig(9) : $!");

    exec { $cmd[0] } @cmd;
  }

  putchild("run-$pid", $pid, transient => 1);

  POSIX::close($write_fd) or die("close($write_fd) : $!");
  my ($status, $output) = _consume($pid, $read_fd);
  POSIX::close($read_fd) or die("close($read_fd) : $!");
  chomp $output if $output;

  _report_command($pid, \@cmd, $status, $output);

  ($status, $output)
}

# invoke curl in a child process, return its exit status and collected output
sub curl
{
  my $url = shift;
  my %params = @_;

  my $query = '';
  for my $k (sort keys %params)
  {
    $query .= "&" if $query;
    $query .= "?" if not $query;

    $query .= $k;
    $query .= "=";
    $query .= $params{$k};
  }

  my($read_fd, $write_fd) = POSIX::pipe() or die;
  my @cmd = (
      "curl"
    , "${url}${query}"
    , "-s"
    , "-o", "/dev/fd/$write_fd"
  );

  my $pid = fork();
  if(!$pid)
  {
    POSIX::close($read_fd);

    open(my $wh, "<&=$write_fd") or die;
    my $flags = fcntl $wh, F_GETFD, 0 or die $!;
    fcntl $wh, F_SETFD, $flags &= ~FD_CLOEXEC or die $!;

    chdir("/") or die "chdir(/) : $!";
    pr_set_pdeathsig(9) or die("pr_set_pdeathsig(9) : $!");

    exec { $cmd[0] } @cmd;
  }

  putchild("curl-$pid", $pid, transient => 1);

  POSIX::close($write_fd) or die("close($write_fd) : $!");
  my ($status, $output) = _consume($pid, $read_fd);
  POSIX::close($read_fd) or die("close($read_fd) : $!");
  chomp $output if $output;

  _report_command($pid, \@cmd, $status, $output);

  ($status, $output)
}

# invoke a child process, piping a string to it on stdin, returns the exit status of the command,
# and its collected stdout as a single scalar
sub filter
{
  my ($cmd, $text) = @_;

  my($in_reader, $in_writer) = POSIX::pipe() or die;
  my($out_reader, $out_writer) = POSIX::pipe() or die;
  my $pid = fork();
  if($pid == 0)
  {
    POSIX::close($in_writer) or die;
    POSIX::dup2($in_reader, 0) or die;
    POSIX::close($in_reader) or die;

    POSIX::close($out_reader) or die;
    POSIX::dup2($out_writer, 1) or die("dup2($out_writer, 1) : $!");
    POSIX::close($out_writer) or die;

    pr_set_pdeathsig(9) or die("pr_set_pdeathsig(9) : $!");

    exec { $$cmd[0] } @$cmd;
  }

  putchild("filter-$pid", $pid, transient => 1);

  POSIX::close($in_reader) or die;
  POSIX::close($out_writer) or die;

  if($text)
  {
    POSIX::write($in_writer, $text, length($text)) or die $!;
  }

  POSIX::close($in_writer) or die;
  my ($status, $output) = _consume($pid, $out_reader);
  POSIX::close($out_reader);
  chomp $output if $output;

  _report_command($pid, $cmd, $status, $output);

  ($status, $output)
}

# creates a context object for invoking rest_get
sub rest_prep
{
  my ($url, %params) = @_;

  return {
      url => $url
    , params => \%params
    , sleep => -1
  };
}

# call a rest api
sub rest_get
{
  my ($rest) = @_;

  # 1, 3, 6, 11, 19, 32, 52
  $$rest{sleep}++;
  if($$rest{sleep})
  {
    sleep($$rest{sleep} + rand(3));
    $$rest{sleep} = int($$rest{sleep} * 1.4);
  }

  my ($status, $text) = curl($$rest{url}, %{$$rest{params}});
  if($status != 0)
  {
    logf("failed to get results");
    return undef;
  }

  my ($error, $data) = try { decode_json($text) };
  if($error)
  {
    logf("unable to interpret results");
    logf(" $error");
    logf(" $text");
    return undef;
  }

  return $data
}

1
