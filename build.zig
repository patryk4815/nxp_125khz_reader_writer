const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    _ = target;

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const firmware = mb.add_firmware(.{
        .name = "example1",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("examples/example1.zig"),
    });

    const nxp_mod = b.addModule("nxp_125khz_reader_writer", .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = "src/root.zig" },
        },
    });
    firmware.add_app_import("nxp_125khz_reader_writer", nxp_mod, .{ .depend_on_microzig = true });

    mb.install_firmware(firmware, .{ });
    mb.install_firmware(firmware, .{ .format = .elf });
}
