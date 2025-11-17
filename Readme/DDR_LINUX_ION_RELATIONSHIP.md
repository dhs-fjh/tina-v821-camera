# DDR 内存分配：Linux vs ION 关系详解

## 概览

本文档详细说明 V821 系统中 DDR 内存如何在 Linux 运行内存和 ION 多媒体内存之间划分，以及如何根据应用需求调整配置。

**核心理解**：
- 物理 DDR 在启动时被**固定划分**为多个区域
- Linux 可用内存（top 显示）和 ION 堆（size_pool）是**独立**的
- 增大 ION 分配 → Linux 可用内存减少（反之亦然）

---

## 物理 DDR 内存完整划分

### 硬件配置

- **物理 DDR 总量**: 64 MB
- **DDR 类型**: DDR2/DDR3 (RISC-V 32-bit)
- **起始地址**: 0x80000000

### 完整内存布局

```
┌─────────────────────────── 64 MB 物理 DDR ───────────────────────────┐
│                                                                       │
│  地址范围                      大小        说明                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                                       │
│  0x80000000 - 0x80FBFFFF     ~16 MB     Linux 内核 + 初始内存       │
│  0x80FC0000 - 0x80FFFFFF     256 KB     OpenSBI (RISC-V 固件)       │
│  0x81000000 - 0x8164DFFF     6.3 MB     E907 RTOS 保留区            │
│  0x82000000 - 0x835FFFFF     20 MB      size_pool (ION 堆)          │ ← 可调整
│  0x83600000 - 0x837FFFFF     2 MB       CMA (可重用)                 │ ← 可调整
│  剩余部分                     ~9 MB      Linux 可用内存池             │
│                                                                       │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                                       │
│  Linux 可见总内存 (top 显示):  ~25 MB                                │
│  ION size_pool (独立管理):     20 MB                                 │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Linux 内存 vs ION 内存

### 1. Linux 运行内存（top/free 显示）

**查看命令**：
```bash
top
# 或
free -h
```

**示例输出**：
```
Mem: 15284K used, 10184K free, 8K shrd, 980K buff, 2284K cached
     ↑            ↑
     已用         空闲

总计: 15284 + 10184 = 25468K ≈ 25 MB
```

**包含内容**：
- ✅ 用户进程内存（堆、栈、代码段）
- ✅ 内核数据结构（页表、slab、task_struct）
- ✅ 文件缓存（page cache）
- ✅ 块设备缓冲（buffers）
- ✅ 网络缓冲区
- ✅ CMA 空闲部分（可重用）
- ❌ **不包含** ION size_pool

**来源**：
```
MemTotal: 25468 kB  ← /proc/meminfo
```

### 2. ION 多媒体内存（size_pool）

**查看命令**：
```bash
cat /sys/kernel/debug/ion/size_pool/num_of_alloc_bytes
```

**配置位置**：
```
device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts
```

**定义**：
```dts
reserved-memory {
    size_pool {
        reg = <0 0x82000000 0 0x01C00000>;  /* 28 MB */
    };
}

heap_size_pool@0 {
    compatible = "allwinner,size_pool";
    heap-name = "size_pool";
    heap-id = <0x7>;
    heap-base = <0x82000000>;
    heap-size = <0x01400000>;              /* 20 MB */
    heap-type = "ion_size_pool";
    thrs = <100>;
    sizes = <0 20480>;
    fall_to_big_pool = <1>;
};
```

**包含内容**：
- ✅ 摄像头视频帧缓冲
- ✅ 视频编码器输入/输出缓冲
- ✅ ISP 图像处理缓冲
- ✅ 显示控制器缓冲
- ✅ 其他多媒体 DMA 缓冲
- ❌ **不包含** 普通进程内存

---

## 内存分配关系

### 关键原则

**1. 固定划分，互不影响**

```
启动时划分（设备树定义）:
┌─────────────────────────────────────────────┐
│             64 MB DDR                       │
├─────────────────┬───────────────────────────┤
│  Linux: 25 MB   │   size_pool: 20 MB       │
│  (可变内容)     │   (可变内容)              │
│  ↕ 使用量变化   │   ↕ 使用量变化            │
│                 │                           │
│  边界固定 ◄─────┼──────► 边界固定           │
└─────────────────┴───────────────────────────┘
         ▲                    ▲
         │                    │
    不能越界              不能越界
