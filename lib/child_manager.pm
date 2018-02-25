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

package child_manager;

#
# Handles SIGCHLD and provides an abstraction around managing child processes in which children are
# able to be referenced by name. On top of this, provides facilities for killing children, and for
# creating children to perform various tasks.
#

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|child_manager_configure|
  , qw|putchild childstatus killfast killchildren|
  , qw|%children_by_pid %children_by_name|
  , qw|$child_manager_sigchld_debug|
);

use Data::Dumper;
use Errno ':POSIX';
use Fcntl;
use Fcntl 'SEEK_SET';
use POSIX;
use JSON::XS;

use util;

our %children_by_pid;
our %children_by_name;
my %status_by_pid;
my %killing_by_pid;

# enable to see each SIGCHLD
our $child_manager_sigchld_debug = 0;

sub _child_handler
{
  local ($!, $?);
  while((my $pid = waitpid(-1, WNOHANG)) > 0) {
    my $exit = $? >> 8;
    my $sig = $? & 127;

    my $name = $children_by_pid{$pid};
    if(!$killing_by_pid{$pid} || $child_manager_sigchld_debug)
    {
      printf("CHLD %s pid=%s, status=%s, exit=%s, signal=%s\n"
        , $name || "(not-tracked)"
        , $pid
        , $?
        , $exit
        , $sig
      )
    }

    if($name)
    {
      delete $children_by_pid{$pid};
      delete $children_by_name{$name};

      $status_by_pid{$pid} = $?;
    }

    # affirmative murder
    kill 9, $pid;
  }
}

sub child_manager_configure
{
  $SIG{CHLD} = \&_child_handler;
}

sub putchild
{
  my ($name, $pid, %params) = @_;

  $children_by_pid{$pid} = $name;
  $children_by_name{$name} = $pid;
  $killing_by_pid{$pid} = 1 if $params{transient};
}

sub childstatus
{
  my ($pid) = @_;

  delete $status_by_pid{$pid}
}

sub killfast
{
  my @pids = @_;

  # ask politely
  for my $pid (@pids)
  {
    kill 15, $pid;
  }

  # wait for compliance
  my $secs = 3;
  my $interval = .1;
  my $maxiter = $secs / $interval;
  my $x;
  for($x = 0; $x < $maxiter; $x++)
  {
    select undef, undef, undef, $interval;
    my $y;
    for($y = 0; $y <= $#pids; $y++)
    {
      last if $children_by_pid{$pids[$y]};
    }

    last if $y > $#pids;
  }

  return if $x < $maxiter;

  # murder
  for my $pid (@pids)
  {
    kill 9, $pid;
  }
}

sub killchildren
{
  my @names = @_;
  @names = keys %children_by_name if !@names;

  my @pids;
  map { push @pids, $children_by_name{$_} if $children_by_name{$_} } @names;
  map { $killing_by_pid{$_} = 1 } @pids;
  killfast(@pids);

  # reap the status for each child
  while(1)
  {
    my $x;
    for($x = 0; $x <= $#pids; $x++)
    {
      next if $pids[$x] == 0;
      if(childstatus($pids[$x]))
      {
        delete $killing_by_pid{$pids[$x]};
        $pids[$x] = 0;
        $x = 0;
      }
    }

    last if $x > $#pids;
  }
}

1
