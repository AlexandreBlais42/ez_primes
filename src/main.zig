const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ez_primes = @import("ez_primes");

pub fn main(init: std.process.Init) !void {
    var threaded_io = std.Io.Threaded.init(init.gpa, .{
        .environ = undefined, // Not needed
    });
    const io = threaded_io.io();

    // std.debug.print("Small primes: {any}\n", .{ez_primes.small_primes});
    const arena = init.arena.allocator();
    const gpa = init.gpa;

    var futures_queue = try std.Deque(std.Io.Future(Allocator.Error![]usize)).initCapacity(gpa, 16);
    defer futures_queue.deinit(gpa);

    try futures_queue.pushBack(gpa, io.async(ez_primes.sieveBlock, .{ arena, ez_primes.small_primes[4..], 0 }));
    while (futures_queue.len > 0) {
        var fut = futures_queue.popFront().?;
        const primes = try fut.await(io);

        var count: u64 = ez_primes.small_primes.len;
        for (primes) |p| {
            if (p < 1000000) count += 1;
        }
        std.debug.print("count: {d}\n", .{count});
    }
}
