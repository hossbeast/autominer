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

package logger;

use strict;
use warnings;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT = (
    qw|logf|
);

sub logf
{
  my $fmt = shift;
  my @args = @_;

  printf("[%20s %6u] $fmt\n"
    , POSIX::strftime('%b %d %Y %T', localtime(time()))
    , $$
    , @args
  );
}
