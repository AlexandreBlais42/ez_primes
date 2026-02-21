const std = @import("std");
const Allocator = std.mem.Allocator;
const BitSet = @This();

pub const MaskInt = usize;
pub const mask_byte_size = @sizeOf(MaskInt);
pub const mask_bit_size = @bitSizeOf(MaskInt);

const full_mask: MaskInt = std.math.maxInt(MaskInt);

/// The integer type used to shift a mask in this bit set
pub const ShiftInt = std.math.Log2Int(MaskInt);

/// The number of valid items in this bit set
bit_length: usize = 0,

/// The bit masks, ordered with lower indices first.
/// Padding bits at the end must be zeroed.
masks: [*]MaskInt,

pub fn numberOfMasks(bit_set: BitSet) usize {
    return numberOfMasksFromLength(bit_set.bit_length);
}

pub fn numberOfMasksFromLength(bit_length: usize) usize {
    return (bit_length - 1 + mask_bit_size) / mask_bit_size;
}

pub fn setMask(bit_set: BitSet, index: usize, data: MaskInt) void {
    bit_set.masks[index] = data;
}

pub fn setAll(bit_set: BitSet) void {
    bit_set.setMasksTo(full_mask);
}

pub fn unsetAll(bit_set: BitSet) void {
    bit_set.setMasksTo(0);
}

/// Returns a mask containing bits [index .. index+mask_bit_size - 1]
pub fn getRelativeMask(bit_set: BitSet, index: usize) MaskInt {
    const mask_index = indexToMaskIndex(index);
    const bit_index = indexToBitIndex(index);

    var mask: MaskInt = 0;
    if (bit_set.numberOfMasks() > mask_index) {
        mask |= bit_set.masks[mask_index] >> @intCast(bit_index);
        if (bit_set.numberOfMasks() > mask_index + 1 and bit_index != 0) {
            mask |= bit_set.masks[mask_index + 1] << @bitCast(0 -% bit_index);
        }
    }

    return mask;
}

pub fn getMasks(bit_set: BitSet) []MaskInt {
    return bit_set.masks[0..bit_set.numberOfMasks()];
}

pub fn init(number_of_bits: usize, masks: []MaskInt) BitSet {
    return BitSet{
        .bit_length = number_of_bits,
        .masks = masks.ptr,
    };
}

pub fn initAllocator(gpa: Allocator, number_of_bits: usize) !BitSet {
    const slice = try gpa.alloc(MaskInt, numberOfMasksFromLength(number_of_bits));
    return BitSet{
        .bit_length = number_of_bits,
        .masks = slice.ptr,
    };
}

pub fn deinit(bit_set: BitSet, gpa: Allocator) void {
    gpa.free(bit_set.getMasks());
}

pub fn setMasksTo(bit_set: BitSet, value: MaskInt) void {
    @memset(bit_set.masks[0..bit_set.numberOfMasks()], value);
}

pub fn count(bit_set: BitSet) usize {
    bit_set.unsetUnusedBits();

    var result: usize = 0;
    for (bit_set.getMasks()) |mask| {
        result += @popCount(mask);
    }
    return result;
}

fn indexToMaskIndex(index: usize) usize {
    return index / mask_bit_size;
}

fn indexToBitIndex(index: usize) ShiftInt {
    return @intCast(index % mask_bit_size);
}

fn indexToBitMask(index: usize) MaskInt {
    return @as(MaskInt, 1) << indexToBitIndex(index);
}

pub fn set(bit_set: BitSet, index: usize) void {
    bit_set.masks[indexToMaskIndex(index)] |= indexToBitMask(index);
}

pub fn unset(bit_set: BitSet, index: usize) void {
    bit_set.masks[indexToMaskIndex(index)] &= ~indexToBitMask(index);
}

pub fn toggle(bit_set: BitSet, index: usize) void {
    bit_set.masks[indexToMaskIndex(index)] ^= ~indexToBitMask(index);
}

