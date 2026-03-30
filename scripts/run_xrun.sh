#!/bin/bash
# run_xrun.sh
# Made by : Alican Yengec
#
# Single-shot compile and run for a specific test.
# Usage:
#   ./run_xrun.sh                        -> runs uart_test (default)
#   ./run_xrun.sh uart_error_test        -> runs uart_error_test
#   ./run_xrun.sh uart_test UVM_MEDIUM   -> override verbosity

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TEST=${1:-uart_test}
VERB=${2:-UVM_LOW}

echo "Running from: $SCRIPT_DIR"
echo "Test        : $TEST"
echo "Verbosity   : $VERB"

rm -rf xcelium.d INCA_libs xrun.history xrun.log waves.shm

xrun -64bit          \
     -sv             \
     -uvm            \
     -access +rwc    \
     -timescale 1ns/1ps \
     -f files.f      \
     -top example_tb_top \
     +UVM_TESTNAME=$TEST \
     +UVM_VERBOSITY=$VERB