```

**2. 增大 ION → 减少 Linux**

修改前：
```
size_pool: 20 MB  →  Linux: 25 MB
```

修改后（增大 size_pool 到 30 MB）：
```
size_pool: 30 MB  →  Linux: 15 MB  (减少了 10 MB)
```

**计算公式**：
```
Linux 可用内存 ≈ 64 MB - size_pool - RTOS - OpenSBI - 内核开销
                ≈ 64 - size_pool - 6 - 0.25 - 12
                ≈ 45.75 - size_pool
```

### 实际示例

| size_pool 配置 | heap_size_pool | Linux MemTotal | 说明 |
|---------------|----------------|----------------|------|
| 28 MB | 20 MB | ~25 MB | **当前配置** |
| 38 MB | 30 MB | ~15 MB | 更多 ION，更少 Linux |
| 18 MB | 10 MB | ~35 MB | 更少 ION，更多 Linux |
| 28 MB | 28 MB | ~25 MB | **推荐**（充分利用保留区） |

---

## size_pool vs heap_size_pool

### 两者的关系

```
┌────────────────────────────────────────────────┐
│  size_pool (reserved-memory)                  │
│  定义保留区域: 28 MB                           │
│  ┌──────────────────────────────────────────┐ │
│  │  heap_size_pool (ION 配置)               │ │
│  │  ION 实际使用: 20 MB                     │ │
│  │                                          │ │
│  │  [ION 管理的内存]                        │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  [剩余 8 MB - 可能被 CMA 或 Linux 使用]        │
└────────────────────────────────────────────────┘
```

### 为什么有差异？

**当前配置**：
- `size_pool`: 28 MB (0x01C00000) - 保留整块区域
- `heap_size_pool`: 20 MB (0x01400000) - ION 实际使用

**差异**: 8 MB (28 - 20 = 8 MB)

**可能原因**：
1. 为 CMA 预留空间（2 MB 从这里分配）
2. 为未来扩展预留
3. 历史配置遗留

### 可以设置为一样吗？

**答案：完全可以！**

**推荐配置**（充分利用）：
```dts
reserved-memory {
    size_pool {
        reg = <0 0x82000000 0 0x01C00000>;  /* 28 MB */
    };
}

heap_size_pool@0 {
    heap-base = <0x82000000>;
    heap-size = <0x01C00000>;              /* 28 MB (与 size_pool 相同) */
    ...
};
```

**优点**：
- ✅ 充分利用保留内存
- ✅ 避免浪费 8 MB
- ✅ 为摄像头应用提供更多缓冲区

---

## 针对摄像头应用的优化配置

### 场景分析

**你的需求**：
- 主要用途：摄像头录像
- 不需要运行大量 Linux 进程
- 需要更多视频缓冲区

### 推荐配置方案

#### 方案 1：保守（当前配置）

```dts
size_pool {
    reg = <0 0x82000000 0 0x01C00000>;     /* 28 MB */
};

heap_size_pool@0 {
    heap-base = <0x82000000>;
    heap-size = <0x01400000>;              /* 20 MB */
};
```

**结果**：
- ION: 20 MB
- Linux: ~25 MB
- 适合：基础摄像头 + 少量进程

#### 方案 2：充分利用（推荐）

```dts
size_pool {
    reg = <0 0x82000000 0 0x01C00000>;     /* 28 MB */
};

heap_size_pool@0 {
    heap-base = <0x82000000>;
    heap-size = <0x01C00000>;              /* 28 MB (与 size_pool 相同) */
};
```

**结果**：
- ION: 28 MB (+8 MB)
- Linux: ~25 MB (不变)
- 适合：摄像头 + 更多缓冲 + 高分辨率

#### 方案 3：激进（最大化 ION）

```dts
size_pool {
    reg = <0 0x82000000 0 0x02800000>;     /* 40 MB */
};

