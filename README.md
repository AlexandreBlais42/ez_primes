# ez_primes
Prime generation made easy! 

## Usage
To generate the first $n$ primes, simply do:
```
ez_primes n
```

## How does it compare to primesieve ?

Here are the results on my laptop:

|  n   | ez_primes | primesieve | delta  |
+------+-----------+------------+--------+
|$10^6$|   3.03ms  | 3.06ms     | -1.1%  |
|$10^6$|   16.3ms  | 11.7ms     | +38.8% |
|$10^8$|   120ms   | 89.3ms     | +34.5% |
|$10^9$|   1200ms  | 872ms      | +37.0% |
|$10^9$|   12.5s   | 8.83s      | +41.8% |

`ez_primes` is 40% slower than `primesieve`. There are still many optimizations available that will help close this gap.
In particular, `ez_primes` does 2700% more cache misses and 260% more branch misses than primesieve.
I also noticed that `primesieve` uses a constant amount of memory while `ez_primes` does not. For example, at $n = 10^9$, `primesieve` uses 5.74MB and `ez_primes` uses `7.29**GB**`. This results in a huge amount of cache misses and page faults, significantly slowing down the program.

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
