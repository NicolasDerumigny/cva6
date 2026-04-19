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

cd verif/sim/

python3 cva6.py --nr_harts 1 --c_tests ../tests/multicore/fpu_share/fpu_test.c --output_ref_file=../tests/multicore/references/fpu_test --iss_yaml cva6.yaml --target cv64a6_imafdc_sv39 --iss=$DV_SIMULATORS --gcc_opts="$CC_OPTS" $DV_OPTS --linker=../../config/gen_from_riscv_config/linker/link.ld 3>&1 1>&2 2>&3 | colout -t cva6 3>&1 1>&2 2>&3

cd -
