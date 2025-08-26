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

# Multicore LSU regression of fpga_linux_zcu104. The two tests leave the
# requests of one hart outstanding in the memory system while the other harts
# have their line invalidated under them, which only shows up when the memory
# answers late: the SoC is elaborated with a fixed delay on both ways of the
# harness memory, the 15 cycles the tests were written against.
#
# Warning: this only stresses the LSU, do not trigger the regression fixed in
# 17d4283a0
#
# Usage: verif/regress/multicore-tests-fpga_linux_zcu104.sh <toolchain>
#        TOOLCHAIN=<toolchain> verif/regress/multicore-tests-fpga_linux_zcu104.sh
#
# Run it from the repository root, in the environment of cook.py: the recipes
# are Python modules the flow installs, so ./cook.py only works with that
# virtualenv activated (flows/QUICKSTART.md).
#
# <toolchain> is a toolchain of the flows configuration, as cook.py takes for
# its -c option (see flows/config/compiler.yml and CONFIG_DIR).  It must give
# __thread a real TLS block: a bare-metal newlib toolchain falls back to emutls,
# which does not even link the programs of this list.

set -euo pipefail

TARGET=fpga_linux_zcu104
TESTLIST=verif/tests/testlist_multicore_lsu.yaml
NR_CORES=${NR_CORES:-2}
MEM_DELAY=${MEM_DELAY:-15}

TOOLCHAIN=${1:-${TOOLCHAIN:-}}
if [ -z "$TOOLCHAIN" ]; then
    echo "Usage: $0 <toolchain>    a toolchain of the flows configuration (-c of cook.py)" >&2
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# The tools of the flow: Verilator, and Spike, whose disassembler reads the
# RVFI traces of the harness and whose front-end server the harness links.
NUM_JOBS=${NUM_JOBS:-$(nproc)}
# The install helpers read their knobs with a plain [-n "$var"], so they need
# every variable they look at to exist: set -u would stop them on the first one
# the caller did not export.  They are sourced with it off, the rest of the
# script keeps it on.
set +u
source ./verif/regress/install-verilator.sh
source ./verif/regress/install-spike.sh
set -u

./cook.py sw-compile-testlist -t "$TARGET" -c "$TOOLCHAIN" -l "$TESTLIST"
./cook.py verilator-testharness-comp -t "$TARGET" --nr-cores "$NR_CORES" \
    --mem-input-delay "$MEM_DELAY" --mem-output-delay "$MEM_DELAY"
./cook.py testharness-run-testlist --simulator verilator -t "$TARGET" -l "$TESTLIST"
