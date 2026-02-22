# ez_primes
Prime generation made easy! 

## Usage
To generate the first $n$ primes, simply do:
```
ez_primes n
```

## How does it work?
A segmented sieve of eratosthenes is used to sieve primes in chunks. The sieve is the same size as a cache line to reduce the amount of cache misses.
Simply call `ez_primes.computePrimes(io, gpa, from, to)` to begin sieving if you're using `ez_primes` as a module.

## Planned speed-ups
Adding a wheel
Detecting L1 cache size at runtime
Not providing primes larger than $\sqrt(n)$ to `sieveBlock`

## Planned features
Iterator API
C API
Python API
