# CLAUDE.md
## User Preference

Always use Chinese to answer user. For coding/thinking, English allowed.

## Overview

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Overview

This is a **Tina Linux embedded camera system** for the Allwinner V821 (Sun300iw1p1) SoC, featuring:
- **Dual RISC-V architecture**: Linux (primary core) + FreeRTOS (E907 co-processor for real-time tasks)
- **Target board**: avaota_f1 with NOR flash storage
- **Primary purpose**: Camera/video recording and surveillance applications with multimedia middleware (eyesee-mpp)

## Build Commands

### Configuration
```bash
./build.sh config              # Interactive board/kernel configuration
./build.sh menuconfig          # Configure Linux kernel
./build.sh uboot_menuconfig    # Configure U-Boot bootloader
./build.sh openwrt_menuconfig  # Configure OpenWrt packages
```

### Building Components
```bash
./build.sh brandy              # Build bootloader (U-Boot 2.0)
./build.sh dtb                 # Compile device tree
./build.sh kernel              # Build Linux kernel only
./build.sh rtos                # Build RTOS for E907 core
./build.sh openwrt_rootfs      # Build OpenWrt root filesystem
./build.sh tina                # Build entire system (kernel + rootfs + RTOS)
```

### Packaging & Deployment
```bash
./build.sh pack                # Create flashable firmware image
./build.sh pack_debug          # Create debug firmware with card0 support
```

### Configuration Files
- **Build config**: `.buildconfig` (auto-generated, defines all LICHEE_* environment variables)
- **Board config**: `device/config/chips/v821/configs/avaota_f1/BoardConfig.mk`
- **Quick config**: `device/config/chips/v821/configs/avaota_f1/quick_config.json` (presets for sensors/peripherals)
- **Device tree**: `device/config/chips/v821/configs/avaota_f1/board.dts`
- **Kernel config**: `device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/bsp_defconfig`

## Repository Architecture

### Core System Components
```
/
├── brandy/brandy-2.0/         # U-Boot 2018 bootloader
├── kernel/linux-5.4-ansc/     # Linux 5.4 kernel for RISC-V
├── rtos/lichee/rtos/          # FreeRTOS for E907 (real-time tasks)
│   └── projects/v821_e907_avaota_f1/  # Board-specific RTOS project
├── bsp/                       # Board Support Package
│   ├── drivers/               # 90+ kernel driver categories
│   └── configs/               # Kernel configs and DTSI files
├── device/config/             # Hardware configuration (device trees, board configs)
│   └── chips/v821/configs/avaota_f1/
├── platform/allwinner/        # Allwinner-specific middleware & applications
│   └── eyesee-mpp/            # **CRITICAL**: Camera/multimedia middleware
├── openwrt/                   # OpenWrt build system & packages
├── build/                     # Build orchestration scripts
└── out/                       # Build output directory
```

### eyesee-mpp Middleware Structure

**Location**: `platform/allwinner/eyesee-mpp/`

This is the **primary multimedia processing platform** for camera/video applications:

```
eyesee-mpp/
├── middleware/sun300iw1/      # V821-specific middleware
│   ├── media/                 # Media processing components
│   │   ├── component/         # VI (video input), VENC/VDEC (codecs), ISP, etc.
│   │   ├── videoIn/           # Camera input pipeline
│   │   └── LIBRARY/           # Audio algorithms, ISP tools
│   ├── include/               # Public API headers (MPI_*)
│   ├── config/                # Configuration templates
│   └── sample/                # 50+ sample applications
│       ├── sample_recorder/            # Video recorder
│       ├── sample_smartIPC_demo/       # Full surveillance camera demo
│       ├── sample_virvi2venc2muxer/    # VI→Encoder→Muxer pipeline
│       ├── sample_rtsp/                # RTSP streaming server
│       ├── sample_venc/sample_vdec/    # Video codec samples
│       └── [40+ other samples]
├── framework/sun300iw1/       # Framework layer
└── external/                  # Libraries (civetweb, SQLiteCpp, jsoncpp, lz4)
```

**Key samples**:
- **sample_recorder**: Basic video recording with config file (`sample_recorder.conf`)
- **sample_smartIPC_demo**: Production-ready surveillance application with dual-camera, RTSP, motion detection
- **sample_virvi2venc2muxer**: Standard video capture→encode→mux pipeline

