const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const BitSet = @import("BitSet.zig");

test {
    _ = BitSet;
}

const usize_size = @bitSizeOf(usize);
const l1_cache_size = 128_000; // TODO: detect at runtime

const very_small_primes = [4]usize{ 2, 3, 5, 7 };
const very_small_primes_mask = blk: {
    @setEvalBranchQuota(10000);
    var prod: usize = 1;
    for (very_small_primes) |p| prod *= p;

    const max = prod + BitSet.mask_bit_size;
    var buffer: [BitSet.numberOfMasksFromLength(max)]BitSet.MaskInt = undefined;
    var bit_set = BitSet.init(max, &buffer);
    bit_set.setAll();

    for (very_small_primes) |p| {
        var i: usize = 0;
        while (i < max) : (i += p) {
            bit_set.unset(i);
        }
    }

    var masks: [prod]BitSet.MaskInt = undefined;
    for (0..prod) |i| {
        masks[i] = bit_set.getRelativeMask(i);
    }

    break :blk masks;
};

test very_small_primes_mask {
    const expected_first = 0b0010100000100000100010100010000010100000100010100010100000000010;
    try std.testing.expectEqual(expected_first, very_small_primes_mask[0]);

    const expected_index_100 = 0b1000001000001010000010001010000010001000001000000010001010001010;
    try std.testing.expectEqual(expected_index_100, very_small_primes_mask[100]);
}

const small_primes = blk: {
    const max = std.math.sqrt(l1_cache_size * 8);
    @setEvalBranchQuota(max * 15);

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

test small_primes {
    var count: u8 = 0;
    for (small_primes) |p| {
        if (p < 100) count += 1;
    }
    try std.testing.expectEqual(25, count);

    const biggest_small_prime = small_primes[small_primes.len - 1];
    try std.testing.expect(primeCountUpperBound(biggest_small_prime) >= small_primes.len);
}

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

    result += 1;
    result *= n_f / log_n;

    return @intFromFloat(@floor(result));
}

fn sieveNaive(bitset: *BitSet) void {
    const num_words = bitset.numberOfMasks();

    // TODO: Use the computed mask
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

/// returns primes p such that from <= p <= to
pub fn computePrimes(io: Io, gpa: Allocator, from: usize, to: usize) ![]usize {
    var futures_queue = try std.Deque(std.Io.Future(Allocator.Error![]usize)).initCapacity(gpa, 16);
    defer futures_queue.deinit(gpa);

    const maximum_number_of_primes = primeCountUpperBound(to);
    const primes_buffer = try gpa.alloc(usize, maximum_number_of_primes + sieve_size);
    defer gpa.free(primes_buffer);
    var primes = std.ArrayList(usize).initBuffer(primes_buffer);

    for (small_primes) |prime| {
        primes.appendAssumeCapacity(prime);
    }

    var biggest_prime: usize = primes.getLast();
    try futures_queue.pushBack(gpa, io.async(sieveBlock, .{ gpa, primes.items[very_small_primes.len..], 0 }));
    while (futures_queue.len > 0) {
        var fut = futures_queue.popFront().?;
        const new_primes = try fut.await(io);
        defer gpa.free(new_primes);

        // FIX: Page faults and cache misses
        for (new_primes) |prime| {
            primes.appendAssumeCapacity(prime);
        }
        const new_biggest_prime = primes.getLast();
        defer biggest_prime = new_biggest_prime;

        const lower = biggest_prime * biggest_prime / sieve_size;
        const upper = @min(new_biggest_prime * new_biggest_prime, to) / sieve_size;

        for (lower + 1..upper + 1) |i| {
            try futures_queue.pushBack(gpa, io.async(sieveBlock, .{ gpa, primes.items[very_small_primes.len..], i * sieve_size }));
        }
    }

    const compare = (struct {
        pub fn compare(a: usize, b: usize) std.math.Order {
            return std.math.order(a, b);
        }
    }).compare;
    const bottom_index = std.sort.lowerBound(usize, primes.items, from, compare);
    const upper_index = std.sort.upperBound(usize, primes.items, to, compare);

    return gpa.dupe(usize, primes.items[bottom_index..upper_index]);
}

test computePrimes {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    // https://en.wikipedia.org/wiki/Prime-counting_function#Table_of_%CF%80(x),_%E2%81%A0x/log_x_%E2%81%A0,_and_li(x)
    const known_pi_values = [_]struct { usize, usize }{
        .{ std.math.pow(usize, 10, 1), 4 },
        .{ std.math.pow(usize, 10, 2), 25 },
        .{ std.math.pow(usize, 10, 3), 168 },
        .{ std.math.pow(usize, 10, 4), 1229 },
        .{ std.math.pow(usize, 10, 5), 9592 },
        .{ std.math.pow(usize, 10, 6), 78498 },
    };

    for (known_pi_values) |values| {
        const n, const amount = values;
        const primes = try computePrimes(io, allocator, 0, n);
        defer allocator.free(primes);

        try std.testing.expectEqual(amount, primes.len);
    }
}

const sieve_size = l1_cache_size * 8;
threadlocal var sieve_buffer: [BitSet.numberOfMasksFromLength(sieve_size)]BitSet.MaskInt align(64) = undefined;
fn sieveBlock(gpa: Allocator, known_primes: []const usize, offset: usize) Allocator.Error![]usize {
    var bit_set = BitSet.init(l1_cache_size * 8, &sieve_buffer);

    // TODO: Evaluate if rearranging the masks to enable sequential access instead of having to do the modulo is worth it.
    for (0..sieve_buffer.len) |i| {
        bit_set.setMask(i, very_small_primes_mask[(i * BitSet.mask_bit_size + offset) % very_small_primes_mask.len]);
    }
    if (offset <= 0) bit_set.unset(0);
    if (offset <= 1) bit_set.unset(1 - offset);

    for (known_primes) |p| {
        var i = offset + p - 1;
        i /= p;
        i *= p;
        // i is now the smallest multiple of p greather than or equal to offset

        // TODO: Figure out our position on a wheel and start wheeling
        // TODO: inline the loop in some way?
        if (i % 2 != 1) i += p;
        while (i < bit_set.bit_length + offset) : (i += 2 * p) {
            bit_set.unset(i - offset);
        }
    }

    const primes = try gpa.alloc(usize, bit_set.count());
    errdefer unreachable;
    var it = bit_set.iterator();
    var primes_index: usize = 0;
    while (it.next()) |prime| {
        primes[primes_index] = prime + offset;
        primes_index += 1;
    }

    return primes;
}
