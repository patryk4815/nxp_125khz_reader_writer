const std = @import("std");
const microzig = @import("microzig");
const sampler = @import("sampler.zig");

const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const time = rp2xxx.time;

pub const ConfigPage0 = packed struct(u8) {
    // main low pass cutoff frequency
    // 0: fL = 3 kHz
    // 1: fL = 6 kHz
    FILTERL: enum(u1) {
        f3khz,
        f6khz,
    } = .f3khz,

    // main high pass cutoff frequency
    // 0: fH = 40 Hz
    // 1: fH = 160 Hz
    FILTERH: enum(u1) {
        f40hz,
        f160hz,
    } = .f40hz,

    // amplifier gain factor
    // 00 g = 100
    // 01 g = 200
    // 10 g = 500
    // 11 g = 1000
    GAIN: enum(u2) {
        g100,
        g200,
        g500,
        g1000,
    } = .g500,

    WriteN: ConfigPageWriteN = .{},
};

pub const ConfigPage1 = packed struct(u8) {
    // select power down mode
    // 0: idle mode
    // 1: power down
    PD_MODE: enum(u1) {
        idle,
        power,
    } = .idle,

    // power down mode enable
    // 0: device active
    // 1: device power down
    PD: enum(u1) {
        active,
        powerdown,
    } = .active,

    // data comparator hysteresis
    // 0: hysteresis OFF
    // 1: hysteresis ON
    HYSTERESIS: enum(u1) {
        off,
        on,
    } = .off,

    // disable coil driver
    // 0: coil driver active
    // 1: coil driver inactive
    TXDIS: enum(u1) {
        active,
        inactive,
    } = .active,

    WriteN: ConfigPageWriteN = .{},
};

pub const ConfigPage2 = packed struct(u8) {
    // facility to achieve fast setting times
    // see Table 13
    FREEZE0: u1 = 0,

    // facility to achieve fast setting times
    // see Table 13
    FREEZE1: u1 = 0,

    // store signal amplitude as reference for later amplitude comparison
    // see status bit AMPCOMP
    ACQAMP: u1 = 0,

    // reset threshold generation of digitizer
    THRESET: u1 = 0,

    Status: ConfigPageStatus = .{},
};

pub const ConfigPage3 = packed struct(u8) {
    // clock frequency
    // 00: 4 MHz, 01: 12 MHz
    // 10: 8 MHz, 11: 16 MHz
    FSEL: enum(u2) {
        f4mhz,
        f12mhz,
        f8mhz,
        f16mhz,
    } = .f4mhz,

    // disable smart comparator
    // 0: smart comparator = ON
    // 1: smart comparator = OFF
    DISSMARTCOMP: enum(u1) {
        on,
        off,
    } = .on,

    // disable low pass 1
    // 0: low pass = ON
    // 1: low pass = OFF
    DIPSL1: enum(u1) {
        on,
        off,
    } = .on,

    Status: ConfigPageStatus = .{},
};

// page: 0, 1
const ConfigPageWriteN = packed struct(u4) {
    N0: u1 = 0,
    N1: u1 = 0,
    N2: u1 = 0,
    N3: u1 = 0,
};

// page: 2,3
const ConfigPageStatus = packed struct(u4) {
    // antenna fail
    // 0: antenna ok
    // 1: antenna failure
    ANTFAIL: enum(u1) {
        ok,
        failure,
    } = .ok,

    // amplitude comparison
    // When ACQAMP is set, the actual amplitude of the data
    // signal is stored as reference. After resetting ACQAMP,
    // status bit AMPCOMP is set when the actual data signal
    // amplitude is higher than the stored reference.
    AMPCOMP: u1 = 0,

    _: u2 = 0,
};

pub fn bitDelay() void {
    // Delay to create serial interface bit time.
    // Requirement is not specified in the HTRC110 datasheet but >= 1uS is a
    // reliable value to use (Nop(); is a single cycle null instruction for the Microchip C18 compiler)
    time.sleep_us(2);
}