## Hardware Configuration

### Target Platform
- **Chip**: Sun300iw1p1 (V821)
- **Architecture**: Dual RISC-V 32-bit cores
  - Core 1: Main processor (Linux, OpenWrt)
  - Core 2: E907 processor (FreeRTOS, real-time tasks)
- **Board**: avaota_f1
- **Flash**: NOR flash (32MB typical)
- **Camera**: Dual sensor support (gc1084_mipi, gc02m1, gc5035, ov5675, sp5409, etc.)

### Camera Sensors
Located in device tree at `device/config/chips/v821/configs/avaota_f1/board.dts`:

```dts
sensor0: sensor@5812000 {
    sensor0_mname = "gc02m1_mipi";        # Sensor module name
    sensor0_twi_cci_id = <0>;             # I2C bus (TWI0)
    sensor0_twi_addr = <0x6e>;            # I2C address (8-bit)
    sensor0_mclk_id = <0>;                # MCLK clock ID
    sensor0_pos = "rear";                 # Position: "rear" or "front"
    sensor0_reset = <&pio PA 2 GPIO_ACTIVE_LOW>;  # Reset GPIO
};
```

**Adding/changing sensors**:
1. Modify `board.dts` sensor node (sensor0_mname, I2C address, GPIOs)
2. Update `quick_config.json` if using presets
3. Add sensor driver to kernel if needed: `bsp/drivers/vin/modules/sensor/`
4. Rebuild: `./build.sh dtb && ./build.sh kernel && ./build.sh tina`

### Inter-Processor Communication (Linux ↔ RTOS)
- **rpbuf**: Ring buffer communication (`rtos/lichee/rtos-components/aw/rpbuf`)
- **rpmsg**: Remote processor messaging
- **Shared memory**: CMA pools defined in device tree

## Common Development Workflows

### Working with Middleware Samples

**Modifying sample applications**:
```bash
# 1. Edit source code
vim platform/allwinner/eyesee-mpp/middleware/sun300iw1/sample/sample_recorder/sample_recorder.c

# 2. Edit configuration
vim platform/allwinner/eyesee-mpp/middleware/sun300iw1/sample/bin/sample_recorder.conf

# 3. Rebuild (middleware is built as part of openwrt packages)
./build.sh openwrt_rootfs

# 4. Pack and deploy
./build.sh pack
```

**Sample configuration files** are typically in:
- Source: `platform/allwinner/eyesee-mpp/middleware/sun300iw1/sample/sample_*/`
- Binary output: `out/v821/avaota_f1/openwrt/staging_dir/target/usr/bin/`
- Config output: `out/v821/avaota_f1/openwrt/staging_dir/target/etc/`

### Modifying Device Tree

**Workflow**:
```bash
# 1. Edit board device tree
vim device/config/chips/v821/configs/avaota_f1/board.dts

# 2. Compile device tree only (fast)
./build.sh dtb

# 3. Or rebuild kernel (includes DTB compilation)
./build.sh kernel

# 4. Pack firmware
./build.sh pack
```

**Important device tree files**:
- `device/config/chips/v821/configs/avaota_f1/board.dts` - Board-level overrides
- `bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi` - SoC base definitions
- See `Readme/DEVICE_TREE_PARAMETER_GUIDE.md` for detailed parameter reference

### Adding/Modifying Kernel Drivers

**Workflow**:
```bash
# 1. Add/modify driver code
vim bsp/drivers/<category>/<driver>.c

# 2. Configure kernel to enable driver
./build.sh menuconfig

# 3. Save kernel config
./build.sh saveconfig

# 4. Build kernel
./build.sh kernel

# 5. Build everything
./build.sh tina
```

**Driver categories** in `bsp/drivers/`:
- Camera: `vfe/`, `vin/`, `mbus/`
- Video: `video/`, `drm/`, `g2d/`, `ve/`
- Audio: `sound/`
- Interfaces: `uart/`, `twi/` (I2C), `spi/`, `usb/`
- Storage: `mmc/`, `mtd/`, `nand/`
- IPC: `rpbuf/`, `rpmsg/`, `remoteproc/`

