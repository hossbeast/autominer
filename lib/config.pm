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
  my ($path, $optargs, $show_configuration) = @_;

  print("applying configuration from $path\n") if $show_configuration;

  open(FH, "<", $path) or die "open($path) : $!";
  my $text = '';
  while(<FH>)
  {
    chomp;
    s/#.*//g; # ignore comments
    $text .= " $_\n" if $_;
  }
  close FH;

  print("$text\n") if $show_configuration;

  () = GetOptionsFromString($text, %$optargs);
}

sub configure
{
  my ($optargs, $opts, %kw) = @_;

  my %args;

  # apply show-configuration from the cmdline
  my $show_configuration = 0;
  if(exists $$optargs{'show-configuration!'})
  {
    %args = ( 'show-configuration!' => $$optargs{'show-configuration!'} );
    GetOptionsFromArray(\@ARGV, %args);

    $show_configuration = $$opts{"show-configuration"};
  }

  # base config file
  apply_config_file("$ENV{HOME}/.autominer/config", $optargs, $show_configuration);

  # apply only the profile from the cmdline
  %args = ( 'profile=s' => $$optargs{'profile=s'} );
  GetOptionsFromArray(\@ARGV, %args);

  # per-profile config file
  if($$opts{profile})
  {
    my $path = "$ENV{HOME}/.autominer/profile/$$opts{profile}/config";
    if(-f $path)
    {
      apply_config_file($path, $optargs, $show_configuration) if -f $path;
    }
    elsif($show_configuration)
    {
      print("no configuration at $path\n");
    }
  }

  # apply cmdline
  if($show_configuration)
  {
    print("applying configuration from cmdline\n");
    print(join("\n", map { " $_" } @ARGV), "\n");
  }
  GetOptionsFromArray(\@ARGV, %$optargs);

  if($$opts{verbose})
  {
    use Carp 'verbose';
    $SIG{__DIE__} = \&Carp::confess;

    $::verbose = 1;
  }

  if(defined($$opts{cards}))
  {
    $$opts{"comma-cards"} = $$opts{cards};
    $$opts{"space-cards"} = join(" ", split(/,/, $$opts{cards}));
    delete $$opts{cards};
  }

  if($show_configuration)
  {
    print("effective configuration ", tojson($opts), "\n");
  }

  # leftovers
  die "unexpected arguments " . join(" ", @ARGV) if @ARGV;
}
