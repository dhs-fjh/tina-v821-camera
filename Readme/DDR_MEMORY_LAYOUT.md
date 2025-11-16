# V821 DDR 内存布局详解

## 概览

本文档详细说明 V821 芯片的 64MB DDR 内存是如何分配和使用的。

**重要区别**：
- **DDR 内存 (RAM)**: 运行时内存，断电丢失，配置在**设备树 (board.dts)** 中
- **Flash 存储 (ROM)**: 持久化存储，断电保留，配置在 **sys_partition.fex** 中

---

## DDR 物理内存配置

### 硬件规格

- **芯片**: Allwinner V821 (Sun300iw1p1)
- **DDR 类型**: DDR2/DDR3 (取决于具体型号)
- **物理容量**: **64 MB** (0x4000000)
- **起始地址**: 0x80000000

### 设备树定义

**位置**: `bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi`

```dts
/ {
    memory {
        device_type = "memory";
        reg = <0x0 0x80000000 0x0 0x04000000>;
        //     ↑   ↑ 起始地址   ↑   ↑ 大小
        //     |   |            |   64MB (0x4000000)
        //     |   0x80000000   |
        //     64位地址高32位   64位地址低32位
    };
};
```

**解读**：
- `reg = <0x0 0x80000000 0x0 0x04000000>`
  - 第1-2个数: 起始地址 = 0x80000000
  - 第3-4个数: 大小 = 0x04000000 = 64 MB

---

## DDR 内存完整布局

### 物理地址映射

```
┌────────────────────────── 64 MB DDR (0x80000000 - 0x83FFFFFF) ──────────────────────────┐
│                                                                                          │
│  地址范围                    大小        用途                                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                                                          │
│  0x80000000 - 0x80FBFFFF   15.75 MB    Linux 可用内存（内核 + 用户空间）                 │
│  ┌──────────────────────────────────────────────────────────────────────────────┐      │
│  │ 0x80000000 - 0x807FFFFF    8 MB      内核代码、数据、BSS                       │      │
│  │ 0x80800000 - 0x80FBFFFF   7.75 MB    用户空间可用内存                          │      │
│  └──────────────────────────────────────────────────────────────────────────────┘      │
│                                                                                          │
│  0x80FC0000 - 0x80FFFFFF   256 KB      OpenSBI (RISC-V Supervisor Binary Interface)     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                                                          │
│  0x81000000 - 0x811FFFFF    2 MB       E907 (RTOS) 保留内存                             │
│  ┌──────────────────────────────────────────────────────────────────────────────┐      │
│  │ 0x81000000 - 0x811FFFFF   2 MB       rv_ddr_reserved (RTOS 专用 DDR)          │      │
│  └──────────────────────────────────────────────────────────────────────────────┘      │
│                                                                                          │
│  0x81200000 - 0x8123FFFF   256 KB      rpmsg vdev0 buffer (Linux <-> RTOS 通信)         │
│  0x81240000 - 0x81241FFF    8 KB       vdev0 vring0 (virtio ring buffer)                │
│  0x81242000 - 0x81243FFF    8 KB       vdev0 vring1 (virtio ring buffer)                │
│  0x81244000 - 0x81443FFF    2 MB       E907 固件加载区 (e907_mem_fw)                    │
│  0x81444000 - 0x81445FFF    8 KB       E907 共享中断表 (share_irq_table)                │
│  0x81446000 - 0x8144DFFF   32 KB       E907 rpbuf (ring buffer 通信)                    │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                                                          │
│  0x82000000 - 0x83BFFFFF   28 MB       Linux 普通内存池 (size_pool)                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐      │
│  │ 包含:                                                                         │      │
│  │  - CMA 池: 2 MB (linux,cma)          视频编解码用                             │      │
│  │  - 用户进程内存                                                                │      │
│  │  - 文件缓存 (page cache)                                                      │      │
│  │  - 块设备缓冲 (buffers)                                                       │      │
│  └──────────────────────────────────────────────────────────────────────────────┘      │
│                                                                                          │
│  0x83C00000 - 0x83FFFFFF    4 MB       预留/其他用途                                     │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 详细内存区域说明

### 1. Linux 内核与用户空间 (0x80000000 - 0x80FBFFFF, ~16 MB)

**总大小**: 约 16 MB

**包含**：
- **内核镜像** (zImage/Image): ~2-3 MB
  - 代码段 (.text)
  - 只读数据 (.rodata)
  - 可读写数据 (.data)
  - BSS 段 (.bss)

- **内核数据结构**:
  - 页表 (Page Tables)
  - 进程控制块 (task_struct)
  - 文件描述符表
  - 网络协议栈缓冲区

- **用户空间可用**: ~7-8 MB
  - 进程代码和数据
  - 堆 (malloc/new)
  - 栈 (函数调用栈)

**查看方式**：
```bash
# 查看内核内存使用
cat /proc/meminfo | grep -E "MemTotal|MemFree"

