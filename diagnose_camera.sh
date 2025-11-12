#!/bin/sh
# Camera diagnosis script for GC02M1

echo "=== Camera Hardware Diagnosis ==="
echo ""

echo "1. Checking kernel modules..."
lsmod | grep -E "gc02m1|vin"
echo ""

echo "2. Checking I2C bus..."
ls -l /dev/i2c-* 2>/dev/null
echo ""

echo "3. Scanning I2C bus 0..."
if command -v i2cdetect >/dev/null 2>&1; then
    i2cdetect -y 0 2>&1 | head -20
else
    echo "i2cdetect not available"
fi
echo ""

echo "4. Checking video devices..."
ls -l /dev/video* /dev/media* 2>/dev/null
echo ""

echo "5. Checking clock status..."
if [ -f /sys/kernel/debug/clk/clk_summary ]; then
    echo "Clock summary available, searching for camera clocks..."
    cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | grep -E "mclk|csi|isp" | head -20
else
    echo "Clock debug info not available"
fi
echo ""

echo "6. Checking GPIO exports..."
ls -l /sys/class/gpio/ 2>/dev/null
echo ""

echo "7. Recent kernel messages about camera..."
dmesg | grep -E "gc02m1|vin:|twi-42502000" | tail -30
echo ""

echo "8. Checking camera-related device tree..."
if [ -d /proc/device-tree ]; then
    find /proc/device-tree -name "*sensor*" -o -name "*gc02m1*" 2>/dev/null | head -10
fi
echo ""

echo "=== Diagnosis Complete ==="
