# COREV-APU FPGA Emulation

We currently provide support for the [Genesys 2 board](https://reference.digilentinc.com/reference/programmable-logic/genesys-2/reference-manual) and the [Agilex 7 Development Kit](https://www.intel.la/content/www/xl/es/products/details/fpga/development-kits/agilex/agf014.html).

- **Genesys 2**

    We provide pre-build bitstream and memory configuration files for the Genesys 2 [here](https://github.com/openhwgroup/cva6/releases).

    Tested on Vivado 2018.2. The FPGA currently contains the following peripherals:

   - DDR3 memory controller
   - SPI controller to connect to an SDCard
   - Ethernet controller
   - JTAG port (see debugging section below)
   - Bootrom containing zero stage bootloader and device tree.
   - UART
   - GPIOs connected to LEDs

> The ethernet controller and the corresponding network connection is still work in progress and not functional at the moment. Expect some updates soon-ish.

- **Agilex 7**

   Tested on Quartus Prime Version 24.1.0 Pro Edition. The FPGA currently contains the following peripherals:

   - DDR4 memory controller
   - JTAG port (see debugging section below)
   - Bootrom containing zero stage bootloader
   - UART
   - GPIOs connected to LEDs

> The ethernet controller and the corresponding network connection, as well as the SD Card connection and the capability to boot linux are still work in progress and not functional at the moment. Expect some updates soon-ish.

***
_Added in this repo_

- **ZCU104**
    Tested on Vivado 2024.1. This project contains several block designs variations in
    `corev_apu/fpga/scripts/block_designs/zcu104*.tcl`, namely:
    - `zcu104_50MHz_ethernet.tcl`: 50 MHz version with Ethernet support.
    - `zcu104_100MHz_ethernet.tcl`: Similar version, with the core clock set to 100 MHz.
    - `zcu104_100MHz_second_uart.tcl`: Adds a second UART, which can be set to contains only SBI
      prints module OpenSBI `platform.c` UART address modification. Usefull for debugging IO deadlocks inside Linux.
    - `zcu104_100MHz_dual_core_ethernet.tcl`: experimental 2-core version with Xilinx AXI Ethernet.
      Also relies on the PULP AXI Interconnect rather than Vivado's one, brigning support of AXI5
      atomics but less block design level customizability.
    The default one is `zcu104_100MHz_dual_core_ethernet.tcl`. To change it, delete `zcu104.tcl` and
    create a symbolic link to the desired flavour.
    The FPGA currently contains the following peripherals:
    - DDR4 memory controller wire to the SO-DIMM slot, using [MTA8ATF1G64HZ-compatible](https://www.micron.com/products/memory/dram-modules/sodimm/part-catalog/part-detail/mta8atf1g64hz-3g2r1) timings
    - JTAG port (see debugging section below)
    - Bootrom containing zero stage bootloader
    - UART, routed through the integrated USB-to-Quad-UART module
    - SPI controler router to the PMOD0 header for SDCard support, requires a [PMOD-micoSD adapter](https://digilent.com/reference/pmod/pmodmicrosd/start)
    - (depending on version) Ethernet MAC Controller, routed to the first port of a
        [CN0506 FMC module](https://www.analog.com/en/resources/reference-designs/circuits-from-the-lab/cn0506.html) using
        [AMD AXI Ethernet](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi_ethernet.html)
    - GPIOs connected to LEDs (including Ethernet's when applicable)


- **PYNQ-Z2**
    Tested on Vivado 2024.1, using a degraded 25 MHz core clock frequency (50 MHz interconnect one
    for faster memory/peripheral transfer speed)
    The FPGA currently contains the following peripherals:
    - Access to the board's upper 128 MiB of DRAM (if double-booting Linux on the Arm cores, limits
      its usage to the 127 lower MiB with the kernel parameter `memory=128M`
    - JTAG port (see debugging section below)
    - Bootrom containing zero stage bootloader
    - UART routed through the PMODA lower port, requires a [PMOD-USB-UART adapter](https://digilent.com/reference/pmod/pmodusbuart/start)
    - SPI controler router to a PMODB header for SDCard support, requires a [PMOD-micoSD adapter](https://digilent.com/reference/pmod/pmodmicrosd/start)
    - GPIOs connected to LEDs

_End of addition_
***

## Programming the Memory Configuration File or bitstream

- **Genesys 2**

   - Open Vivado 2018.2
   - Open the hardware manager and open the target board (Genesys II - `xc7k325t`)
   - Tools - Add Configuration Memory Device
   - Select the following Spansion SPI flash `s25fl256xxxxxx0`
   - Add `ariane_xilinx.mcs`
   - Press Ok. Flashing will take a couple of minutes.
   - Right click on the FPGA device - Boot from Configuration Memory Device (or press the program button on the FPGA)

- **Agilex 7**

   - Open Quartus programmer
   - Configure HW Setup by selecting the AGF FPGA Development Kit
   - Click Auto-Detect to scan the JTAG chain
   - In the device list, right click over device AGFB014R24B and add file (.rbf under corev_apu/altera/output_files)
   - Click on Start button to program the FPGA
   - Right after programming you can connect to the UART and see your CVA6 alive on Agilex!
   - For this you need to use the JTAG UART provided with Quartus installation


***
_Added in this repo_

- **ZCU104 / PYNQ-Z2**
   - Open Vivado 2021.1
   - Open the hardware manager and open the target board
   - Right-click on the MPSoC node (`xczu7_0` for the ZCU104) in the "Hardware" tab
   - Select `ariane_xilinx.bit`
   - Press Ok. Flashing will take a couple of seconds. Booting will begin as soon as flashing is
     done

_Note:_ Flashing can also be performed from a booted (Arm-side) Linux using [fpga manager](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18841645/Solution+Zynq+PL+Programming+With+FPGA+Manager) and
`ariane_xilinx.bin` file generated with Vivado's [bootgen](https://github.com/Xilinx/bootgen).


_End of addition_
***

```
.$quartus_installation_path/qprogrammer/quartus/bin/juart-terminal
juart-terminal: connected to hardware target using JTAG UART on cable
juart-terminal: "AGF FPGA Development Kit [1-3]", device 1, instance 0
juart-terminal: (Use the IDE stop button or Ctrl-C to terminate)

Hello World!
```

## Booting Linux

***
_Added in this repo_

MPSoC boot is similar, except that:
- The corresponding ariane-sdk repo is located [here](https://github.com/NicolasDerumigny/cva6-sdk)
- The USB Serial device is probably not `/dev/ttyUSB0`, as Linux should see the board's programming
  interface first. On the ZCU104, it should be `/dev/ttyUSB3`.

_End of addition_
***

The first stage bootloader will boot from SD Card by default. Get yourself a suitable SD Card (we use [this](https://www.amazon.com/Kingston-Digital-Mobility-MBLY10G2-32GB/dp/B00519BEQO) one). Either grab a pre-built Linux image from [here](https://github.com/pulp-platform/ariane-sdk/releases) or generate the Linux image yourself following the README in the [ariane-sdk repository](https://github.com/pulp-platform/ariane-sdk). Prepare the SD Card by following the "Booting from SD card" section in the ariane-sdk repository.

Connect a terminal to the USB serial device opened by the FTDI chip e.g.:
```
screen /dev/ttyUSB0 115200
```

Default baudrate set by the bootloader and Linux is `115200`.

After you've inserted the SD Card and programmed the FPGA you can connect to the serial port of the FPGA and should see the bootloader and afterwards Linux booting. Default username is `root`, no password required.

## Booting zephyr RTOS

[zephyr](https://zephyrproject.org/) is a real-time unikernel operating system developed by the Linux Foundation that targets resource-constrained embedded devices. It is highly configurable and optionally provides subsystems like userspace support with the PMP, a full network stack and a file system.

zephyr natively supports the cva6 SoC and the **Genesys 2** board in two configurations: [cv64a6_imafdc_sv39](https://docs.zephyrproject.org/latest/boards/openhwgroup/cv64a6_genesys_2/doc/index.html) and [cv32a6_imac_sv32](https://docs.zephyrproject.org/latest/boards/openhwgroup/cv32a6_genesys_2/doc/index.html).
See the
`cv64a6_imafdc_sv39` is the configuration that will be synthesized when you follow the steps [below](#generating-a-bitstream).
In order to build `cv32a6_imac_sv32`, use the following command instead:
```bash
target=cv32a6_imac_sv32 make fpga
```

In order to build a zephyr application, follow the [zephyr getting started guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html) to setup the build dependencies and install zephyr's meta tool *west*.
You can then build zephyr applications using the standard process:
```bash
west build -p -b cv64a6_genesys_2 samples/hello_world # for cv64a6_imafdc_sv39
west build -p -b cv32a6_genesys_2 samples/hello_world # for cv32a6_imac_sv32
```


You can use zephyr's *west* to debug or flash the application via openocd, akin to [the instructions below](#debugging):
```bash
west flash # loads the application into memory and runs it
west debug # launches an interactive GDB console that loads the application and stops at the first instruction
west attach # attaches to an application loaded using "west load"
```

Alternatively, similar to the [Linux instructions](#booting-linux), you may load zephyr from an SD card.
To this end, *after building the application*, use the provided script:
```bash
./util/write-zephyr-sd.sh /dev/sdXXX /path/to/zephyrproject/zephyr # provide correct SD card device and path to top level of cloned zephyrproject/zephyr repository
```
**WARNING: The script will wipe the partition table and destroy all data on the SD card. Double-check the device path before running the script.**

You can then insert the SD card into the board and have the zero-stage boot loader load and run zephyr.



## Generating a Bitstream

- **Genesys 2**

To generate the FPGA bitstream (and memory configuration) yourself for the Genesys II or MPSoC boards (check the `BOARD` variable in `Makefile` to set the actual target), then run:

```
make fpga
```

This will produce a bitstream file and memory configuration file (in `fpga/work-fpga`) which you can permanently flash by running the above commands. On MPSoCs, this also creates a customizable Vivado 2024.1 project in `corev_apu/fpga/ariane.xpr`.

- **Agilex 7**

To generate the FPGA bitstream yourself for the Agilex 7 board run:
```
make altera
```

We recommend to set the parameter FpgaAlteraEn (and also FpgaEn) to benefit from the FPGA optimizations.

This will produce a bitstream file (in `altera/output_files`) which you can program following the previous instructions. **Note: Bear in mind that you need a Quartus Pro Licence to be able to generate this bitstream**

To clean the project after generating the bitstream, use

```
make clean-altera
```

## Debugging

- **Genesys 2**
You can debug (and program) the FPGA using [OpenOCD](http://openocd.org/doc/html/Architecture-and-Core-Commands.html). We provide two example scripts for OpenOCD below.

To get started, connect the micro USB port that is labeled with JTAG to your machine. This port is attached to the FTDI 2232 USB-to-serial chip on the Genesys 2 board, and is usually used to access the native JTAG interface of the Kintex-7 FPGA (e.g. to program the device using Vivado 2018.2). However, the FTDI chip also exposes a second serial link that is routed to GPIO pins on the FPGA, and we leverage this to wire up the JTAG from the RISC-V debug module.

>If you are on an Ubuntu based system you need to add the following udev rule to `/etc/udev/rules.d/99-ftdi.rules`
>```
> SUBSYSTEM=="usb", ACTION=="add", ATTRS{idProduct}=="6010", ATTRS{idVendor}=="0403", MODE="664", GROUP="plugdev"
>```

Once attached to your system, the FTDI chip should be listed when you type `lsusb`:

```
Bus 005 Device 019: ID 0403:6010 Future Technology Devices International, Ltd FT2232C/D/H Dual UART/FIFO IC
```

If this is the case, you can go on and start openocd with the `fpga/ariane.cfg` configuration file:

```
openocd -f fpga/ariane.cfg

Open On-Chip Debugger 0.10.0+dev-00195-g933cb87 (2018-09-14-19:32)
Licensed under GNU GPL v2
For bug reports, read
    http://openocd.org/doc/doxygen/bugs.html
adapter speed: 1000 kHz
Info : auto-selecting first available session transport "jtag". To override use 'transport select <transport>'.
Info : clock speed 1000 kHz
Info : TAP riscv.cpu does not have IDCODE
Info : datacount=2 progbufsize=8
Info : Examined RISC-V core; found 1 harts
Info :  hart 0: XLEN=64, misa=0x8000000000141105
Info : Listening on port 3333 for gdb connections
Ready for Remote Connections
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Info : accepting 'gdb' connection on tcp/3333
```
- **Agilex 7**

You can debug (and program) the FPGA using a modified version of OpenOCD included with Quartus installation ($quartus_installation_path/qprogrammer/quartus/bin/openocd).

To get started, connect the micro USB port that is labeled with J13 to your machine. It is the same port that is used for the UART. Both use the JTAG interface and connect to the System Level Debugging (SLD) Hub instantiated inside the FPGA. Then the debugger connection goes to the virtual JTAG IP (vJTAG) which can be accessed with the modified version of OpenOCD.

You can start openocd with the `altera/cva6.cfg` configuration file:

```
./$quartus_installation_path/qprogrammer/quartus/bin/openocd -f altera/cva6.cfg
Open On-Chip Debugger 0.11.0-R22.4
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
Info : only one transport option; autoselect 'jtag'
Info : Application name is OpenOCD.20241016093010
Info : No cable specified, so will be searching for cables

Info : At present, The first hardware cable will be used [1 cable(s) detected]
Info : Cable 1: device_name=(null), hw_name=AGF FPGA Development Kit, server=(null), port=1-3, chain_id=0x559319c8cde0, persistent_id=1, chain_type=1, features=34816, server_version_info=Version 24.1.0 Build 115 03/21/2024 SC Pro Edition
Info : TAP position 0 (C341A0DD) has 3 SLD nodes
Info :     node  0 idcode=00406E00 position_n=0
Info :     node  1 idcode=30006E00 position_n=0
Info :     node  2 idcode=0C006E00 position_n=0
Info : TAP position 1 (20D10DD) has 1 SLD nodes
Info :     node  0 idcode=0C206E00 position_n=0
Info : Discovered 2 TAP devices
Info : Detected device (tap_position=0) device_id=c341a0dd, instruction_length=10, features=12, device_name=AGFB014R24A(.|R1|R2)/..
Info : Found an Intel device at tap_position 0.Currently assuming it is SLD Hub
Info : Detected device (tap_position=1) device_id=020d10dd, instruction_length=10, features=4, device_name=VTAP10
Info : Found an Intel device at tap_position 1.Currently assuming it is SLD Hub
Info : This adapter doesn't support configurable speed
Info : JTAG tap: agilex7.fpga.tap tap/device found: 0xc341a0dd (mfg: 0x06e (Altera), part: 0x341a, ver: 0xc)
Info : JTAG tap: auto0.tap tap/device found: 0x020d10dd (mfg: 0x06e (Altera), part: 0x20d1, ver: 0x0)
Info : JTAG tap: agilex7.fpga.tap Parent Tap found: 0xc341a0dd (mfg: 0x06e (Altera), part: 0x341a, ver: 0xc)
Info : Virtual Tap/SLD node 0x00406E00 found at tap position 0 vtap position 0
Warn : AUTO auto0.tap - use "jtag newtap auto0 tap -irlen 10 -expected-id 0x020d10dd"
Info : datacount=2 progbufsize=8
Info : Examined RISC-V core; found 1 harts
Info :  hart 0: XLEN=32, misa=0x40141107
Info : starting gdb server for agilex7.cva6.0 on 3333
Info : Listening on port 3333 for gdb connections
Ready for Remote Connections
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
```

***
_Added in this repo_

- **AMD MPSoC boards**

The CVA6 is debuggable from a booted Arm-side Linux using Xilinx Virtual Cable interface, now
supported on latest versions of OpenOCD.
The steps to run it are:
- Copy `corev_apu/fpga/ariane-mpsoc.cfg` to the board
- Edit the `xlnx_axi_xvc dev_addr 0xZZZZZZZ` to match the AXI-JTAG address (0xA0000000 on ZCU104, 0x43C00000 on the PYNQ-Z2)
- If running the single-core version: delete the line `target create $_TARGETNAME_1 riscv -chain-position $_TARGETNAME -coreid 1`
- Start OpenOCD:
```
sudo openocd -f ariane-mpsoc.cfg

Open On-Chip Debugger 0.12.0+dev-gce83008c6 (2025-07-01-09:37)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : Opening /dev/mem for AXI communication
Info : Mapped Xilinx XVC/AXI vaddr 0xffff98ed4000 paddr 0xa0000000
Info : Note: The adapter "xlnx_axi_xvc" doesn't support configurable speed
Info : WARN: XVC driver has no reset.
Info : JTAG tap: riscv.cpu tap/device found: 0x00000001 (mfg: 0x000 (<invalid>), part: 0x0000, ver: 0x0)
Info : datacount=2 progbufsize=8
Info : Examined RISC-V core; found 2 harts
Info :  hart 0: XLEN=64, misa=0x800000000014112f
Info : [riscv.cpu0] Examination succeed
Info : datacount=2 progbufsize=8
Info : Examined RISC-V core; found 2 harts
Info :  hart 1: XLEN=64, misa=0x800000000014112f
Info : [riscv.cpu1] Examination succeed
Info : [riscv.cpu0] starting gdb server on 3333
Info : Listening on port 3333 for gdb connections
Info : [riscv.cpu1] starting gdb server on 3334
Info : Listening on port 3334 for gdb connections
Ready for Remote Connections
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
```

_End of addition_
***



- **Common for all boards**

Then you will be able to either connect through `telnet` or with `gdb`:

```
risc-none-elf-gdb /path/to/elf

(gdb) target remote localhost:3333
(gdb) load
Loading section .text, size 0x6508 lma 0x80000000
Loading section .rodata, size 0x900 lma 0x80006508
(gdb) b putchar
(gdb) c
Continuing.

Program received signal SIGTRAP, Trace/breakpoint trap.
0x0000000080009126 in putchar (s=72) at lib/qprintf.c:69
69    uart_sendchar(s);
(gdb) si
0x000000008000912a  69    uart_sendchar(s);
(gdb) p/x $mepc
$1 = 0xfffffffffffdb5ee
```

You can read or write device memory by using:
```
(gdb) x/i 0x1000
    0x1000: lui t0,0x4
(gdb) set {int} 0x1000 = 22
(gdb) set $pc = 0x1000
```


## Preliminary Support for OpenPiton Cache System

CVA6 has preliminary support for the OpenPiton distributed cache system from Princeton University. To this end, a different L1 cache subsystem (`src/cache_subsystem/wt_cache_subsystem.sv`) has been developed that follows a write-through protocol and that has support for cache invalidations and atomics.

The corresponding integration patches will be released on [OpenPiton GitHub repository](https://github.com/PrincetonUniversity/openpiton). Check the `README` in that repository to see how to use CVA6 in the OpenPiton setting.

To activate the different cache system, compile your code with the macro `DCACHE_TYPE`.


## Re-generating the Bootcode (ZSBL)

The zero stage bootloader (ZSBL) for RTL simulation lives in `bootrom/` while the bootcode for the FPGA is in `fpga/src/bootrom`. The RTL bootcode simply jumps to the base of the DRAM where the FSBL takes over. For the FPGA the ZSBL performs additional housekeeping. Both bootloader pass the hartid as well as address to the device tree in argument register `a0` and `a1` respectively.

To re-generate the bootcode you can use the existing makefile within those directories. To generate the SystemVerilog files you will need the `bitstring` python package installed on your system.

***
_Added in this repo_

A target `bootrom-fpga` has been added to the top-level Makefile, which will trigger the
`fpga/src/bootrom` one with the correct arguments.

_End of addition_
***