pub fn isSet(bit_set: BitSet, index: usize) bool {
    return bit_set.masks[indexToMaskIndex(index)] & indexToBitMask(index) != 0;
}

pub fn iterator(bit_set: BitSet) Iterator {
    return Iterator.init(bit_set);
}

pub fn unsetUnusedBits(bit_set: BitSet) void {
    const unused_bits = 64 - bit_set.bit_length % mask_bit_size;
    if (unused_bits != 64) {
        bit_set.masks[bit_set.numberOfMasks() - 1] &= full_mask >> @intCast(unused_bits);
    }
}

test initAllocator {
    const gpa = std.testing.allocator;
    const bit_set = try initAllocator(gpa, 500);
    defer bit_set.deinit(gpa);
}

test setMasksTo {
    const length = 500;
    var buffer: [numberOfMasksFromLength(length)]MaskInt = undefined;
    var bit_set = init(length, &buffer);

    bit_set.setMasksTo(std.math.maxInt(MaskInt));
    for (bit_set.getMasks()) |mask| {
        try std.testing.expectEqual(mask, std.math.maxInt(MaskInt));
    }

    bit_set.setMasksTo(0);
    for (bit_set.getMasks()) |mask| {
        try std.testing.expectEqual(mask, 0);
    }
}

test getRelativeMask {
    const length = 200;
    const gpa = std.testing.allocator;
    const bit_set = try initAllocator(gpa, length);
    defer bit_set.deinit(gpa);

    bit_set.setMasksTo(0);
    bit_set.set(32);
    bit_set.set(90);

    const entire_mask: u256 = (1 << 32) + (1 << 90);

    for (0..length) |i| {
        const expected_mask: MaskInt = @truncate(entire_mask >> @intCast(i));
        try std.testing.expectEqual(expected_mask, bit_set.getRelativeMask(i));
    }
}

test set {
    const gpa = std.testing.allocator;
    const bit_set = try initAllocator(gpa, 200);
    defer bit_set.deinit(gpa);

    bit_set.setMasksTo(0);
    const bits = [_]usize{ 0, 1, 4, 5, 6, 18, 32, 33, 63, 64, 65, 66, 78, 80, 90, 199 };
    for (&bits) |bit| {
        try std.testing.expect(bit_set.isSet(bit) == false);
        bit_set.set(bit);
        try std.testing.expect(bit_set.isSet(bit) == true);
    }
}

const Iterator = struct {
    bit_set: BitSet,
    current_index: usize = 0,
    current_mask: usize,

    pub fn init(bit_set: BitSet) Iterator {
        bit_set.unsetUnusedBits();
        return Iterator{
            .bit_set = bit_set,
            .current_mask = bit_set.masks[0],
        };
    }

    pub fn next(it: *Iterator) ?usize {
        while (it.current_mask == 0) {
            it.current_index += 1;
            if (it.current_index >= it.bit_set.numberOfMasks()) {
                break;
            }
            it.current_mask = it.bit_set.masks[it.current_index];
        }
        if (it.current_mask != 0) {
            const index = @ctz(it.current_mask);
            it.current_mask ^= indexToBitMask(index);
            return it.current_index * mask_bit_size + index;
        }
        return null;
    }
};

test Iterator {
    const gpa = std.testing.allocator;
    const bit_set = try initAllocator(gpa, 1000);
    defer bit_set.deinit(gpa);

    bit_set.setMasksTo(0);
    const set_bits = [_]usize{ 0, 63, 100, 101, 102, 103, 104, 105, 127, 128, 500, 504, 508, 512, 516 };
    for (set_bits) |i| {
        bit_set.set(i);
    }

    var it = bit_set.iterator();
    var index: usize = 0;
    while (it.next()) |i| {
        try std.testing.expectEqual(set_bits[index], i);
        index += 1;
    }
    try std.testing.expectEqual(set_bits.len, index);
}
