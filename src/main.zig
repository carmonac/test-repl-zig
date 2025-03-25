const std = @import("std");
const Child = std.process.Child;

pub fn main() !void {
    // Uncomment this block to pass the first stage
    while (true) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("$ ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var it = std.mem.splitSequence(u8, user_input, " ");

        const command = it.next();

        if (std.mem.eql(u8, command.?, "exit")) {
            if (it.next()) |status_str| {
                if (std.fmt.parseInt(u8, status_str, 10)) |status| {
                    std.process.exit(status);
                } else |_| {
                    try stdout.print("exit: invalid status\n", .{});
                }
            } else {
                std.process.exit(0);
            }
            return;
        }

        if (std.mem.eql(u8, command.?, "")) {
            continue;
        }

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        var count: usize = 0;
        var temp_it = it;
        while (temp_it.next()) |_| {
            count += 1;
        }
        const args = try allocator.alloc([]const u8, count + 1);
        defer allocator.free(args);
        args[0] = command.?;
        for (args[1..]) |*arg| {
            arg.* = it.next().?;
        }

        var child = Child.init(args, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |e| {
            try stdout.print("{}\n", .{e});
            continue;
        };

        const stdoutCommand = try child.stdout.?.reader().readAllAlloc(allocator, 1024 * 1024);
        defer allocator.free(stdoutCommand);

        const term = child.wait() catch |e| {
            try stdout.print("{}\n", .{e});
            continue;
        };

        if (term == .Exited) {
            try stdout.print("{s}\n", .{stdoutCommand});
        } else {
            try stdout.print("{?s}: command not found\n", .{command});
        }
    }
}
