# ez_primes
Prime generation made easy! 

## Usage
To generate the first $n$ primes, simply do:
```
ez_primes n
```

## How does it compare to primesieve ?

Here are the results on my laptop:

|  n      | ez_primes | primesieve | delta  |
|---------|-----------|------------|--------|
|$10^6$   |   3.00ms  | 3.05ms     | -1.6%  |
|$10^7$   |   14.8ms  | 11.6ms     | +26.9% |
|$10^8$   |   105ms   | 89.6ms     | +16.7% |
|$10^9$   |   1030ms  | 873ms      | +17.7% |
|$10^{10}$|   10.9s   | 8.78s      | +23.9% |

`ez_primes` is 25% slower than `primesieve`. There are still many optimizations available that will help close this gap.
In particular, `ez_primes` does 6100% more cache misses and 110% more branch misses than primesieve.
I also noticed that `primesieve` uses a constant amount of memory while `ez_primes` does not. For example, at $n = 10^{10}$, `primesieve` uses 5.74MB and `ez_primes` uses 7.29**GB**. This results in a huge amount of cache misses and page faults, significantly slowing down the program.

## How does it work?
A segmented sieve of eratosthenes is used to sieve primes in chunks. The sieve is the same size as a cache line to reduce the amount of cache misses.

## Can I use it as a module?

Yes! simply call `ez_primes.computePrimes(io, gpa, from, to)` to begin generating primes.

## Planned speed-ups
Wheel sieving

Detecting L1 cache size at runtime

Not providing primes larger than $\sqrt(n)$ to `sieveBlock`

Reduce the amount of cache misses when recolting primes after sieving

## Planned features
Iterator API

C API

Python API