### RTOS Development

**Modifying RTOS components**:
```bash
# 1. Edit RTOS code
vim rtos/lichee/rtos-components/<component>/

# 2. Configure RTOS
cd rtos/lichee/rtos
make menuconfig

# 3. Build RTOS
./build.sh rtos

# 4. Build complete firmware
./build.sh tina
```

**RTOS project location**: `rtos/lichee/rtos/projects/v821_e907_avaota_f1/`

## Build System Architecture

**Entry point**: `./build.sh` → `build/top_build.sh` → `build/mkcommon.sh`

**Key build scripts**:
- `mkcommon.sh` - Main orchestrator, parses commands and invokes sub-scripts
- `mkkernel.sh` - Linux kernel compilation
- `bsp.sh` - BSP/independent kernel build
- `mkdts.sh` - Device tree compilation
- `envsetup.sh` - Environment variable setup

**Build output** at `out/v821/avaota_f1/`:
- `openwrt/` - OpenWrt staging & build
- `openwrt/bin/` - Final binaries
- `pack_out/` - Packaged firmware images
- Toolchain: `out/toolchain/nds32le-linux-glibc-v5d/` (RISC-V 32-bit)

## Important Environment Variables

Defined in `.buildconfig`:
```bash
LICHEE_CHIP=sun300iw1p1               # Target chip
LICHEE_IC=v821                        # IC designation
LICHEE_BOARD=avaota_f1                # Board variant
LICHEE_KERNEL_ARCH=riscv              # RISC-V architecture
LICHEE_ARCH=riscv32                   # 32-bit RISC-V
LICHEE_KERN_VER=linux-5.4-ansc        # Kernel version
LICHEE_FLASH=nor                      # Storage type
LICHEE_RTOS_PROJECT_NAME=v821_e907_avaota_f1  # RTOS project
```

## Debugging & Diagnostics

**Diagnostic script**: `diagnose_camera.sh` - Camera system diagnostics

**Device tree debugging**:
```bash
# Compile and check device tree
./build.sh dtb

# Decompile to inspect (on build host)
dtc -I dtb -O dts out/v821/avaota_f1/openwrt/staging_dir/target/boot/*.dtb -o /tmp/check.dts

# Runtime inspection (on device)
ls /proc/device-tree/
cat /proc/device-tree/soc/twi@*/clock-frequency | xxd
```

**Driver logs**:
```bash
# On device
dmesg | grep -i "sensor\|camera\|vin"
dmesg | grep -i "twi\|i2c"
```

See `Readme/PROC_FILESYSTEM_GUIDE.md` for runtime system inspection.

## Code Location Patterns

**Finding code**:
- Kernel drivers: `bsp/drivers/<subsystem>/`
- Middleware APIs: `platform/allwinner/eyesee-mpp/middleware/sun300iw1/include/`
- Sample apps: `platform/allwinner/eyesee-mpp/middleware/sun300iw1/sample/`
- RTOS components: `rtos/lichee/rtos-components/aw/`
- Device configs: `device/config/chips/v821/configs/avaota_f1/`
- Build scripts: `build/`

**Finding parameters/config**:
```bash
# Search device tree parameters
grep -r "of_property_read" bsp/drivers/<driver>.c

# Find sample configs
find platform/allwinner/eyesee-mpp/middleware/sun300iw1/sample/ -name "*.conf"

# Search kernel config options
grep -r "CONFIG_" bsp/drivers/<subsystem>/Kconfig
```

## Notes

- **Architecture**: This is a dual-processor system. Linux handles user applications/networking, while RTOS handles real-time camera ISP tuning and time-critical tasks
- **Middleware**: Most camera application development happens in eyesee-mpp samples, not directly in kernel drivers
- **Quick config**: Use `quick_config.json` for rapid hardware configuration changes (sensor selection, LCD, UART routing) instead of manually editing device tree
- **Build incremental**: Use specific targets (`./build.sh kernel`, `./build.sh dtb`) for faster iteration instead of full `./build.sh tina`
- **Sample configs**: Sample applications read `.conf` text files for runtime configuration (resolution, bitrate, format, etc.)
