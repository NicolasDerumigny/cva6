#!/bin/bash
SCRIPT_DIR=`dirname $(readlink -f $0)`

export PATH=${PATH}:/opt/xpack/riscv-none-elf-gcc/bin:/opt/Xilinx/Vivado/2024.1/bin
export RISCV=/opt/xpack/riscv-none-elf-gcc
export RISCV_CC=/opt/riscv/riscv32-corev-elf-gcc/bin/riscv32-corev-elf-gcc
export RISCV_GCC=/opt/xpack/riscv-none-elf-gcc/bin/riscv-none-elf-gcc
export RISCV_OBJCOPY=/opt/xpack/riscv-none-elf-gcc/bin/riscv-none-elf-objcopy
export CV_SW_TOOLCHAIN=/opt/riscv/riscv32-corev-elf-gcc
export CORE_V_VERIF=${SCRIPT_DIR}/verif/core-v-verif
export CVA6_REPO_DIR=${SCRIPT_DIR}
export HPDCACHE_DIR=${SCRIPT_DIR}/core/cache_subsystem/hpdcache

export XLEN=64
export BOARD=zcu104
export target=cv64a6_${BOARD}_sv39
export TARGET_CFG=${target}
export PLATFORM=PLAT_XILINX

export NUM_JOBS=$(nproc)

export DV_SIMULATORS=veri-testharness,spike

if [ -f "${SCRIPT_DIR}/venv/bin/activate" ]; then
    source ${SCRIPT_DIR}/venv/bin/activate
fi
source ${SCRIPT_DIR}/verif/sim/setup-env.sh
