#!/bin/bash
# Environment of this checkout: the tools the flows need, and the board and
# target the recipes build by default.
#
# The tool paths live in two places. `verif/sim/setup-env.sh`, sourced at
# the end of this file, derives the RISC-V toolchain, Verilator and Spike
# locations from RISCV, VERILATOR_INSTALL_DIR and SPIKE_INSTALL_DIR;
# `flows/config/setenv.sh` is the one cook.py reads for the proprietary
# tools (Vivado, Verible, the simulators) and for the Python environment of
# the flows. This file only sets what those two leave out, and the defaults
# of this fork: a Xilinx board, the target of `config/target` built for it,
# and the two harts of the multicore SoC.
#
#   source set-env.sh
#   ./cook.py vivado-fpga-build --target fpga_linux_zcu104 --board zcu104
#
# Each variable keeps the value the environment already has, so a CI job or
# a shell may override any of them before sourcing this file.

if [ -n "$BASH_VERSION" ]; then
  SCRIPT_PATH="$BASH_SOURCE[0]"
elif [ -n "$ZSH_VERSION" ]; then
  SCRIPT_PATH="${(%):-%N}"
else
  echo "Error: non recognized shell: source set-env.sh from bash or zsh."
  return
fi
SCRIPT_DIR=$(readlink -f "$(dirname "${SCRIPT_PATH}")")

# ---------------------------------------------------------------
# Board and target
# ---------------------------------------------------------------

# Xilinx board of the FPGA images, and the target of config/target built
# for it (see the BOARD switch of the root Makefile and the board table of
# flows/utils/fpga_board.py).
export BOARD=${BOARD:-zcu104}
export target=${target:-fpga_linux_${BOARD}}
# Name the file lists of the RTL use to find config/target/<target>/
export TARGET_CFG=${target}
# Platform macro of the zero stage bootloader, -D<PLATFORM> of
# corev_apu/fpga/src/bootrom/Makefile.
export PLATFORM=${PLATFORM:-PLAT_XILINX}
# Register width, from the march of the target: read by the bootrom and by
# the riscv-tests of the Makefile entries.
export XLEN=${XLEN:-64}
# Harts of the multicore SoC, -GNR_CORES of `make verilate` and
# CVA6_NR_HARTS of verif/sim/Makefile: both must agree, the model is
# elaborated with it.
export CVA6_NR_HARTS=${CVA6_NR_HARTS:-2}
export NR_CORES=${NR_CORES:-$CVA6_NR_HARTS}
export NUM_JOBS=${NUM_JOBS:-$(nproc)}

# ---------------------------------------------------------------
# Tools
# ---------------------------------------------------------------

# Toolchain the software of the regressions and the bootloader are built
# with. CV_SW_PREFIX is the prefix of the binaries of RISCV: verif/sim/
# setup-env.sh derives it from the first program it finds in bin, which
# picks the wrong one when a toolchain carries several prefixes, so it is
# named here.
export RISCV=${RISCV:-/opt/xpack/riscv-none-elf-gcc}
export CV_SW_PREFIX=${CV_SW_PREFIX:-riscv-none-elf-}
export PATH=${PATH}:${RISCV}/bin

# Toolchain of the zero stage bootloader of the PYNQ-Z2, which runs in
# RV32 (see RISCV_CC of corev_apu/fpga/src/bootrom/Makefile).
export RISCV_CC=${RISCV_CC:-/opt/riscv/riscv32-corev-elf-gcc/bin/riscv32-corev-elf-gcc}
export RISCV_GCC=${RISCV_GCC:-${RISCV}/bin/riscv-none-elf-gcc}
export RISCV_OBJCOPY=${RISCV_OBJCOPY:-${RISCV}/bin/riscv-none-elf-objcopy}
export RISCV_OBJDUMP=${RISCV_OBJDUMP:-${RISCV}/bin/riscv-none-elf-objdump}
export CV_SW_TOOLCHAIN=${CV_SW_TOOLCHAIN:-/opt/riscv/riscv32-corev-elf-gcc}

# Vivado, for the `make fpga` entries: cook.py reads it from
# flows/config/setenv.sh, the Makefiles only need it in PATH.
export PATH=${PATH}:/opt/Xilinx/Vivado/2024.1/bin

# ---------------------------------------------------------------
# Repository
# ---------------------------------------------------------------

export CVA6_REPO_DIR=${SCRIPT_DIR}
export CORE_V_VERIF=${SCRIPT_DIR}/verif/core-v-verif
export HPDCACHE_DIR=${SCRIPT_DIR}/core/cache_subsystem/hpdcache

# ---------------------------------------------------------------
# Simulators
# ---------------------------------------------------------------

# The regress scripts of verif/regress run the TestHarness with Verilator
# and compare its trace against Spike; the multicore tests are only
# exercised with Verilator, the other simulators drive one hart at a time.
export DV_SIMULATORS=${DV_SIMULATORS:-veri-testharness,spike}
# Built by verif/regress/install-verilator.sh and install-spike.sh, under
# tools/ (see verif/sim/setup-env.sh).
export VERILATOR_INSTALL_DIR=${VERILATOR_INSTALL_DIR:-${SCRIPT_DIR}/tools/verilator}
export SPIKE_INSTALL_DIR=${SPIKE_INSTALL_DIR:-${SCRIPT_DIR}/tools/spike}

# ---------------------------------------------------------------
# Python environment of cook.py
# ---------------------------------------------------------------

# The flows need Python 3.12 with flows/requirements.txt:
#   uv venv -p 3.12 .venv && . .venv/bin/activate
#   uv pip install -r flows/requirements.txt
# The virtual environment `make venv` creates, venv/, is used as a fallback
# for what does not use cook.py. It needs `pyyaml` and `colout`, and the
# symbolic link the Makefile entry does not create:
#   ln -s ../../../../../util/colout_cva6.py venv/lib/python3.XX/site-packages/colout
for venv in "${VENV_PATH:-}" "${SCRIPT_DIR}/.venv" "${SCRIPT_DIR}/venv"; do
  if [ -n "${venv}" ] && [ -f "${venv}/bin/activate" ]; then
    # shellcheck disable=SC1090
    source "${venv}/bin/activate"
    break
  fi
done

# shellcheck disable=SC1090
source "${SCRIPT_DIR}/verif/sim/setup-env.sh"
