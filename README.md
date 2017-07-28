# autominer

autominer is a utility for cryptocurrency miners that selects the miner
and algorithm to mine based on past performance and current market rates
in order to achieve the optimal mining strategy.

# Installing

Install perl and curl if necessary (these come standard with every linux distro).

Install the perl module JSON::XS.

## Arch Linux

````
sudo pacman -S perl-json-xs
````

## Ubuntu

````
sudo apt-get install libjson-xs-perl
````

The autominer program expects to be executed from directory structure in this repository.

# Getting Started

Create a config file and supply your btc address as username. You must also
minimally specify which nicehash region(s) to mine in.

````
# create the config for the default profile
#  set --payout-address
#  set --nicehash-eu, and/or --nicehash-usa
cp config/sample ~/.autominer/config
vi ~/.autominer/config
````

Run autominer
````
autominer mine
````

There is no benchmarking phase. Autominer continuously monitors the performance of your miners and
uses these data to determine which miner and algorithm to run. If a miner/algo combination has never
been run, autominer will choose to run it.

By default, autominer re-evaluates what to mine every 60 seconds.

The first time you run autominer, you may choose to run quickly run every miner/algo combination to
save time (though a longer benchmark period will be more accurate).

````
autominer mine --period 30  # switch every 30 seconds
````

# Profiles

You may wish to run multiple copies of autominer with different settings. For
example, you may wish to run one instance of autominer on a dedicated mining
GPU, and run another instance of autominer on a GPU which is disabled from time
to time while using the GPU for something else.

In this configuration, you may also want to supply the --worker parameter
separately for each profile, so that you can distinguish the mining rewards for
each card.

````
# create per-profile configs, set the --worker parameter
cp ~/.autominer/config ~/.autominer/profile/card-zero/config
vi ~/.autominer/profile/cardo-zero/config

cp ~/.autominer/config ~/.autominer/profile/card-one/config
vi ~/.autominer/profile/cardo-one/config
````

In addition, you may want to run the pricing aggregator separately from the
autominer process, so that it is not disturbed when you stop/start autominer.

If you don't run it separately, autominer-mine will run nicehash-aggregator for
each region you're mining in, but it will be stopped when autominer-mine
terminates.

````
nicehash-aggregator --region usa
nicehash-aggregator --region eu
````

Finally, run autominer

````
autominer mine --profile card-zero
autominer mine --profile card-one
````

# Miners

To see a list of supported miners, look in the miners directory.

To configure another miner, you need to create a wrapper script for it at ````miners/autominer-$name````

The wrapper must have the following semantics, when invoked with a single argument, as follows:

* configured - if the miner is available, print "yes" on stdout
* algos - print a list of algorithms supported by the miner, one per line
* mine - exec into the actual miner
* perf - process output from the miner on stdin, and write perf records on stdout, one per line.

The format of the perf record is

````$time $hashes $units h/s````

$time is the number of seconds since the program started

$hashes is a floating point number

$units is one of k|m|g|t|p

# Dependencies

* perl (http://www.perl.org)
* JSON::XS (http://search.cpan.org/~mlehmann/JSON-XS-3.03/XS.pm)
* curl (https://curl.haxx.se)
