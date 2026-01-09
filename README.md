# RP2350/RP2040 HITAG/RFID API

This API is intended to work primarily with **RP2350** (tested), and **RP2040** (untested).

It provides an interface for working with **RFID/HITAG read/write tags operating at 125 kHz**.

## Supported Chips

This library supports the following NXP chips:

- **NXP PCF7991**
- **NXP HTRC110**

The chip API is implemented based on publicly available documentation:

- [PCF7991AT Advanced Basestation IC](https://www.farnell.com/datasheets/2353677.pdf)
- [HTRC110 HITAG reader chip](https://www.nxp.com/docs/en/data-sheet/037031.pdf)
- Old docs: ["Read/Write Devices based on the HITAG Read/Write IC HTRC110" (Sep 1998)](https://www.ic72.com/pdf_file/9/155194.pdf)
- Latest docs: ["Read/write devices based on the HITAG read/write IC HTRC110" (Mar 2010)](https://www.nxp.com/docs/en/application-note/AN98080.pdf)

## Build your own PCB :)
Example schematics:
- https://github.com/ibexuk/C_RFID_125khz_Readers_HTRC110/blob/master/Schematics/htrc110_rfid_reader_driver_example_project_circuit.pdf
- https://github.com/kivijakola/hitager/wiki/Building-your-own-hitager-hardware

## Caveat

- Currently, only a **4 MHz XTAL** is supported due to a hardcoded value in the source code:  
  https://github.com/patryk4815/nxp_125khz_reader_writer/blob/main/src/root.zig#L423

- When designing your own PCB, special care must be taken when building the **antenna circuit**.  
  The capacitors and resistors must be properly selected and tuned to generate a **clean sinusoidal waveform at 125 kHz**, otherwise tag communication may be unreliable or fail completely.
![wave-length.png](imgs/wave-length.png)


## Installation / Usage

TBA. See the `./examples/` directory for working examples.

## Features
- Read and write HITAG/RFID tags
- Compatible with 125 kHz tags
- Works on RP2350 (tested) and RP2040 (untested)
- Supports multiple NXP chips


## 
RFID 125khz HITAG READER WRITER NXP PCF7991 NXP HTRC110 RP2350 RP2040 microzig