# 查看进程内存
ps aux --sort=-%mem
```

---

### 2. OpenSBI 区域 (0x80FC0000 - 0x80FFFFFF, 256 KB)

**定义位置**: `sun300iw1p1.dtsi`
```dts
/memreserve/ 0x80fc0000 0x40000; /* opensbi */
```

**用途**:
- **OpenSBI** (Open Source Supervisor Binary Interface)
- RISC-V 架构的固件层
- 提供 SBI 调用接口（类似 x86 的 BIOS）
- 处理 M-mode (机器模式) 的异常和中断

**特点**:
- 🔒 运行在最高权限 M-mode
- 🔒 Linux 内核运行在 S-mode，通过 SBI 调用访问硬件
- 🔒 此区域内存不可被 Linux 使用

---

### 3. E907 RTOS 保留区 (0x81000000 - 0x8164DFFF, ~6.3 MB)

V821 是**双核异构处理器**：
- **A27 核心**: 运行 Linux
- **E907 核心**: 运行 FreeRTOS

**详细分配**：

#### a) RTOS DDR 保留 (0x81000000 - 0x811FFFFF, 2 MB)
```dts
rv_ddr_reserved: rvddrreserved@81000000 {
    reg = <0x0 0x81000000 0x0 0x200000>;  /* 2 MB */
    no-map;  /* Linux 不能访问 */
};
```
- **用途**: E907 核心的运行内存
- **内容**: RTOS 堆、栈、全局变量

#### b) RPMsg 通信缓冲区 (0x81200000 - 0x8123FFFF, 256 KB)
```dts
rv_vdev0buffer: vdev0buffer@81200000 {
    compatible = "shared-dma-pool";
    reg = <0x0 0x81200000 0x0 0x40000>;  /* 256 KB */
    no-map;
};
```
- **用途**: Linux 与 RTOS 之间的消息传递缓冲区
- **协议**: RPMsg (Remote Processor Messaging)

#### c) VirtIO Ring 缓冲区 (0x81240000 - 0x81243FFF, 16 KB)
```dts
rv_vdev0vring0: vdev0vring0@81240000 {
    reg = <0x0 0x81240000 0x0 0x2000>;  /* 8 KB */
    no-map;
};

