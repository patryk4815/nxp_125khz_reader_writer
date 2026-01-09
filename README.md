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

## Requirements

This library requires:

- [microzig](https://pypi.org/project/microzig/) version **0.15.0**

## Installation / Usage

TBA. See the `./examples/` directory for working examples.

## Features
- Read and write HITAG/RFID tags
- Compatible with 125 kHz tags
- Works on RP2350 (tested) and RP2040 (untested)
- Supports multiple NXP chips


## 
RFID 125khz HITAG READER WRITER NXP PCF7991 NXP HTRC110 RP2350 RP2040 microzig
