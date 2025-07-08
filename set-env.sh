#!/bin/bash
SCRIPT_DIR=`dirname $(readlink -f $0)`

source ${SCRIPT_DIR}/venv/bin/activate
export PATH=${PATH}:/opt/xpack/riscv-none-elf-gcc/bin:/opt/Xilinx/Vivado/2024.1/bin
export RISCV=/opt/xpack/riscv-none-elf-gcc
export RISCV_CC=/opt/riscv/riscv32-corev-elf-gcc/bin/riscv32-corev-elf-gcc
export CV_SW_TOOLCHAIN=/opt/riscv/riscv32-corev-elf-gcc
export CORE_V_VERIF=${SCRIPT_DIR}/verif/core-v-verif
export CVA6_REPO_DIR=${PWD}

source ${SCRIPT_DIR}/verif/sim/setup-env.sh
