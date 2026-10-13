#!/bin/bash
# Dual-core multicore regress for the FPGA block-design geometry
# (cv64a6_zcu104_sv39: 512-bit D$ lines, 64-bit AXI data, HPDCACHE_WT).
#
# Same test set as multicore-tests-cv64a6_imafdc_sv39.sh, but built against
# the config package used by the Xilinx dual-core block design, so the
# store->load-same-line wbuf geometry (clWords=8, wbufWords=1) is exercised.

# where are the tools
if ! [ -n "$RISCV" ]; then
  echo "Error: RISCV variable undefined"
  return
fi

DV_SIMULATORS=veri-testharness

if [[ "$DV_SIMULATORS" == *"veri-testharness"* ]]; then
  source ./verif/regress/install-verilator.sh
fi
source ./verif/regress/install-spike.sh

source ./verif/regress/install-riscv-compliance.sh
source ./verif/regress/install-riscv-tests.sh
source ./verif/regress/install-riscv-arch-test.sh

source ./verif/sim/setup-env.sh

if ! [ -n "$UVM_VERBOSITY" ]; then
    export UVM_VERBOSITY=UVM_NONE
fi

export DV_OPTS="$DV_OPTS --issrun_opts=+debug_disable=1+UVM_VERBOSITY=$UVM_VERBOSITY"

CC_OPTS="-static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g ../tests/multicore/common/syscalls.c ../tests/multicore/common/vm.c ../tests/multicore/common/crt.S ../tests/multicore/common/page_table.s -I../tests/multicore/env -I../tests/multicore/common -lgcc"

COMPILE_ARGS="-march=rv64gc_zba_zbb_zbs_zbc_zbkb_zbkx_zkne_zknd_zknh_zicbom -mabi=lp64d -DNUM_HARTS=2 --target=riscv64-none-elf"

./verif/regress/gen-compile-commands.sh "${srcA[*]} $CC_OPTS $COMPILE_ARGS" "verif/tests/multicore/lsu_stall"
./verif/regress/gen-compile-commands.sh "${srcA[*]} $CC_OPTS $COMPILE_ARGS" "verif/tests/multicore/lsu_kill_value"

cd verif/sim/

# Warning: this only stresses the LSU, do not trigger the regression fixed in 17d4283a0
python3 cva6.py --nr_harts 2 --mem_output_delay=15 --mem_input_delay=15 --c_tests ../tests/multicore/lsu_stall/lsu_stall.c --output_ref_file=../tests/multicore/references/lsu_stall --iss_yaml cva6.yaml --target cv64a6_zcu104_sv39 --iss=$DV_SIMULATORS --gcc_opts="$CC_OPTS -nostdlib -lgcc" $DV_OPTS --linker=../tests/multicore/common/main.ld 3>&1 1>&2 2>&3 | colout -t cva6 3>&1 1>&2 2>&3
python3 cva6.py --nr_harts 2 --mem_output_delay=15 --mem_input_delay=15 --c_tests ../tests/multicore/lsu_kill_value/lsu_kill_value.c --output_ref_file=../tests/multicore/references/lsu_kill_value --iss_yaml cva6.yaml --target cv64a6_zcu104_sv39 --iss=$DV_SIMULATORS --gcc_opts="$CC_OPTS -nostdlib -lgcc" $DV_OPTS --linker=../tests/multicore/common/main.ld 3>&1 1>&2 2>&3 | colout -t cva6 3>&1 1>&2 2>&3

cd -
