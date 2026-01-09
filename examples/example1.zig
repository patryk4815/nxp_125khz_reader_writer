const std = @import("std");
const nxp_125khz_reader_writer = @import("nxp_125khz_reader_writer");

pub fn panic(message: []const u8, stack: ?*std.builtin.StackTrace, size: ?usize) noreturn {
    // _ = message;
    _ = stack;
    _ = size;
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub fn main() !void {
    const DIN = 4; // DIN (MOSI)
    const DOUT = 3; // DOUT (MISO)
    const SCLK = 2; // SCLK

    const c = nxp_125khz_reader_writer.ChipHelper.init(DIN, DOUT, SCLK);
    c.INIT_PINS();
    c.SET_IDLE_ANTENA();
    c.SET_ACTIVE_ANTENA();

    if (c.IS_ANTENNA_FAIL()) {
        @panic("antenna failure...");
    }
    c.SET_ANTENNA_OFFSET() catch unreachable;

    const write_data = [_]u1{1,1,1,1,1,0,0,0,0};
    c.WRITE(write_data[0..]);

    var read_data: [100]u1 = @splat(0);
    c.READ(read_data[0..]);
}
