const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const ez_primes = @import("ez_primes");
const clap = @import("clap");

pub fn main(init: std.process.Init) !void {
    var threaded_io = std.Io.Threaded.init(init.gpa, .{ .environ = init.minimal.environ });
    const io = threaded_io.io();

    const gpa = init.gpa;

    var stdout_file = std.Io.File.stdout();
    const stdout_buffer = try gpa.alloc(u8, 1_000_000);
    defer gpa.free(stdout_buffer);
    var stdout_writer = stdout_file.writer(io, stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch unreachable;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-p, --no-print         Don't print prime numbers
        \\<usize>...
        \\
    );

    var diagnostic = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{
        .diagnostic = &diagnostic,
        .allocator = gpa,
    }) catch |err| {
        try diagnostic.reportToFile(io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.@"0".len != 1) {
        try clap.helpToFile(io, .stderr(), clap.Help, &params, .{});
        return;
    }

    const count = res.positionals.@"0"[0];
    const primes = try ez_primes.computePrimes(io, gpa, 0, count);
    defer gpa.free(primes);

    if (res.args.@"no-print" == 0) {
        for (primes) |p| {
            try stdout.print("{d}\n", .{p});
        }
    }
    try stdout.print("π({d}) = {d}\n", .{ count, primes.len });
}
