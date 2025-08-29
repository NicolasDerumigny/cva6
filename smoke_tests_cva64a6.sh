#!/bin/bash
source set-env.sh
bash verif/regress/smoke-tests-cv64a6_imafdc_sv39.sh 2>&1 | colout -t cva6
