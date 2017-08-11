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

package util;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|override_warn_and_die lock_obtain|
  , qw|mkdirp symlinkf|
  , qw|max min|
  , qw|durationstring|
  , qw|format_usd tojson|
  , qw|variance average variance2|
  , qw|try|
);

use File::Temp;
use Errno ':POSIX';
use Fcntl;
use Fcntl 'SEEK_SET';
use POSIX;
use MIME::Base64;
use Data::Dumper;
use Scalar::Util;
use JSON::XS;
use B;

use xlinux;
use logger;

sub override_warn_and_die
{
  $SIG{__WARN__} = sub { die @_ };
  $SIG{__DIE__} = sub {
    die @_ if $^S;
    die @_ unless $_[0] =~ /(.*) at .* line.*$/m;
    die "$1\n"
  };
}

sub try(&@)
{
  my $code = \&{shift @_};

  my $r = eval { $code->() };
  return ($@, undef) if $@;
  return (undef, $r)
}

sub _try_obtain
{
  my $path = shift;

  # create the pidfile
  my $fd = uxopen($path, O_CREAT | O_WRONLY | O_EXCL);

  # success ; record our pid in the file
  if($fd >= 0)
  {
    POSIX::write($fd, "$$\n", length("$$\n"));
    POSIX::close($fd);
    return 0;
  }

  # failure ; read the pid from the file
  open(my $fh, "<$path") or die "open($path) : $!";
  my $pid = <$fh>;
  close $fh;

  chomp $pid if $pid;
  $pid = int $pid if $pid;
  $pid
}

# fatal obtain a lock by creating the specified file
sub lock_obtain
{
  my $path = shift;

  while(1)
  {
    my $pid = _try_obtain($path);

    # lock successfully obtained
    last if $pid == 0;

    # lock holder is still running
    return $pid if kill 0, $pid;

    # forcibly release the lock
    xunlink($path);
  }

  return 0;
}

# fatal mkdir but only fail when errno != EEXIST
sub mkdirp
{
  my $path = shift;

  my $pfx = '/' if substr($path, 0, 1) eq '/';
  my $s = '';
  for my $part (split(/\/+/, $path))
  {
    next unless $part;
    $s .= "/" if $s;
    $s .= $part;
    uxmkdir("/$s") if $pfx;
    uxmkdir($s) if not $pfx;
  }
}

# rm linkpath (but dont fail if linkpath doesnt exist), then fatal symlink(target, linkpath)
sub symlinkf
{
  my ($target, $linkpath) = @_;

  uxunlink($linkpath);
  symlink($target, $linkpath) or die("symlink($target, $linkpath) : $!");
}

sub max
{
  ($_[0], $_[1])[$_[0] < $_[1]]
}

sub min
{
  ($_[0], $_[1])[$_[0] > $_[1]]
}

sub durationstring
{
  my $x = shift;
  $x = int($x);

  my $s = '';
  my $days = int($x / (60 * 60 * 24));
  $s .= "$days days " if $days;
  $x -= ($days * (60 * 60 * 24));

  my $hours = int($x / (60 * 60));
  $s .= "$hours hours " if $hours;
  $x -= ($hours * (60 * 60));

  my $minutes = int($x / (60));
  $s .= "$minutes minutes " if $minutes;
  $x -= ($minutes * (60));

  $s .= "$x seconds " if $x;

  $s = substr($s, 0, -1) if $s;
  $s;
}

sub format_usd
{
  my $x = shift;
  my $in_x = $x;

  my @p;
  while(int($x) > 0)
  {
    my $n = $x / 1000;
    push @p, sprintf("%03d", $x % 1000) if int($n);
    push @p, sprintf("%d", $x % 1000) unless int($n);
    $x = $n;
  }

  return '$' . join(",", reverse @p) if @p;
  return '$0';
}

sub variance2
{
  my ($start, $end) = @_;

  return 1 if !$start;

  $end / $start
}

sub variance
{
  my ($start, $end) = @_;

  return 1 if !$start;

  ($end - $start) / $start
}

sub average
{
  return 0 if $#_ == -1;

  my $total = 0;
  map { $total += $_ } @_;
  return $total / ($#_ + 1);
}

sub rest_prep
{
  my ($url, %params) = @_;

  return {
      url => $url
    , params => \%params
    , sleep => -1
  };
}

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

#
# SUMMARY - tojson
#  render a structure to json, like encode_json, but without exponential notation
#
# PARAMETERS
#  o       - object to render
#
# internal  parameters
#  k       - key
#  v       - value
#  lvl     - number of aggregates descended to this point
#  pos     - position within the parent aggregate
#  aligned - whether leading whitespace has already been emitted
#
sub tojson
{
  my ($o, $k, $v, $lvl, $pos, $aligned) = @_;

  $lvl = 0 if not defined $lvl;
  $pos = -1 if not defined $pos;

  my $j = '';
  unless($aligned)
  {
    $j .= '    ' x ($lvl - 1) if $lvl;
    $j .= '  , ' if $pos > 0;
    $j .= '    ' if $pos == 0;
  }

  my $ref = Scalar::Util::reftype($o);
  if($k)
  {
    $j .= '"' . $k . '" : ';
    $j .= tojson($v, undef, undef, $lvl, $pos, 1);
  }
  elsif($ref and $ref eq "HASH")
  {
    $j .= '{';
    my @keys = sort keys %$o;
    for(my $x = 0; $x <= $#keys; $x++)
    {
      $j .= "\n";
      $j .= tojson(undef, $keys[$x], $$o{$keys[$x]}, $lvl + 1, $x);
    }
    $j .= "\n";
    $j .= '    ' x ($lvl - 1) if $lvl;
    $j .= '    ' if $pos >= 0;
    $j .= '}';
  }
  elsif($ref and $ref eq "ARRAY")
  {
    $j .= '[';
    for(my $x = 0; $x <= $#$o; $x++)
    {
      $j .= "\n";
      $j .= tojson($$o[$x], undef, undef, $lvl + 1, $x);
    }

    $j .= "\n";
    $j .= '    ' x ($lvl - 1) if $lvl;
    $j .= '    ' if $pos >= 0;
    $j .= ']';
  }
  elsif(not $ref and (B::svref_2object(\$o)->FLAGS & B::SVp_POK))
  {
    $j .= '"' . $o . '"';
  }
  elsif(not $ref)
  {
    if(not defined $o)
    {
      $j .= "null";
    }
    elsif($o =~ /\..+/)
    {
      $j .= sprintf("%18.16f", $o);
    }
    else
    {
      $j .= $o;
    }
  }

  # some blessed perl bs
  else
  {
    $j .= "null";
  }

  $j
}

1