pub const ChipRaw = struct {
    SCLK: gpio.Pin, // SCLK
    DIN: gpio.Pin, // DIN (MOSI)
    DOUT: gpio.Pin,  // DOUT (MISO)

    // This command is used to read back the sampling time ts set with SET_SAMPLING_TIME.
    // The sampling time is coded binary in D5 to D0.
    pub fn GET_SAMPLING_TIME(self: ChipRaw) u6 {
        const cmd: u8 = 0b00000010;
        const out = self.send_data(u8, cmd, true);
        return @truncate(out);
    }

    // This command has three functions:
    // 1. Reading back the configuration parameters set by SET_CONFIG_PAGE command
    // 2. Reading back the transmit pulse width programmed with WRITE_TAG_N
    // 3. Reading the system status information
    // P1 and P0 select one of four configuration pages. The response (X3 X2 X1 X0 D3 D2 D1
    // D0) contains the contents of the selected configuration page in its lower nibble. For P = 0
    // or P = 1 the higher nibble reflects the current setting of N (the transmit pulse width). For
    // P = 2 or P = 3 the system status information is returned in the higher nibble.
    pub fn GET_CONFIG_PAGE(self: ChipRaw, comptime T: type) T {
        var page: u2 = 0;
        switch (T) {
            ConfigPage0 => page = 0,
            ConfigPage1 => page = 1,
            ConfigPage2 => page = 2,
            ConfigPage3 => page = 3,
            else => @compileError("Only ConfigPage0, ConfigPage1, ConfigPage2, or ConfigPage3 are allowed")
        }

        var cmd: u8 = 0b00000100;
        cmd |= ((page >> 1) & 1) << 1;
        cmd |= ((page >> 0) & 1) << 0;
        return @bitCast(self.send_data(u8, cmd, true));
    }

    // This command is used to set the amplifier and filter parameters (cutoff frequencies, gain
    // factors) and the different operation modes. P1 and P0 select one of four configuration
    // pages.
    pub fn SET_CONFIG_PAGE(self: ChipRaw, comptime T: type, data: T) void {
        var page: u2 = 0;
        switch (T) {
            ConfigPage0 => page = 0,
            ConfigPage1 => page = 1,
            ConfigPage2 => page = 2,
            ConfigPage3 => page = 3,
            else => @compileError("Only ConfigPage0, ConfigPage1, ConfigPage2, or ConfigPage3 are allowed")
        }

        var cmd: u8 = 0b01000000;
        cmd |= @as(u8, page) << 4;
        cmd |= @as(u8, @bitCast(data)) & 0b1111;
        _ = self.send_data(u8, cmd, false);
    }

    // This command specifies the demodulator sampling time ts. The sampling time is coded
    // binary in D5 to D0.
    pub fn SET_SAMPLING_TIME(self: ChipRaw, times: u6) void {
        var cmd: u8 = 0b10000000;
        cmd |= times;
        _ = self.send_data(u8, cmd, false);
    }

    // This command is used to read the antenna´s phase, which is measured at every carrier
    // cycle. The phase is coded binary in D5 to D0.
    pub fn READ_PHASE(self: ChipRaw) u6 {
        const cmd: u8 = 0b00001000;
        return @truncate(self.send_data(u8, cmd, true));
    }

    // This command is used to read the demodulated bit stream from a transponder: After the
    // assertion of the three command bits the HTRC110 instantaneously switches to
    // READ_TAG-mode and transmits the demodulated, filtered and digitized data from the
    // transponder. Data comes out and should be decoded by the microcontroller.
    // READ_TAG-mode is terminated by a low to high transition at SCLK.
    pub fn READ_TAG(self: ChipRaw) void {
        const cmd: u3 = 0b111;
        _ = self.send_data(u3, cmd, false);
    }

    // This command is used to write data to a transponder.
    // If N3 to N0 are set to zero, the signal from DIN is transparently switched to the drivers. A
    // high level at DIN corresponds to antenna drivers witched off, a low level corresponds to
    // antenna drivers switched on.
    // If any binary number between 1 and 1111 is loaded into N3 to N0 the drivers are switched
    // off at the next positive transition of DIN. This state is held for a time interval equal to N * T0
    // (T0 = 8 μs). This method relaxes the timing resolution requirements to the microcontroller
    // and to the software implementation while providing exact, selectable write pulse timing.
    // WRITE_TAG-mode is terminated immediately by a low to high transition at SCLK.
    pub fn WRITE_TAG_N(self: ChipRaw, timeout: u4) void {
        var cmd: u8 = 0b00010000;
        cmd |= timeout;
        _ = self.send_data(u8, cmd, false);
    }

    // This is the 3 bit short form of the previously described command WRITE_TAG_N. It allows
    // to switch into WRITE_TAG-mode with a minimum communication time.
    // The behaviour of the WRITE_TAG command is identical to WRITE_TAG_N with two
    // exceptions:
    // • WRITE_TAG-mode is entered after assertion of the 3rd command bit.
    // • No N parameter is specified with this command; instead the N value, which was
    // programmed with the most recent WRITE_TAG_N command, is used. If no
    // WRITE_TAG_N was issued so far, a default N = 0 (transparent mode) will be
    // assumed.
    pub fn WRITE_TAG(self: ChipRaw) void {
        // TODO:
        // For optimizing the WRITE-pulse positions (see section 10.2) the delay times
        // of 310 µs for FILTERL=0
        // and 175 µs for FILTERL=1 shall be considered.
        const cmd: u3 = 0b110;
        _ = self.send_data(u3, cmd, false);
    }

    pub fn initPins(self: ChipRaw) void {
        self.SCLK.set_direction(.out);
        self.SCLK.set_function(.sio);
        self.SCLK.set_pull(.down);

        self.DIN.set_direction(.out);
        self.DIN.set_function(.sio);
        self.DIN.set_pull(.down);

        self.DOUT.set_direction(.in);
        self.DOUT.set_pull(.up);
        self.DOUT.set_schmitt_trigger_enabled(true);
        self.DOUT.set_function(.sio);
    }

    // duration: ~2us
    pub fn terminate_mode(self: ChipRaw) void {
        self.SCLK.put(1);
        bitDelay();
        self.SCLK.put(0);
    }

    // duration: ~40us if get_response=false
    // duration: ~72us if get_response=true
    fn send_data(self: ChipRaw, comptime T: type, tx_data: T, get_response: bool) u8 {
        var rx_data: u8 = 0;

        // --- Inicjalizacja interfejsu ---
        self.SCLK.put(0);
        bitDelay();

        self.DIN.put(0);
        bitDelay();

        self.SCLK.put(1);
        bitDelay();

        self.DIN.put(1); // Inicjalizacja (DIN Low-to-High przy SCLK High)
        bitDelay();

        const bits = switch (T) {
            u8 => 8,
            u7 => 7,
            u6 => 6,
            u5 => 5,
            u4 => 4,
            u3 => 3,
            u2 => 2,
            u1 => 1,
            else => @compileError("Only u[8-1] are allowed")
        };

        inline for (0..bits) |i| {
            self.SCLK.put(0);
            bitDelay();

            if ((tx_data & ((1 << (bits-1)) >> i)) != 0) {
                self.DIN.put(1);
            }
            else {
                self.DIN.put(0);
            }

            self.SCLK.put(1);
            bitDelay();
        }
        self.DIN.put(0);

        if (get_response) {
            inline for (0..8) |i| {
                self.SCLK.put(0);
                bitDelay();

                self.SCLK.put(1);
                bitDelay();

                if (self.DOUT.read() != 0) {
                    rx_data |= (0x80 >> i);
                }
            }
        }

        self.SCLK.put(0);
        return rx_data;
    }
};

