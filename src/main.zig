const std = @import("std");
const Io = std.Io;
const ez_primes = @import("ez_primes");

const small_primes = blk: {
    const max = 1000;
    @setEvalBranchQuota(max * 100);
    const BitSet = std.DynamicBitSetUnmanaged;

    const mask_size = @bitSizeOf(BitSet.MaskInt);
    var bitset_buffer: [(max + mask_size - 1) / mask_size]BitSet.MaskInt = undefined;
    var bitset = BitSet{
        .bit_length = max,
        .masks = &bitset_buffer,
    };
    ez_primes.sieveNaive(&bitset);

    var buffer: [max / 2]usize = undefined;
    var primes_list = std.ArrayListUnmanaged(usize).initBuffer(&buffer);
    var primes_iterator = bitset.iterator(.{});
    while (primes_iterator.next()) |prime| {
        if (prime >= max) break;
        primes_list.appendAssumeCapacity(prime);
    }

    var primes: [primes_list.items.len]usize = undefined;
    @memcpy(&primes, primes_list.items);
    break :blk primes;
};

pub fn main(init: std.process.Init) !void {
    var threaded_io = std.Io.Threaded.init(init.gpa, .{
        .environ = undefined, // Not needed
    });
    const io = threaded_io.io();
    _ = io;

    std.debug.print("Small primes: {any}\n", .{small_primes});
}
