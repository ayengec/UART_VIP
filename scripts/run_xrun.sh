#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Running from: $SCRIPT_DIR"

rm -rf xcelium.d INCA_libs xrun.history xrun.log waves.shm

xrun -64bit \
     -sv \
     -uvm \
     -access +rwc \
     -f files.f \
     -top example_tb_top
