# CLINT (Core-local Interrupt Controller)

This repository contains a RISC-V privilege spec 1.11 (WIP) compatible CLINT for the Ariane Core.

The CLINT plugs into an existing AXI Bus with an AXI 4 Lite interface. The IP mirrors transaction IDs and is fully pin-compatible with the full AXI 4 interface. It does not support burst transfers (as specified in the AXI 4 Bus specification)

The number of supported harts is set by the `NR_CORES` parameter (default `1`). Each hart has its own `msip` and `mtimecmp` registers, while a single 64-bit `mtime` register is shared by all harts. The interrupt outputs `timer_irq_o` and `ipi_o` are `NR_CORES`-bit wide, with bit `i` corresponding to hart `i`.

|                             Address                            | Description |                                          Note                                            |
|----------------------------------------------------------------|-------------|------------------------------------------------------------------------------------------|
| `BASE` + `0x0` ... `BASE` + `0x4 * (NR_CORES - 1)`             | msip        | Per-hart machine mode software interrupt (IPI), 4-byte stride, only bit 0 is implemented |
| `BASE` + `0x4000` ... `BASE` + `0x4000 + 0x8 * (NR_CORES - 1)` | mtimecmp    | Per-hart 64-bit machine mode timer compare register, 8-byte stride                       |
| `BASE` + `0xBFF8`                                              | mtime       | Timer register, shared by all harts                                                      |
