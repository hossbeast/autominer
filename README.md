# autominer

autominer is a utility for cryptocurrency miners that selects the miner
and algorithm to mine based on past performance and current market rates
in order to achieve the optimal mining strategy.

# Getting Started

Create a config file and supply your btc address as username

````
cp config/sample ~/.autominer/config
vi ~/.autominer/config
````

Run the nicehash pricing aggregator
````
nicehash-aggregator
````

Run autominer
````
autominer mine
````

There is no benchmarking phase. Autominer continuously monitors the performance of your miners and
uses these data to determine which miner and algorithm to run. If a miner/algo combination has never
been run, autominer will choose to run it.

The first time you run autominer, you may choose to run quickly run every miner/algo combination to
save time

````
autominer mine --period 30 # switch every 30 seconds
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