pub const ChipHelper = struct {
    chip_raw: ChipRaw,

    pub fn init(DIN: u9, DOUT: u9, SCLK: u9) ChipHelper {
        const c = ChipRaw{
            .DIN = gpio.num(DIN),
            .DOUT = gpio.num(DOUT),
            .SCLK = gpio.num(SCLK),
        };

        return ChipHelper{
            .chip_raw = c,
        };
    }

    pub fn INIT_PINS(self: @This()) void {
        time.sleep_ms(100);
        self.chip_raw.initPins();
        time.sleep_ms(100);
        sampler.init(self.chip_raw.DIN, self.chip_raw.DOUT);
    }

    pub fn SET_IDLE_ANTENA(self: @This()) void {
        // TODO: poprawic na zgodnie z dokumentacja

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage3, .{
            .DIPSL1 = .on,
            .DISSMARTCOMP = .on,
            // TODO: config cristal speed?
            .FSEL = .f4mhz,
        });

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage0, .{
            .FILTERL = .f6khz,  // main low pass cutoff frequency, fL = 6 kHz
            .FILTERH = .f160hz, //  main high pass cutoff frequency, fH = 160 Hz
            // TODO: config gain?
            .GAIN = .g100,  // amplifier gain factor, gain = 31.5
        });

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 1,
            .ACQAMP = 1,
            .FREEZE0 = 1,
            .FREEZE1 = 1,
        });

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage1, .{
            .PD_MODE = .idle,
            .PD = .powerdown,
            .HYSTERESIS = .off,
            .TXDIS = .inactive,
        });
    }

    pub fn SET_ACTIVE_ANTENA(self: @This()) void {
        // TODO: poprawic na zgodnie z dokumentacja

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage3, .{
            .DIPSL1 = .on,
            .DISSMARTCOMP = .on,
            // TODO: config cristal speed?
            .FSEL = .f4mhz,
        });

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage0, .{
            .FILTERL = .f6khz,  // main low pass cutoff frequency, fL = 6 kHz
            .FILTERH = .f160hz, //  main high pass cutoff frequency, fH = 160 Hz
            // TODO: config gain?
            .GAIN = .g100,  // amplifier gain factor, gain = 31.5
        });

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage1, .{
            .PD_MODE = .idle,
            .PD = .active,
            .HYSTERESIS = .off,
            .TXDIS = .active,
        });

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 1,
            .FREEZE0 = 1,
            .FREEZE1 = 1,
        });

        time.sleep_ms(4);

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 1,
            .FREEZE0 = 0,
            .FREEZE1 = 0,
        });

        time.sleep_ms(1);

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 0,
            .FREEZE0 = 0,
            .FREEZE1 = 0,
        });
    }

    pub fn IS_ANTENNA_FAIL(self: @This()) bool {
        const status = self.chip_raw.GET_CONFIG_PAGE(ConfigPage2);
        return status.Status.ANTFAIL == .failure;
    }

    pub fn SET_ANTENNA_OFFSET(self: @This()) !void {
        const RFID_T_OC = 0x3f;
        const t_m: u8 = self.chip_raw.READ_PHASE();
        const t_ant: u8 = (t_m * 2) + RFID_T_OC;
        const offset: u6 = @truncate(t_ant);

        self.chip_raw.SET_SAMPLING_TIME(offset);
        const check_offset = self.chip_raw.GET_SAMPLING_TIME();

        if(check_offset != offset) {
            return error.NotStored;
        }
    }

    // duration: ~350us until read will start
    pub fn READ(self: @This(), buf: []u1) void {
        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 1,
            .FREEZE0 = 1,
            .FREEZE1 = 1,
        });
        const timeTransferUs = 40;  // time how slow is SET_CONFIG_PAGE
        time.sleep_us(250 - timeTransferUs);

        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 0,
            .FREEZE0 = 0,
            .FREEZE1 = 0,
        });

        self.chip_raw.READ_TAG();
        sampler.read_data(self.chip_raw.DOUT, buf);
        self.chip_raw.terminate_mode();
    }

    // duration: ~60us until write will start
    pub fn WRITE(self: @This(), buf: []const u1) void {
        self.chip_raw.SET_CONFIG_PAGE(ConfigPage2, .{
            .THRESET = 1,
            .FREEZE0 = 0,
            .FREEZE1 = 1,
        });

        self.chip_raw.WRITE_TAG();
        sampler.write_data(self.chip_raw.DIN, buf);
        self.chip_raw.terminate_mode();
    }
};
