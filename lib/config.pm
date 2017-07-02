#!/bin/env perl

package config;

use strict;
use warnings;

use subs 'die';
sub die { CORE::die(@_, "\n") } 

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = qw|configure config|;

use Getopt::Long qw|GetOptionsFromArray GetOptionsFromString :config pass_through no_ignore_case|;
use Data::Dumper;
use util;

sub apply_config_file
{
  my ($path, $optargs) = @_;

  open(FH, "<", $path) or die "open($path) : $!";
  my $text = '';
  while(<FH>)
  {
    chomp;
    s/#.*//g; # ignore comments
    $text .= " $_\n";
  }
  close FH;

  () = GetOptionsFromString($text, %$optargs);
}

sub configure
{
  my ($optargs, $opts) = @_;

  # base config file
  apply_config_file("$ENV{HOME}/.autominer/config", $optargs);

  # apply only the profile from the cmdline
  my %args = ( 'profile=s' => $$optargs{'profile=s'} );
  GetOptionsFromArray(\@ARGV, %args);

  # per-profile config file
  my $path = "$ENV{HOME}/.autominer/profile/$$opts{profile}/config";
  apply_config_file($path, $optargs) if -f $path;

  # apply cmdline
  GetOptionsFromArray(\@ARGV, %$optargs);

  if($$opts{verbose})
  {
    use Carp 'verbose';
    $SIG{__DIE__} = sub { Carp::confess(@_) };

    $::verbose = 1;
  }

  if(defined($$opts{cards}))
  {
    $$opts{"comma-cards"} = $$opts{cards};
    $$opts{"space-cards"} = join(" ", split(/,/, $$opts{cards}));
    delete $$opts{cards};
  }

  # leftovers
  die "unexpected arguments " . join(" ", @ARGV) if @ARGV;
}
