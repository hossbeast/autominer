# autominer

autominer is a cryptocurrency mining application that selects the market, pool, miner, and
algorithm to mine by predicting the profit that would be realized by mining many possibilities, and
choosing the one with the greatest profit. This strategy will be successful at maximizing profits to
the extent that the selection is broad and the predictions are accurate.

# Getting Started

Create a config file and supply some basic configuration.

````
# create a config for the default profile
# uncomment/specify all of the following
#  --history-dir
#  --cache-dir
#  --run-dir
#  --nh-address
#  --nicehash-eu, and/or --nicehash-usa
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

By default, autominer re-evaluates what to mine every 10 minutes.

The first time you run autominer, you may wish to run quickly through every miner/algo combination to
save time (though a longer benchmark period may be more accurate).

````
autominer mine --switching-period 300  # switch every 5 minutes
````

## Installing Dependencies

If autominer failed to run, you may need to install the following dependencies.

### Arch Linux

````
sudo pacman -S perl curl perl-json-xs
````

### Ubuntu

````
sudo apt-get install perl curl libjson-xs-perl
````

# Miners

autominer includes wrappers for the following miners.

* ccminer (https://github.com/tpruvot/ccminer)
* ccminer-cryptonight (https://github.com/KlausT/ccminer-cryptonight)
* ethminer (https://github.com/Genoil/cpp-ethereum)
* nheqminer_cuda (https://github.com/nicehash/nheqminer)
* sgminer (https://github.com/nicehash/sgminer)
* eqm (https://www.nicehash.com/tools/eqm_v1.0.4c_Linux_Ubuntu16.zip)

You need to obtain/install miners separately in order to use autominer.

# Markets

The following markets / mining services are supported.

### nicehash

nicehash regions are enabled separately.

For a given payout address, the nicehash api reports accepted speed and profitability merged, across
regions, and across workers. This means that you cannot reliably run multiple autominer processes
for the same nicehash payout address - they will interfere with one another. You must use separate
payout addresses.

There is no reason not to mine in all nicehash regions that you have reasonable network connectivity
to. Buyers see them as separate markets, so you'll get better rates if you enable selling in all of
them.

In order to mine in a nicehash region, you must run the nicehash pricing aggregator for that region.
autominer will start this process automatically for each region you enable nicehash mining in.

### miningpoolhub

pplns pool mining on miningpoolhub works, but should be considered experimental. autominer currently
assumes the actual profit of mining on an mph pool is equal to the predicted profit. In a future
update, autominer with gather the actual profit by querying the mph api.

miningpoolhub requires the --worker parameter to be specified.

In order to mine on mph, you must run the coinstats aggregator, and the miningpoolhub-aggregator.
autominer will start them automatically if they aren't already running.

# Profiles

You may wish to run multiple copies of autominer with different settings. For example, you may wish
to run one instance of autominer on a dedicated mining GPU, and run another instance of autominer on
a GPU which is disabled from time to time while using the GPU for something else.

In this configuration, you may also want to supply the --worker parameter separately for each
profile, so that you can distinguish the mining histories for each profile, with autominer-stats.

````
# create per-profile configs, set the --worker parameter
cp ~/.autominer/config ~/.autominer/profile/card-zero/config
vi ~/.autominer/profile/cardo-zero/config

cp ~/.autominer/config ~/.autominer/profile/card-one/config
vi ~/.autominer/profile/cardo-one/config
````

In addition, you may want to the various pricing aggregators separately from the autominer process,
so that they are not disturbed when you stop/start autominer.

````
autominer nicehash-aggregator --region usa
autominer nicehash-aggregator --region eu
autominer coinstats-aggregator
autominer miningpoolhub-aggregator
````

Finally, run autominer

````
autominer mine --profile card-zero
autominer mine --profile card-one
````

# Other Miners

To see a list of supported miners, look in the miners directory.

To configure another miner, you need to create a wrapper script for it at ````miners/autominer-$name````

The wrapper must have the following semantics, when invoked with a single argument, as follows:

* configured - if the miner is available, print "yes" on stdout
* algos - print a list of algorithms supported by the miner, one per line
* mine - exec into the actual miner
* perf - process output from the miner on stdin, and write perf records on stdout, one per line.

The format of the perf record is

````$time $speed $units h/s````

$time is the number of seconds since the program started

$hashes is a floating point number indicating the observed speed since the last record

$units is one of k|m|g|t|p

# Analysis

To view statistics for current market prices, run

````
autominer rates --market usa
````

To view statistics for historical performance, including mining selections, run

````
autominer stats
````

# Dependencies

* perl (http://www.perl.org)
* JSON::XS (http://search.cpan.org/~mlehmann/JSON-XS-3.03/XS.pm)
* curl (https://curl.haxx.se)

# Discuss

* bitcointalk thread: https://bitcointalk.org/index.php?topic=2023598.0