rv_vdev0vring1: vdev0vring1@81242000 {
    reg = <0x0 0x81242000 0x0 0x2000>;  /* 8 KB */
    no-map;
};
```
- **用途**: VirtIO 传输层的环形缓冲区
- **方向**: vring0 (Linux→RTOS), vring1 (RTOS→Linux)

#### d) E907 固件加载区 (0x81244000 - 0x81443FFF, 2 MB)
```dts
e907_mem_fw: e907_mem_fw@81244000 {
    /* boot0 & uboot0 load elf addr */
    reg = <0x0 0x81244000 0x0 0x00200000>;  /* 2 MB */
};
```
- **用途**: 存放 E907 RTOS 固件 (amp_rv0.fex)
- **加载**: U-Boot 从 Flash 加载到此地址
- **执行**: E907 核心从此地址启动

#### e) 共享中断表 (0x81644000 - 0x81645FFF, 8 KB)
```dts
e907_share_irq_table: share_irq_table@81644000 {
    reg = <0x0 0x81644000 0x0 0x2000>;  /* 8 KB */
    no-map;
};
```
- **用途**: Linux 和 RTOS 之间共享的中断路由表

#### f) RPBuf (0x81646000 - 0x8164DFFF, 32 KB)
```dts
e907_rpbuf_reserved:e907_rpbuf@81646000 {
    compatible = "shared-dma-pool";
    reg = <0x0 0x81646000 0x0 0x8000>;  /* 32 KB */
    no-map;
};
```
- **用途**: Ring Buffer 通信（另一种 IPC 机制）

---

### 4. Linux 普通内存池 (0x82000000 - 0x83BFFFFF, 28 MB)

```dts
size_pool {
    reg = <0 0x82000000 0 0x01C00000>;  /* 28 MB */
};
```

**用途**：
- 用户进程内存分配
- 页缓存 (page cache)
- 块设备缓冲 (buffers)
- 网络缓冲区
- CMA 池（从此区域分配）

#### CMA (Contiguous Memory Allocator)

**板级配置** (`board.dts`):
```dts
linux,cma {
    size = <0x0 0x200000>;  /* 2 MB */
};
```

**基础配置** (`sun300iw1p1.dtsi`):
```dts
linux,cma {
    compatible = "shared-dma-pool";
    reusable;
    size = <0x0 0x1000000>;  /* 16 MB (默认值，可被 board.dts 覆盖) */
    alignment = <0x0 0x2000>;
    linux,cma-default;
};
```

**实际生效**: 2 MB (板级配置覆盖了基础配置)

**用途**：
- 视频编码器 (VENC) 输入/输出缓冲
- 视频解码器 (VDEC) 输入/输出缓冲
- ISP (图像信号处理器) 缓冲
- G2D (2D 图形加速器) 缓冲

**特点**：
- ✅ **可重用**: 未使用时可被普通内存使用
- ✅ **连续物理内存**: 满足 DMA 设备要求
- 🎥 **专用**: 优先给多媒体设备分配

**查看 CMA 使用**：
```bash
cat /proc/meminfo | grep Cma
# 输出:
# CmaTotal:           2048 kB
# CmaFree:            1992 kB
```

---

## 内存使用总结

### 内存分配表

| 地址范围 | 大小 | 用途 | Linux 可用 | 说明 |
|---------|------|------|-----------|------|
| 0x80000000 - 0x80FBFFFF | ~16 MB | Linux 内核 + 用户空间 | ✅ 部分 | 内核占用约 8MB |
| 0x80FC0000 - 0x80FFFFFF | 256 KB | OpenSBI | ❌ | RISC-V 固件 |
| 0x81000000 - 0x8164DFFF | ~6.3 MB | E907 RTOS + IPC | ❌ | RTOS 专用 |
| 0x82000000 - 0x83BFFFFF | 28 MB | Linux 内存池 | ✅ 是 | 用户主要使用区 |
| 0x83C00000 - 0x83FFFFFF | 4 MB | 预留 | - | 其他用途 |
| **总计** | **64 MB** | | ~25 MB | |

### 为什么 `free -h` 只显示 25 MB？

```bash
free -h
              total        used        free
Mem:          25468        9992        3184
```

**计算**：
```
物理 DDR 总量:     64 MB
- OpenSBI:       -0.25 MB
- E907 RTOS:     -6.3 MB
- 内核代码/数据:   -8 MB
- 其他保留:       -4 MB
- 页表/内核结构:   -20 MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
= 用户可见内存:    ~25 MB
```

**详细分解**：
1. **64 MB** - 物理 DDR
2. **-0.25 MB** - OpenSBI 保留
3. **-6.3 MB** - E907 RTOS 保留
4. **-8 MB** - Linux 内核镜像
5. **-20 MB** - 内核数据结构（页表、slab、栈等）
6. **-4 MB** - 其他保留区
7. **= ~25 MB** - 用户空间可用

---

## 如何查看实际内存布局

### 1. 查看设备树定义

```bash
# 在设备上查看编译后的设备树
ls /proc/device-tree/

# 查看内存节点
ls /proc/device-tree/memory/
cat /proc/device-tree/memory/reg | hexdump -C

# 查看保留内存
ls /proc/device-tree/reserved-memory/
```

### 2. 查看内核启动日志

```bash
dmesg | grep -i "memory\|ddr\|cma"
```

**示例输出**：
```
[    0.000000] Memory: 25468K/65536K available
               (2048K kernel code, 256K rwdata, 512K rodata,
                1024K init, 256K bss, 40068K reserved, 2048K cma-reserved)
[    0.000000] cma: Reserved 2 MiB at 0x82000000
[    0.000000] rpmsg: reserved memory region at 0x81200000 (256KB)
```

**解读**：
- `65536K` = 64 MB: 物理 DDR 总量
- `25468K` = 24.87 MB: 用户可用内存
- `40068K` = 39.13 MB: 保留内存（OpenSBI + RTOS + 内核）
- `2048K` = 2 MB: CMA 保留

### 3. 查看内存信息

```bash
# 总体内存
cat /proc/meminfo | head -30

# CMA 内存
cat /proc/meminfo | grep Cma

