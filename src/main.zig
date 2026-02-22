const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ez_primes = @import("ez_primes");

pub fn main(init: std.process.Init) !void {
    var threaded_io = std.Io.Threaded.init(init.gpa, .{
        .environ = undefined, // Not needed
    });
    const io = threaded_io.io();

    _ = init.arena.allocator();
    const gpa = init.gpa;

    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);

    if (args.len != 2) {
        std.log.err("Format: {s} count", .{args[0]});
        return;
    }

    const count = std.fmt.parseInt(usize, args[1], 10) catch {
        std.log.err("Argument \"{s}\" is not a number", .{args[1]});
        return;
    };

    const primes = try ez_primes.computePrimes(io, gpa, 0, count);
    defer gpa.free(primes);

    var stdout_file = std.Io.File.stdout();
    const stdout_buffer = try gpa.alloc(u8, 1_000_000);
    defer gpa.free(stdout_buffer);
    var stdout_writer = stdout_file.writer(io, stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch unreachable;

    for (primes) |p| {
        try stdout.print("{d}\n", .{p});
    }
    try stdout.print("pi({d}) = {d}\n", .{ count, primes.len });
}
