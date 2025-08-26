#!/bin/bash
SCRIPT_DIR=`dirname $(readlink -f $0)`

export PATH=${PATH}:/opt/xpack/riscv-none-elf-gcc/bin:/opt/Xilinx/Vivado/2024.1/bin
export RISCV=/opt/xpack/riscv-none-elf-gcc
export RISCV_CC=/opt/riscv/riscv32-corev-elf-gcc/bin/riscv32-corev-elf-gcc
export CV_SW_TOOLCHAIN=/opt/riscv/riscv32-corev-elf-gcc
export CORE_V_VERIF=${SCRIPT_DIR}/verif/core-v-verif
export CVA6_REPO_DIR=${PWD}

export XLEN=64
export BOARD=zcu104
export target=cv64a6_imafdch_sv39
export PLATFORM=PLAT_XILINX

source ${SCRIPT_DIR}/venv/bin/activate
source ${SCRIPT_DIR}/verif/sim/setup-env.sh