# 内核内存
cat /proc/meminfo | grep -E "Slab|KReclaimable|Kernel"
```

### 4. 查看 /proc/iomem

```bash
cat /proc/iomem
```

**示例输出**：
```
80000000-83ffffff : System RAM
  80000000-807fffff : Kernel code
  80800000-808fffff : Kernel data
  80fc0000-80ffffff : reserved (OpenSBI)
  81000000-8164dfff : reserved (E907)
  82000000-83bfffff : System RAM
```

---

## 内存配置修改

### 修改 CMA 大小

**位置**: `device/config/chips/v821/configs/avaota_f1/board.dts`

```dts
reserved-memory {
    linux,cma {
        size = <0x0 0x400000>;  /* 改为 4 MB */
    };
};
```

**注意**：
- CMA 越大，视频处理能力越强（可处理更高分辨率）
- CMA 越大，普通内存越少
- 推荐：2-4 MB

### 修改 E907 RTOS 内存

**位置**: `device/config/chips/v821/configs/avaota_f1/board.dts`

```dts
rv_ddr_reserved: rvddrreserved@81000000 {
    reg = <0x0 0x81000000 0x0 0x400000>;  /* 改为 4 MB */
    no-map;
};
```

**注意**：需要同步修改 RTOS 端的内存映射配置。

### 重新编译

```bash
# 修改设备树后重新编译
./build.sh dtb
./build.sh kernel
./build.sh tina
./build.sh pack
```

---

## DDR vs Flash 对比总结

| 特性 | DDR 内存 | NOR Flash |
|-----|---------|-----------|
| **容量** | 64 MB | 32 MB |
| **类型** | 易失性 RAM | 非易失性 ROM |
| **速度** | 极快 (~800 MB/s) | 慢 (~20 MB/s) |
| **用途** | 程序运行 | 数据存储 |
| **断电** | 数据丢失 | 数据保留 |
| **配置文件** | **board.dts** | **sys_partition.fex** |
| **查看命令** | `free -h` | `df -h` |
| **分区信息** | `/proc/iomem` | `/proc/mtd` |
| **内容** | 进程、缓存、CMA | 内核、rootfs、配置 |

---

## 常见问题

### Q1: 为什么 DDR 是 64MB，而可用内存只有 25MB？

**A**: 64MB 物理 DDR 被分为多个部分：
- OpenSBI: 256 KB
- E907 RTOS: 6.3 MB
- Linux 内核: 8 MB
- 内核数据结构: 20 MB
- 其他保留: 4 MB
- **剩余给用户**: 25 MB

### Q2: sys_partition.fex 能修改 DDR 大小吗？

**A**: 不能！`sys_partition.fex` 只管理 Flash 分区，不涉及 DDR。
- **DDR 配置**: 在设备树 `board.dts` 中
- **Flash 配置**: 在 `sys_partition.fex` 中

### Q3: 如何增加可用内存？

**A**: 有限的选项：
1. ✅ **减小 CMA 大小**（如果不需要高分辨率视频）
2. ✅ **优化内核配置**（去除不必要的驱动）
3. ❌ **不能减小 RTOS 保留**（会导致 RTOS 无法运行）
4. ❌ **不能减小 OpenSBI**（系统无法启动）

### Q4: CMA 内存为什么显示空闲但不能用？

**A**: CMA 内存是**可重用的**：
- 当视频设备需要时，CMA 专用
- 当视频设备空闲时，可被普通内存使用
- 已经计入 `MemAvailable`

### Q5: E907 RTOS 内存能被 Linux 使用吗？

**A**: 不能！这些区域标记为 `no-map`，Linux 无法访问：
```dts
rv_ddr_reserved: rvddrreserved@81000000 {
    reg = <0x0 0x81000000 0x0 0x200000>;
    no-map;  /* Linux 禁止访问 */
};
```

---

## 相关文档

- [MEMORY_MANAGEMENT.md](MEMORY_MANAGEMENT.md) - 内存使用管理和监控
- [FLASH_PARTITION_LAYOUT.md](FLASH_PARTITION_LAYOUT.md) - Flash 分区布局
- [DISK_SPACE_MANAGEMENT.md](DISK_SPACE_MANAGEMENT.md) - 磁盘空间管理
- [DEVICE_TREE_PARAMETER_GUIDE.md](DEVICE_TREE_PARAMETER_GUIDE.md) - 设备树参数指南

---

**更新日期**：2025-01-16