heap_size_pool@0 {
    heap-base = <0x82000000>;
    heap-size = <0x02800000>;              /* 40 MB */
};
```

**结果**：
- ION: 40 MB (+20 MB)
- Linux: ~13 MB (-12 MB)
- 适合：纯摄像头应用，极少进程

**⚠️ 警告**：Linux 内存太少可能导致：
- 系统不稳定
- 无法运行额外服务
- OOM (Out of Memory) 杀进程

### 不同分辨率的内存需求

**单帧大小计算**：
```
1920x1080 @ YUV420 = 1920 * 1080 * 1.5 = 3,110,400 bytes ≈ 3 MB
1280x720  @ YUV420 = 1280 * 720  * 1.5 = 1,382,400 bytes ≈ 1.35 MB
640x480   @ YUV420 = 640  * 480  * 1.5 =   460,800 bytes ≈ 0.45 MB
```

**缓冲区需求**（假设 5 个帧缓冲）：
```
1920x1080: 3 MB * 5 = 15 MB
1280x720:  1.35 MB * 5 = 6.75 MB
640x480:   0.45 MB * 5 = 2.25 MB
```

**推荐配置**：
| 分辨率 | 最小 ION | 推荐 ION | 配置方案 |
|--------|---------|---------|---------|
| 640x480 | 5 MB | 10 MB | 方案 1 (20 MB) ✓ |
| 1280x720 | 10 MB | 15 MB | 方案 1 (20 MB) ✓ |
| 1920x1080 | 20 MB | 30 MB | 方案 2 (28 MB) 或方案 3 (40 MB) |

---

## 修改配置步骤

### 1. 备份原始配置

```bash
cd /home/f/tina/tina-v821-camera
cp device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts \
   device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts.bak
```

### 2. 编辑设备树

```bash
vim device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts
```

#### 修改 size_pool（如果需要扩大）

找到（约第 84 行）：
```dts
reserved-memory {
    size_pool {
        reg = <0 0x82000000 0 0x01C00000>;  /* 28 MB */
    };
}
```

**如果要扩大到 40 MB**：
```dts
reserved-memory {
    size_pool {
        reg = <0 0x82000000 0 0x02800000>;  /* 40 MB (0x2800000) */
    };
}
```

#### 修改 heap_size_pool

找到（约第 128 行）：
```dts
heap_size_pool@0 {
    compatible = "allwinner,size_pool";
    heap-name = "size_pool";
    heap-id = <0x7>;
    heap-base = <0x82000000>;
    heap-size = <0x01400000>;              /* 20 MB */
    heap-type = "ion_size_pool";
    thrs = <100>;
    sizes = <0 20480>;
    fall_to_big_pool = <1>;
};
```

**推荐修改 1**（充分利用当前保留区）：
```dts
heap_size_pool@0 {
    ...
    heap-size = <0x01C00000>;              /* 28 MB (与 size_pool 相同) */
    ...
};
```

**推荐修改 2**（如果扩大了 size_pool）：
```dts
heap_size_pool@0 {
    ...
    heap-size = <0x02800000>;              /* 40 MB (与 size_pool 相同) */
    ...
};
```

### 3. 重新编译

```bash
# 编译设备树
./build.sh dtb

# 编译内核
./build.sh kernel

# 编译完整系统
./build.sh tina

# 打包固件
./build.sh pack
```

### 4. 烧录固件

```bash
# 烧录方法取决于你的工具
# 例如：使用 PhoenixSuit 或其他烧录工具
```

### 5. 验证配置

启动后验证：

```bash
# 1. 检查 Linux 可用内存
free -h
cat /proc/meminfo | grep MemTotal

# 2. 检查 size_pool 堆大小
cat /sys/kernel/debug/ion/heaps
# 应该看到 size_pool 堆

# 3. 检查物理内存映射
cat /proc/iomem | grep 82000000

# 4. 运行摄像头应用测试
sample_recorder &

# 5. 查看 ION 使用情况
cat /sys/kernel/debug/ion/size_pool/num_of_alloc_bytes
```

---

## 配置对比表

### 内存分配对比

| 配置 | size_pool | heap_size_pool | Linux MemTotal | 浪费 | 适用场景 |
|-----|-----------|----------------|----------------|------|---------|
| **当前** | 28 MB | 20 MB | ~25 MB | 8 MB | 通用 |
| **优化 1** | 28 MB | 28 MB | ~25 MB | 0 MB | ✅ 推荐（摄像头） |
| **优化 2** | 40 MB | 40 MB | ~13 MB | 0 MB | 高分辨率摄像头 |
| **优化 3** | 20 MB | 20 MB | ~33 MB | 0 MB | 更多 Linux 进程 |

### 大小计算工具

**十六进制转换**：
```
20 MB = 0x01400000
28 MB = 0x01C00000
30 MB = 0x01E00000
40 MB = 0x02800000
50 MB = 0x03200000
```

**在线计算**：
```bash
# MB 转十六进制
echo "obase=16; 28*1024*1024" | bc
# 输出: 1C00000

