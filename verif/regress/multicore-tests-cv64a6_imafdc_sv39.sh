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

# Multicore regression of cv64a6_imafdc_sv39: the harts of the SoC share their
# L1d and each has a hpicache L1i of its own, and the tests of the lists have
# them interact through that cache -- a hart taking a line another one wrote,
# a reservation lost under another hart, the CLINT interrupting them all.
#
# Both lists of verif/tests are run.  testlist_multicore_lsu.yaml needs a
# memory which answers late, so its design is elaborated a second time with a
# delay on both ways of the harness memory; the two elaborations are what the
# two lists are run on.
#
# Only Verilator is supported: the harness of corev_apu/tb, which is what the
# tests are written for, has no UVM counterpart able to drive several harts.
#
# Usage: verif/regress/multicore-tests-cv64a6_imafdc_sv39.sh <toolchain>
#        TOOLCHAIN=<toolchain> verif/regress/multicore-tests-cv64a6_imafdc_sv39.sh
#
# Run it from the repository root, in the environment of cook.py: the recipes
# are Python modules the flow installs, so ./cook.py only works with that
# virtualenv activated (flows/QUICKSTART.md).
#
# <toolchain> is a toolchain of the flows configuration, as cook.py takes for
# its -c option (see flows/config/compiler.yml and CONFIG_DIR).  It must give
# __thread a real TLS block: a bare-metal newlib toolchain falls back to emutls,
# which does not even link the programs of these lists.  NR_CORES and
# MEM_DELAY override the number of harts and the delay of the memory.

set -euo pipefail

TARGET=cv64a6_imafdc_sv39
TESTLISTS=(verif/tests/testlist_multicore.yaml verif/tests/testlist_multicore_lsu.yaml)
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

# One build of the programs of each list, then, per list, one elaboration of
# the SoC with as many harts as the tests were compiled for (-DNUM_HARTS of the
# testlist) and the whole list on that elaboration.
for testlist in "${TESTLISTS[@]}"; do
    ./cook.py sw-compile-testlist -t "$TARGET" -c "$TOOLCHAIN" -l "$testlist"
done

./cook.py verilator-testharness-comp -t "$TARGET" --nr-cores "$NR_CORES"
./cook.py testharness-run-testlist --simulator verilator -t "$TARGET" -l "${TESTLISTS[0]}"

# The load-unit tests only show what they test when the memory answers late.
./cook.py verilator-testharness-comp -t "$TARGET" --nr-cores "$NR_CORES" \
    --mem-input-delay "$MEM_DELAY" --mem-output-delay "$MEM_DELAY"
./cook.py testharness-run-testlist --simulator verilator -t "$TARGET" -l "${TESTLISTS[1]}"
