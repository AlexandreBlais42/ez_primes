const std = @import("std");
const Io = std.Io;

pub fn sieveNaive(bitset: *std.DynamicBitSetUnmanaged) void {
    const mask_size = @bitSizeOf(std.DynamicBitSetUnmanaged.MaskInt);
    const num_words = (bitset.bit_length + mask_size + 1) / mask_size;

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
    for (3..bitset.capacity()) |i| {
        if (bitset.isSet(i)) {
            var j: usize = i * 3;
            while (j < bitset.capacity()) : (j += i * 2) {
                bitset.unset(j);
            }
        }
    }
}
