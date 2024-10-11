[![Build firmware](https://github.com/PatrickBaus/SCAN2000_iCE40_Firmware/actions/workflows/ci.yml/badge.svg)](https://github.com/PatrickBaus/SCAN2000_iCE40_Firmware/actions/workflows/ci.yml)

# Keithley SCAN2000 iCE40 SSR Replacement Firmware
This repository contains the [SystemVerilog](https://en.wikipedia.org/wiki/SystemVerilog) firmware for the Keithley SCAN2000 iCE40 SSR replacement PCB found [here](https://github.com/PatrickBaus/SCAN2000/). Do note, this firmware only works with the 2.x revision of the PCB that uses the [iCE40 FPGA](https://www.latticesemi.com/iCE40). I used the [iCE40](https://www.latticesemi.com/iCE40), because there is an open source framework called [Project IceStorm](https://github.com/YosysHQ/icestorm) to compile the [SystemVerilog](https://en.wikipedia.org/wiki/SystemVerilog) code for the [iCE40](https://www.latticesemi.com/iCE40), making this a fully open implementation.

## Contents
- [Description](#description)
- [Installation](#installation)
- [Compiled Binaries](#compiled-binaries)
- [Related Repositories](#related-repositories)
- [Versioning](#versioning)
- [License](#license)

## Description
The FPGA mimics the serial-input latched drivers found on the original 2000-SCAN cards. Additionally, it allows to reconfigure the internal routing to also accomodate the protocol of the 20 channel version using the same firmware. This can be achieved by setting two jumpers on the PCB. The advante of an FPGA over the MCU driven solutions found online is that an FPGA can easily parse the faster 2 MHz serial input of the [Keithley Model 2002](https://www.tek.com/en/products/keithley/digital-multimeter/2002-series), while at the same time perform some input validation and finally translate the commands designed for latching relays into outputs usable by the non-latching SSRs.

## Installation
The FPGA downloads its firmware on boot from the [Winbond W25Q16JVS](https://www.winbond.com/hq/product/code-storage-flash-memory/serial-nor-flash/?__locale=en&partNo=W25Q16JV) flash ROM IC using SPI. The ROM chip must also be programmed via SPI. This requires a USB to SPI programmer. I used an [OLIMEXINO-32U4](https://www.olimex.com/Products/Duino/AVR/OLIMEXINO-32U4/open-source-hardware) development board and the [iceprogduino](https://github.com/OLIMEX/iCE40HX1K-EVB/tree/master/programmer) implementation, but a Raspberry Pi can [do the job](https://www.olimex.com/wiki/ICE40HX1K-EVB#Iceprog_with_Raspberry_PI) as well.

### Building and Testing
The [SystemVerilog](https://en.wikipedia.org/wiki/SystemVerilog) source code file ```scan2000.sv``` comes with a test bench file called ```scan200_tb.sv``` that runs several unit tests on the code to make sure the FPGA operates correctly. It is highly recommended to run these tests against any code changes before uploading the binary image.

#### Unit Tests
To run the unit tests the following packages need to be installed
```bash
sudo apt -y install nextpnr-ice40 yosys iverilog
```

The tests can then be run be entering
```bash
make tests
```

The command if fail if any of the unit tests fail. If you then want to inspect the FPGA registers, you can open the ```scan200_tb.vvp``` file, created during the test run, with [GTKWave](https://gtkwave.sourceforge.net/) which requires the follwing package to be installed
```bash
sudo apt -y install gtkwave
```

Once installed, you can open the ```scan200_tb.vvp``` file in ```GTKWave```.

#### Building the binary file
To build the source code the following packages are required
```bash
sudo apt -y install nextpnr-ice40 yosys fpga-icestorm
```

The build process is started by typing
```bash
make
```

## Related Repositories
See the following repositories for more information

Keithley SCAN2000 Hardware 2.x: https://github.com/PatrickBaus/SCAN2000/

## Versioning
I use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags](../../tags) available for this repository.

- MAJOR versions in this context mean a breaking change to the external interface like changed commands or functions.
- MINOR versions contain changes that only affect the inner workings of the software, but otherwise the performance is unaffected.
- PATCH versions do not add, remove or change any features. They contain small changes like fixed typos.

## License
This project is licensed under the GPL v3 license - see the [LICENSE](LICENSE) file for details
