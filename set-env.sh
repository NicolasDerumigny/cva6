#!/bin/bash
SCRIPT_DIR=`dirname $(readlink -f $0)`

export PATH=${PATH}:/opt/xpack/riscv-none-elf-gcc/bin:/opt/Xilinx/Vivado/2024.1/bin
export RISCV=/opt/xpack/riscv-none-elf-gcc/
export CVA6_REPO_DIR=${PWD}
