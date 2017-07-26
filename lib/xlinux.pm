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

package xlinux;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|mkdirp symlinkf uxopen uxunlink pr_set_pdeathsig|;

use Errno ':POSIX';
use Fcntl;
use Fcntl 'SEEK_SET';
use POSIX;

# fatal mkdir but only fail when errno != EEXIST
sub mkdirp
{
  my $path = shift;
  return if mkdir $path;
  return if $!{EEXIST};
  die "mkdir($path) : $!"
}

# fatal unlink but only fail when errno != ENOENT
sub uxunlink
{
  my $path = shift;
  return if unlink $path;
  return if $!{ENOENT};
  die "unlink($path) : $!";
}

# rm linkpath (but dont fail if linkpath doesnt exist), then fatal symlink(target, linkpath)
sub symlinkf
{
  my ($target, $linkpath) = @_;

  uxunlink($linkpath);
  symlink($target, $linkpath) or die("symlink($target, $linkpath) : $!");
}

# fatal open but only fail when errno not in { ENOENT, EEXIST }
sub uxopen
{
  my $path = shift;
  my $fh;
  my $r = open($fh, $path);
  return $fh if $r;
  return if $!{ENOENT};
  return if $!{EEXIST};
  die "open($path) : $!";
}

sub pr_set_pdeathsig
{
  my $sig = shift;

  return unless $^O eq 'linux';

  my(undef, undef, undef, undef, $machine) = POSIX::uname();
  my $SYS_prctl = undef;
  $SYS_prctl = 157 if $machine eq "x86_64";
  $SYS_prctl = 172 if $machine =~ /^i[3456]86$/;

  return unless $SYS_prctl;

  my $PR_SET_PDEATHSIG = 1;   # at least it is on my machine

  syscall($SYS_prctl, $PR_SET_PDEATHSIG, $sig) >= 0 or die "prctl failed : $!";
}

1
