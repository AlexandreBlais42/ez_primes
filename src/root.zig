const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const BitSet = @import("BitSet.zig");

test {
    _ = BitSet;
}

const usize_size = @bitSizeOf(usize);
const l1_cache_size = 128_000; // TODO: detect at runtime

pub const small_primes = blk: {
    const max = std.math.sqrt(l1_cache_size * 8);
    @setEvalBranchQuota(max * 10);

    var bit_set_buffer: [BitSet.numberOfMasksFromLength(max)]BitSet.MaskInt = undefined;
    var bit_set = BitSet{
        .bit_length = max,
        .masks = &bit_set_buffer,
    };
    sieveNaive(&bit_set);

    var buffer: [max / 2]usize = undefined;
    var primes_list = std.ArrayListUnmanaged(usize).initBuffer(&buffer);
    var primes_iterator = bit_set.iterator();
    while (primes_iterator.next()) |prime| {
        if (prime >= max) break;
        primes_list.appendAssumeCapacity(prime);
    }

    var primes: [primes_list.items.len]usize = undefined;
    @memcpy(&primes, primes_list.items);
    break :blk primes;
};

/// Returns an upper bound for the number of primes smaller than n.
pub fn primeCountUpperBound(n: usize) usize {
    // https://en.wikipedia.org/wiki/Prime-counting_function#Inequalities Pierre Dusart
    const n_f: f64 = @floatFromInt(n);
    const log_n = @log(n_f);
    var result: f64 = 1;

    const coefficients = [3]f64{ 7.59, 2, 1 };
    for (coefficients) |i| {
        result += i;
        result /= log_n;
    }

    result *= n / log_n;

    return @intFromFloat(@floor(result));
}

pub fn sieveNaive(bitset: *BitSet) void {
    const num_words = bitset.numberOfMasks();

    const mask = blk: {
        var result: usize = 0b10;
        while (true) {
            const new_result = (result << 2) | result;
            if (new_result == result) break :blk result;
            result = new_result;
        }
    };
    @memset(bitset.masks[0..num_words], mask);
    bitset.unset(1);
    bitset.set(2);
    for (3..bitset.bit_length) |i| {
        if (bitset.isSet(i)) {
            var j: usize = i * 3;
            while (j < bitset.bit_length) : (j += i * 2) {
                bitset.unset(j);
            }
        }
    }
}

threadlocal var sieveBuffer: [BitSet.numberOfMasksFromLength(l1_cache_size * 8)]BitSet.MaskInt align(64) = undefined;
pub fn sieveBlock(allocator: Allocator, known_primes: []const usize, offset: usize) Allocator.Error![]usize {
    var bit_set = BitSet.init(l1_cache_size * 8, &sieveBuffer);

    // TODO: Apply the right mask
    bit_set.setMasksTo(std.math.maxInt(BitSet.MaskInt));
    if (offset <= 0) bit_set.unset(0);
    if (offset <= 1) bit_set.unset(1 - offset);

    for (known_primes) |p| {
        // TODO: optimize this
        var i = offset;
        if (i % p != 0) {
            i += p;
            i -= i % p;
        }
        while (i < bit_set.bit_length + offset) : (i += p) {
            bit_set.unset(i - offset);
        }
    }

    const primes = try allocator.alloc(usize, bit_set.count());
    var it = bit_set.iterator();
    var primes_index: usize = 0;
    while (it.next()) |prime| {
        primes[primes_index] = prime;
        primes_index += 1;
    }

    return primes;
}