# 十六进制转 MB
echo "ibase=16; 1C00000" | bc
# 输出: 29360128 (bytes)
echo "29360128 / 1024 / 1024" | bc
# 输出: 28 (MB)
```

---

## 监控与诊断

### 完整监控脚本

```bash
#!/bin/sh
# /mnt/UDISK/scripts/memory_balance_check.sh

echo "=========================================="
echo "  Linux vs ION 内存分配监控"
echo "=========================================="
echo ""

# 1. Linux 内存
echo "=== Linux 内存 (top/free) ==="
MEM_TOTAL=$(cat /proc/meminfo | awk '/MemTotal/ {print $2}')
MEM_FREE=$(cat /proc/meminfo | awk '/MemFree/ {print $2}')
MEM_AVAIL=$(cat /proc/meminfo | awk '/MemAvailable/ {print $2}')
MEM_USED=$((MEM_TOTAL - MEM_FREE))

echo "总内存:   $((MEM_TOTAL / 1024)) MB ($MEM_TOTAL KB)"
echo "已使用:   $((MEM_USED / 1024)) MB ($MEM_USED KB)"
echo "可用:     $((MEM_AVAIL / 1024)) MB ($MEM_AVAIL KB)"
echo "使用率:   $((MEM_USED * 100 / MEM_TOTAL))%"
echo ""

# 2. ION size_pool
echo "=== ION size_pool 内存 ==="
if [ -f /sys/kernel/debug/ion/size_pool/num_of_alloc_bytes ]; then
    ION_ALLOC=$(cat /sys/kernel/debug/ion/size_pool/num_of_alloc_bytes)
    ION_WM=$(cat /sys/kernel/debug/ion/size_pool/alloc_bytes_wm)
    ION_BUFS=$(cat /sys/kernel/debug/ion/size_pool/num_of_buffers)

    # 从设备树读取配置（假设 28 MB）
    ION_TOTAL=$((28 * 1024 * 1024))

    echo "配置大小: 28 MB ($ION_TOTAL bytes)"
    echo "已分配:   $((ION_ALLOC / 1024 / 1024)) MB ($ION_ALLOC bytes)"
    echo "峰值:     $((ION_WM / 1024 / 1024)) MB ($ION_WM bytes)"
    echo "缓冲区数: $ION_BUFS"
    echo "使用率:   $(awk "BEGIN {printf \"%.2f\", $ION_ALLOC*100/$ION_TOTAL}")%"
else
    echo "无法访问 ION 信息"
fi
echo ""

# 3. CMA
echo "=== CMA (可重用) ==="
CMA_TOTAL=$(cat /proc/meminfo | awk '/CmaTotal/ {print $2}')
CMA_FREE=$(cat /proc/meminfo | awk '/CmaFree/ {print $2}')
CMA_USED=$((CMA_TOTAL - CMA_FREE))
echo "总量:     $((CMA_TOTAL / 1024)) MB ($CMA_TOTAL KB)"
echo "已用:     $((CMA_USED / 1024)) MB ($CMA_USED KB)"
echo "空闲:     $((CMA_FREE / 1024)) MB ($CMA_FREE KB)"
echo ""

# 4. 总览
echo "=== 内存使用总览 ==="
echo "物理 DDR 总量:     64 MB"
echo "├─ Linux 可用:     $((MEM_TOTAL / 1024)) MB"
echo "├─ ION size_pool:  28 MB (配置)"
echo "├─ CMA:            $((CMA_TOTAL / 1024)) MB"
echo "├─ RTOS:           6 MB"
echo "└─ 其他保留:       ~$(( 64 - MEM_TOTAL/1024 - 28 - CMA_TOTAL/1024 - 6 )) MB"
echo ""

# 5. 健康检查
echo "=== 健康状态 ==="
if [ $((MEM_AVAIL * 100 / MEM_TOTAL)) -lt 10 ]; then
    echo "🔴 警告: Linux 可用内存不足 10%"
elif [ $((MEM_AVAIL * 100 / MEM_TOTAL)) -lt 20 ]; then
    echo "🟡 注意: Linux 可用内存低于 20%"
else
    echo "✅ Linux 内存正常"
fi

if [ -f /sys/kernel/debug/ion/size_pool/num_of_alloc_bytes ]; then
    if [ $(awk "BEGIN {print ($ION_ALLOC*100/$ION_TOTAL > 80)}") -eq 1 ]; then
        echo "🟡 注意: ION size_pool 使用超过 80%"
    else
        echo "✅ ION size_pool 正常"
    fi
