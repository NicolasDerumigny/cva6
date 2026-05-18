#!/bin/bash
# Inria 2026
#
# Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
# You may obtain a copy of the License at https://solderpad.org/licenses/
#
# Original Author: Nicolas Derumigny - Inria

CC=${RISCV_GCC}
CFLAGS="${1//-mcmodel=medany/}"
DIR="${2}"


CFLAGS="${CFLAGS//-I\.\.\//-I${PWD}\/verif\/}"
CFLAGS="${CFLAGS// \.\.\// ${PWD}\/verif\/}"

echo "[" > "${DIR}/compile_commands.json"

first=1
for f in "$DIR"/*.c; do
    [ -e "$f" ] || continue

    if [ $first -eq 0 ]; then
        echo "," >> "${DIR}/compile_commands.json"
    fi
    first=0

    cat >> "${DIR}/compile_commands.json" << EOF
{
  "directory": "$(pwd)/$DIR",
  "command": "$CC $CFLAGS -c $f -o ${f%.c}.o",
  "file": "$f"
}
EOF
done

echo "]" >> "${DIR}/compile_commands.json"
