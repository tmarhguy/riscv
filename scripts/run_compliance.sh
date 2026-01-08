#!/bin/bash
SIM=./build/obj_dir/ironcore_sim
TESTS_DIR=tb/compliance/build
LOG_DIR=logs/compliance
mkdir -p $LOG_DIR

echo "Running Compliance Tests..."
passed=0
failed=0

for test_bin in $(find $TESTS_DIR -name "*.bin" | sort); do
    test_name=$(basename $test_bin .bin)
    echo -n "Running $test_name ... "
    $SIM $test_bin --timeout 200000 > $LOG_DIR/${test_name}.log
    if [ $? -eq 0 ]; then
        echo "PASS"
        passed=$((passed+1))
    else
        echo "FAIL (See $LOG_DIR/${test_name}.log)"
        failed=$((failed+1))
    fi
done

echo "--------------------------------"
echo "Results:"
echo "PASS: $passed"
echo "FAIL: $failed"
exit $failed
