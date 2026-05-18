#!/bin/bash
# Copyright 2021 Thales DIS design services SAS
# Inria 2026
#
# Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
# You may obtain a copy of the License at https://solderpad.org/licenses/
#
# Original Author: Jean-Roch COULON - Thales
# Modified by Nicolas Derumigny - Inria

# where are the tools
if ! [ -n "$RISCV" ]; then
  echo "Error: RISCV variable undefined"
  return
fi

#if ! [ -n "$DV_SIMULATORS" ]; then
# Only tested (working?) with Verilator
  DV_SIMULATORS=veri-testharness
#fi

# install the required tools
if [[ "$DV_SIMULATORS" == *"veri-testharness"* ]]; then
  source ./verif/regress/install-verilator.sh
fi
source ./verif/regress/install-spike.sh

# install the required test suites
source ./verif/regress/install-riscv-compliance.sh
source ./verif/regress/install-riscv-tests.sh
source ./verif/regress/install-riscv-arch-test.sh

# setup sim env
source ./verif/sim/setup-env.sh

echo "$SPIKE_INSTALL_DIR$"

if ! [ -n "$UVM_VERBOSITY" ]; then
    export UVM_VERBOSITY=UVM_NONE
fi

export DV_OPTS="$DV_OPTS --issrun_opts=+debug_disable=1+UVM_VERBOSITY=$UVM_VERBOSITY"

CC_OPTS="-static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g ../tests/multicore/common/syscalls.c ../tests/multicore/common/crt.S -I../tests/multicore/env -I../tests/multicore/common -lgcc"

srcs=(
    ../tests/multicore/pinned/pinned_csr.c
    ../tests/multicore/pinned/pinned_mem_coherency.c
    ../tests/multicore/pinned/pinned_after_inval.c
    ../tests/multicore/pinned/pinned_full.c
)

srcA=(
    ../tests/multicore/common/page_table.s
    ../tests/multicore/common/trampoline.S
    ../tests/multicore/common/vm.c
)

./verif/regress/gen-compile-commands.sh "${srcA[*]} $CC_OPTS" "verif/tests/multicore/pinned"

cd verif/sim/

for src in "${srcs[@]}"; do
    ref_file=`basename ${src/.c//}`
    python3 cva6.py --nr_harts 2 --c_tests $src  --output_ref_file=../tests/multicore/references/hpdcache_${ref_file} --iss_yaml cva6.yaml --target cv64a6_imafdc_sv39 --iss=$DV_SIMULATORS --gcc_opts="${srcA[*]} $CC_OPTS" $DV_OPTS --linker=../tests/multicore/common/main.ld 3>&1 1>&2 2>&3 | colout -t cva6 3>&1 1>&2 2>&3
done

cd -
