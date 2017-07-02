#!/bin/env perl

package util;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|run killfast curl filter pr_set_pdeathsig override_warn_and_die|;

use File::Temp;
use Fcntl;
use Fcntl 'SEEK_SET';
use POSIX;
use MIME::Base64;
use Data::Dumper;

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

  syscall($SYS_prctl, $PR_SET_PDEATHSIG, $sig) >= 0 or die $!;
}

sub curl
{
  my $url = shift;

  my($rh, $wh);
  pipe($rh, $wh) or die $!;
  my $pid = fork;
  if(!$pid)
  {
    close $rh;

    my $flags = fcntl $wh, F_GETFD, 0 or die $!;
    fcntl $wh, F_SETFD, $flags &= ~FD_CLOEXEC or die $!;

    my @cmd = (
        "curl"
      , $url
      , "-s"
      , "-o", "/dev/fd/" . fileno($wh)
    );

    exec { $cmd[0] } @cmd;
  }

  close $wh;
  wait or die "wait : $!";
  do { local $/ = undef ; <$rh> }
}

sub run
{
  my @cmd = @_;
  print(" > @cmd\n") if $::verbose;

  my($rh, $wh);
  pipe($rh, $wh) or die $!;
  my $pid = fork;
  if(!$pid)
  {
    close $rh;
    open(STDIN, "</dev/null");
    open(STDOUT, ">&=" . fileno($wh)) or die;
    chdir("/") or die;

    exec { $cmd[0] } @cmd;
  }

  close $wh;
  wait or die "wait : $!";
  my $output = do { local $/ = undef ; <$rh> };
  close $rh;

  $output;
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

1
