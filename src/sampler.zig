const std = @import("std");
const microzig = @import("microzig");

const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const time = rp2xxx.time;

const Pio = rp2xxx.pio.Pio;
const StateMachine = rp2xxx.pio.StateMachine;

const any_rx = blk: {
    @setEvalBranchQuota(6000);
    break :blk rp2xxx.pio.assemble(
        \\.program any_rx
        \\
        \\.wrap_target
        \\    in pins, 1
        \\    push block
        \\.wrap
    , .{}).get_program_by_name("any_rx");
};

const ask_tx = blk: {
    @setEvalBranchQuota(9000);
    break :blk rp2xxx.pio.assemble(
        \\.program ask_tx
        \\
        \\pull block           ; pobierz licznik -> OSR
        \\mov x, osr           ; X = liczba cykli do wysłania
        \\
        \\loop:
        \\    pull block        ; pobierz kolejny bit
        \\    out pins, 1       ; ustaw pin wg bit0
        \\    jmp x-- loop      ; zmniejsz X, jeśli X!=0 -> loop
        \\end:
        \\    set x, 0xF        ; EOF marker
        \\    mov isr, x
        \\    push block
        \\    jmp end
        , .{}).get_program_by_name("ask_tx");
};

const pio_tx = rp2xxx.pio.num(0);
const pio_rx = rp2xxx.pio.num(1);

pub fn init(DIN: gpio.Pin, DOUT: gpio.Pin) void {
    init_rx(DOUT);
    init_tx(DIN);
}

fn init_rx(pin: gpio.Pin) void {
    const sm: StateMachine = .sm0;
    const freq: f32 = @floatFromInt(rp2xxx.clock_config.sys.?.frequency());
    const div = freq / (125_000.0 * 2.0);  // aktualnie 2cycles = 1bit = 8us

    pio_rx.sm_set_pindir(sm, to_pio_pin_num(pin), 1, .in);
    // jak tego nie ustamy, to przy wlaczniu PIO, ten pin bedzie floating i bedzie mial dziwny voltage
    pio_rx.sm_set_pin(sm, to_pio_pin_num(pin), 1, 1); // default high

    pio_rx.sm_load_and_start_program(sm, any_rx, .{
        .clkdiv = rp2xxx.pio.ClkDivOptions.from_float(div),
        .shift = .{
            .in_shiftdir = .right,
            .autopush = false,
            .join_rx = true,      // fifo queue_len=8
            .push_threshold = 0,  // 0 means full 32-bits
        },
        .pin_mappings = .{
            .in_base = to_pio_pin_num(pin),
            .set = .{
                .base = to_pio_pin_num(pin),
                .count = 1,
            },
        },
    }) catch unreachable;
}

fn start_rx() void {
    const sm: StateMachine = .sm0;
    pio_rx.sm_set_enabled(sm, false);
    pio_rx.sm_clear_fifos(sm);
    pio_rx.sm_clear_debug(sm);
    pio_rx.sm_restart(sm);
    pio_rx.sm_clkdiv_restart(sm);

    pio_rx.sm_exec(sm, rp2xxx.pio.Instruction{
        .tag = .jmp,

        .delay_side_set = 0,
        .payload = .{
            .jmp = .{
                .address = 0,
                .condition = .always,
            },
        },
    });
}

fn init_tx(pin: gpio.Pin) void {
    const sm: StateMachine = .sm1;
    const freq: f32 = @floatFromInt(rp2xxx.clock_config.sys.?.frequency());
    const div = freq / (125_000.0 * 3.0);  // aktualnie 3cycles = 1bit = 8us

    pio_tx.sm_set_pindir(sm, to_pio_pin_num(pin), 1, .out);
    pio_tx.sm_set_pin(sm, to_pio_pin_num(pin), 1, 0);

    pio_tx.sm_load_and_start_program(sm, ask_tx, .{
        .clkdiv = rp2xxx.pio.ClkDivOptions.from_float(div),
        .shift = .{
            .out_shiftdir = .right,
            .autopull = false,
            .autopush = false,
            .pull_threshold = 0,  // 0 means full 32-bits
            .join_tx = false,     // fifo queue_len=4
        },
        .pin_mappings = .{
            .out = .{
                .base = to_pio_pin_num(pin),
                .count = 1,
            },
        },
    }) catch unreachable;
}

fn start_tx() void {
    const sm: StateMachine = .sm1;
    pio_tx.sm_set_enabled(sm, false);
    pio_tx.sm_clear_fifos(sm);
    pio_tx.sm_clear_debug(sm);
    pio_tx.sm_restart(sm);
    pio_tx.sm_clkdiv_restart(sm);

    pio_tx.sm_exec(sm, rp2xxx.pio.Instruction{
        .tag = .jmp,

        .delay_side_set = 0,
        .payload = .{
            .jmp = .{
                .address = 0,
                .condition = .always,
            },
        },
    });
}

pub fn read_data(pin: gpio.Pin, buf: []u1) void {
    // TODO: to moze dzialac na DMA kiedys

    if (buf.len < 1) {
        return;
    }

    const sm: StateMachine = .sm0;
    const old_value1 = pin.get_pads_reg().read();
    const old_value2 = pin.get_regs().ctrl.read();
    defer pin.get_pads_reg().write(old_value1);
    defer pin.get_regs().ctrl.write(old_value2);

    start_rx();
    pio_rx.gpio_init(pin);
    pio_rx.sm_set_enabled(sm, true);
    defer pio_rx.sm_set_enabled(sm, false);

    var i: usize = 0;

    while (i < buf.len) {
        const val = pio_rx.sm_blocking_read(sm);
        // musi byc odwrocony sygnal, bo tak przychodzi sygnal odwrócony
        // wiec go odwracamy do zgodnego z dokumentacja

        if(val > 1) {
            buf[i] = 0;
        } else {
            buf[i] = 1;
        }
        i += 1;
    }
}

pub fn write_data(pin: gpio.Pin, buf: []const u1) void {
    // TODO: to moze dzialac na DMA kiedys

    if (buf.len < 1) {
        return;
    }

    const sm: StateMachine = .sm1;
    const old_value1 = pin.get_pads_reg().read();
    const old_value2 = pin.get_regs().ctrl.read();
    defer pin.get_pads_reg().write(old_value1);
    defer pin.get_regs().ctrl.write(old_value2);

    start_tx();
    pio_tx.gpio_init(pin);
    pio_tx.sm_set_enabled(sm, true);
    defer pio_tx.sm_set_enabled(sm, false);

    pio_tx.sm_blocking_write(sm, buf.len - 1);
    for(buf) |bit| {
        pio_tx.sm_blocking_write(sm, bit);
    }
    const eof = pio_tx.sm_blocking_read(sm);
    if (eof != 0xf) {
        @panic("pio invalid response, never should happen");
    }
}

fn to_pio_pin_num(pin: gpio.Pin) u5 {
    return @truncate(@intFromEnum(pin));
}