fi

echo ""
echo "=========================================="
echo "检查完成 - $(date)"
echo "=========================================="
```

**使用方法**：
```bash
cat > /mnt/UDISK/scripts/memory_balance_check.sh << 'EOF'
# (上面的脚本)
EOF
chmod +x /mnt/UDISK/scripts/memory_balance_check.sh
/mnt/UDISK/scripts/memory_balance_check.sh
```

---

## 常见问题

### Q1: size_pool 和 heap_size_pool 必须一样大吗？

**A**: 不必须，但**推荐一样**。

- `size_pool` 保留内存区域
- `heap_size_pool` 实际使用大小
- heap_size_pool ≤ size_pool
- 如果不相等，差额会被浪费（除非被 CMA 使用）

### Q2: 我增大 ION 后，Linux 内存不够用怎么办？

**A**: 需要权衡：

**选项 1**: 减小 ION
```dts
heap-size = <0x01000000>;  /* 16 MB */
```

**选项 2**: 优化 Linux 应用
- 减少运行的进程
- 使用 tmpfs 而非磁盘缓存
- 卸载不必要的内核模块

**选项 3**: 升级硬件
- 使用 128 MB DDR 版本的芯片

### Q3: 如何判断 ION 大小是否合适？

**A**: 运行摄像头应用，观察 ION 使用率：

```bash
# 启动摄像头
sample_recorder &

# 查看使用情况
cat /sys/kernel/debug/ion/size_pool/num_of_alloc_bytes

# 理想状态：使用率 30-70%
# < 30%: ION 过大，可以减小
# > 80%: ION 不足，应该增大
```

### Q4: 修改后无法启动怎么办？

**A**:

1. **检查语法**：
```bash
# 编译前检查设备树语法
./build.sh dtb
# 看是否有错误
```

2. **恢复备份**：
```bash
cp device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts.bak \
   device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts
```

3. **不要过度减少 Linux 内存**：
   - 最少保留 15 MB 给 Linux
   - 否则系统可能无法启动

### Q5: size_pool 地址可以改吗？

**A**: 可以，但**不推荐**。

如果修改地址，需要：
1. 修改 `reserved-memory` 中的 `reg`
2. 修改 `heap_size_pool@0` 中的 `heap-base`
3. 确保不与其他保留区重叠
4. 确保在有效的 DDR 地址范围内

---

## 总结

### 关键要点

1. ✅ **DDR 固定划分**：Linux 内存 + ION 内存 + 其他保留 = 64 MB
2. ✅ **互相排斥**：增大 ION → 减少 Linux（反之亦然）
3. ✅ **可以相同**：size_pool 和 heap_size_pool 建议设为相同大小
4. ✅ **摄像头优先**：如果只用摄像头，可以增大 ION，减少 Linux

### 推荐配置（仅摄像头应用）

```dts
reserved-memory {
    size_pool {
        reg = <0 0x82000000 0 0x01C00000>;  /* 28 MB */
    };
}

heap_size_pool@0 {
    heap-base = <0x82000000>;
    heap-size = <0x01C00000>;              /* 28 MB (与 size_pool 相同) */
    heap-type = "ion_size_pool";
    thrs = <100>;
    sizes = <0 20480>;
    fall_to_big_pool = <1>;
};
```

**结果**：
- ION: 28 MB (比默认多 8 MB)
- Linux: ~25 MB (不变)
- 浪费: 0 MB

### 配置选择矩阵

| 应用场景 | size_pool | heap_size_pool | Linux 内存 |
|---------|-----------|----------------|-----------|
| **纯摄像头（推荐）** | 28 MB | 28 MB | ~25 MB |
| **摄像头 + 少量进程** | 28 MB | 20 MB | ~25 MB |
| **摄像头 + 更多进程** | 20 MB | 20 MB | ~33 MB |
| **高分辨率摄像头** | 40 MB | 40 MB | ~13 MB |

---

**相关文档**：
- [DDR_MEMORY_LAYOUT.md](DDR_MEMORY_LAYOUT.md) - DDR 完整布局
- [ION_MEMORY_MANAGEMENT.md](ION_MEMORY_MANAGEMENT.md) - ION 详细说明
- [MEMORY_MANAGEMENT.md](MEMORY_MANAGEMENT.md) - 内存管理指南

**更新日期**：2025-01-16
