# ez_primes
Prime generation made easy! 

## Usage
To generate the first $n$ primes, simply do:
```
ez_primes n
```

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
