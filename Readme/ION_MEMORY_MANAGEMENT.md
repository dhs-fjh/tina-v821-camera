# ION 内存管理与 size_pool 详解

## 概览

本文档详细解释 V821 系统中的 `size_pool` 内存区域和 ION 内存管理器的工作原理。

**关键概念**：
- **size_pool**: 设备树中定义的 28MB 内存区域（0x82000000 - 0x83BFFFFF）
- **ION**: Android/Linux 多媒体内存分配框架
- **用途**: 为视频编解码、摄像头、显示等提供高效的 DMA 缓冲区管理

---

## size_pool 是什么？

### 设备树定义

**位置**: `device/config/chips/v821/configs/avaota_f1/board.dts`

```dts
reserved-memory {
    size_pool {
        reg = <0 0x82000000 0 0x01C00000>;  /* 28 MB */
    };
};
```

**解读**：
- **起始地址**: 0x82000000
- **大小**: 0x01C00000 = 28 MB
- **说明**: 这是一个**自定义节点**，不是 Linux 内核标准的保留内存类型

### ION 堆配置

同一个内存区域还被配置为 ION 堆：

```dts
ion-heap {
    heap-base = <0x82000000>;      /* ION 堆起始地址（与 size_pool 相同） */
    heap-size = <0x01400000>;      /* 20 MB ION 堆大小 */
    heap-type = "ion_size_pool";   /* 堆类型：size_pool 类型 */
    thrs = <100>;                  /* 小内存分配阈值：100 KB */
    sizes = <0 20480>;             /* 内存池大小配置 */
    fall_to_big_pool = <1>;        /* 失败时回退到大池 */
};
```

**关键参数说明**：

| 参数 | 值 | 说明 |
|-----|---|------|
| **heap-base** | 0x82000000 | ION 堆起始地址 |
| **heap-size** | 0x01400000 (20 MB) | ION 堆大小（比 size_pool 小 8MB） |
| **heap-type** | ion_size_pool | ION 堆类型 |
| **thrs** | 100 (KB) | 小内存分配阈值，<100KB 从小池分配 |
| **sizes** | 0 20480 | 两个内存池：0 和 20480 KB |
| **fall_to_big_pool** | 1 | 小池分配失败时回退到大池 |

---

## ION 内存管理器

### 什么是 ION？

**ION** (Ion Memory Manager) 是 Android/Linux 系统中用于多媒体应用的内存分配器，特别适合需要 DMA (直接内存访问) 的设备。

```
┌─────────────────────────────────────────────────────────┐
│                    应用程序                              │
│        (摄像头应用、录像程序、视频播放器)                 │
└──────────────────┬──────────────────────────────────────┘
                   │ 申请连续物理内存
                   ↓
┌─────────────────────────────────────────────────────────┐
│                 ION 内存管理器                           │
│  ┌──────────────┬──────────────┬──────────────────┐    │
│  │ size_pool堆  │   CMA 堆     │   system 堆      │    │
│  │  (20 MB)     │   (2 MB)     │  (buddy分配器)   │    │
│  └──────────────┴──────────────┴──────────────────┘    │
└──────────────────┬──────────────────────────────────────┘
                   │ 分配连续物理内存
                   ↓
┌─────────────────────────────────────────────────────────┐
│              硬件设备 (DMA)                              │
│   摄像头、视频编码器、视频解码器、显示控制器              │
└─────────────────────────────────────────────────────────┘
```

### ION 的优势

1. ✅ **连续物理内存**: 满足 DMA 设备的要求
2. ✅ **零拷贝**: 不同设备间共享内存，无需拷贝数据
3. ✅ **内存池管理**: 预分配内存池，提高分配效率
4. ✅ **多堆管理**: 支持不同类型的内存堆
5. ✅ **用户空间访问**: 应用程序可以直接管理多媒体缓冲区

---

## size_pool 堆的工作原理

### 内存布局

```
size_pool 区域: 0x82000000 - 0x83BFFFFF (28 MB)
├─────────────────────────────────────────────────┐
│                                                 │
│  ION size_pool 堆: 20 MB (heap-size)            │
│  ┌───────────────────────────────────────┐     │
│  │ 小内存池 (< 100KB 分配)                │     │
│  │  - 频繁分配的小块内存                  │     │
│  │  - 减少碎片化                         │     │
│  ├───────────────────────────────────────┤     │
│  │ 大内存池 (>= 100KB 分配)               │     │
│  │  - 视频帧缓冲                         │     │
│  │  - 编码输出缓冲                        │     │
│  └───────────────────────────────────────┘     │
│                                                 │
│  CMA 区域: 2 MB (linux,cma)                     │
│  ┌───────────────────────────────────────┐     │
│  │ 可重用连续内存区                       │     │
│  │  - 视频编解码缓冲                      │     │
│  │  - ISP 缓冲                            │     │
│  └───────────────────────────────────────┘     │
│                                                 │
│  剩余: ~6 MB                                    │
│  ┌───────────────────────────────────────┐     │
│  │ 普通 Linux 内存                        │     │
│  │  - 用户进程                            │     │
│  │  - 页缓存                              │     │
│  └───────────────────────────────────────┘     │
└─────────────────────────────────────────────────┘
```

### 分配策略

**驱动代码**: `bsp/drivers/staging/android/ion/heaps/ion_size_pool_heap.c`

```c
// 分配逻辑
if (size <= threshold) {  // size <= 100 KB
    // 从小内存池分配
    allocate_from_small_pool();
} else {
    // 从大内存池分配
    allocate_from_big_pool();
}

// 如果小池失败，且 fall_to_big_pool = 1
if (small_pool_failed && fall_to_big_pool) {
    // 回退到大池
    allocate_from_big_pool();
}
```

**配置参数**：
- `thrs = <100>`: 阈值 100 KB
  - 小于 100 KB → 小池
  - 大于等于 100 KB → 大池
- `fall_to_big_pool = <1>`: 启用回退机制

---

## 如何在设备上查看 ION 使用情况

### 1. 查看 ION debugfs 信息

```bash
# 查看 ION 调试文件系统
ls /sys/kernel/debug/ion/

# 查看 ION 堆列表
cat /sys/kernel/debug/ion/heaps

# 示例输出
heap_name             heap_type heap_id
--------------------------------------------
size_pool             3         0
cma                   4         1
system                0         2
```

### 2. 查看 ION 客户端

```bash
# 查看 ION 客户端
cat /sys/kernel/debug/ion/clients

# 示例输出
client(0xXXXXXXXX) sample_recorder pid(456) ------------
  heap_name     total_size      allocation_size
  size_pool     4194304         [2MB video buffer]
  cma           1048576         [1MB ISP buffer]
```

### 3. 查看具体堆的使用情况

```bash
# 查看 size_pool 堆详情
cat /sys/kernel/debug/ion/heaps/size_pool

# 可能的输出
size_pool heap stats:
  total bytes: 20971520 (20 MB)
  free bytes:  18874368 (18 MB)
  alloc bytes:  2097152 (2 MB)
  peak bytes:   4194304 (4 MB)
```

### 4. 使用 proc 查看内存信息

```bash
# 查看总体内存（包括 ION 使用）
cat /proc/meminfo | grep -E "MemTotal|MemAvailable|CmaTotal|CmaFree"
```

**示例输出**：
```
MemTotal:          25468 kB    # 总内存
MemAvailable:      12968 kB    # 可用内存
CmaTotal:           2048 kB    # CMA 总量
CmaFree:            1992 kB    # CMA 空闲（ION 可能从这里分配）
```

### 5. 查看 /proc/iomem

```bash
# 查看物理内存映射
cat /proc/iomem | grep -A 5 "0x82000000"
```

**示例输出**：
```
82000000-83bfffff : System RAM
  82000000-833fffff : ion size_pool heap
  83400000-835fffff : linux,cma
  83600000-83bfffff : available
```

---

## ION 内存使用示例

### 应用程序使用 ION

**示例代码** (C):

```c
#include <ion_mem_alloc.h>

// 打开 ION 设备
int ion_fd = ion_open();

// 分配 ION 内存 (从 size_pool 堆)
struct aw_ion_alloc_info alloc_data = {
    .len = 1024 * 1024,  // 1 MB
    .heap_id_mask = ION_HEAP_SIZE_POOL_MASK,  // 从 size_pool 堆分配
    .flags = ION_FLAG_CACHED,  // 可缓存
};

ion_handle_t handle;
int ret = ion_alloc_fd(ion_fd, alloc_data.len, &alloc_data, &handle);

// 映射到用户空间
void *vir_addr = mmap(NULL, alloc_data.len, PROT_READ | PROT_WRITE,
                      MAP_SHARED, alloc_data.fd, 0);

// 使用内存
memset(vir_addr, 0, alloc_data.len);

// 获取物理地址（用于传递给硬件）
unsigned long phy_addr;
ion_get_phys(ion_fd, handle, &phy_addr);

// 释放
munmap(vir_addr, alloc_data.len);
ion_free(ion_fd, handle);
ion_close(ion_fd);
```

### 眼见为实的摄像头应用

**位置**: `platform/allwinner/eyesee-mpp/middleware/sun300iw1/sample/sample_recorder/`

摄像头录像应用使用 ION 分配视频缓冲区：

```c
// 分配视频帧缓冲
VIDEO_FRAME_INFO_S frame;
ion_alloc_fd(ion_fd, frame_size, &alloc_data, &handle);

// 传递给视频编码器
AW_MPI_VENC_SendFrame(VencChn, &frame, timeout);

// 编码器直接访问物理地址，无需拷贝
```

---

## size_pool vs CMA 对比

| 特性 | size_pool | CMA |
|-----|-----------|-----|
| **大小** | 20 MB (可配置) | 2 MB (可配置) |
| **类型** | ION 专用堆 | 可重用连续内存 |
| **分配方式** | gen_pool (内存池) | buddy allocator (伙伴系统) |
| **性能** | 快速（预分配） | 较慢（动态分配） |
| **碎片化** | 低 | 中等 |
| **可重用** | ❌ 专用 | ✅ 空闲时可被普通进程使用 |
| **主要用途** | 频繁的多媒体缓冲分配 | 大块连续内存分配 |
| **优先级** | 高（专用） | 低（可重用） |

**使用建议**：
- **小缓冲 (< 100KB)**: size_pool 小池
- **中等缓冲 (100KB - 2MB)**: size_pool 大池
- **大缓冲 (> 2MB)**: CMA
- **非常大或不规则**: 系统堆（buddy allocator）

---

## 监控 ION 内存的脚本

### ION 内存监控脚本

```bash
#!/bin/sh
# /mnt/UDISK/scripts/check_ion_memory.sh

echo "=========================================="
echo "        ION 内存使用情况"
echo "=========================================="
echo ""

# 1. 检查 ION debugfs 是否挂载
if [ ! -d /sys/kernel/debug/ion ]; then
    echo "错误: ION debugfs 未挂载"
    echo "尝试挂载 debugfs..."
    mount -t debugfs none /sys/kernel/debug
fi

# 2. 显示 ION 堆列表
echo "=== ION 堆列表 ==="
if [ -f /sys/kernel/debug/ion/heaps ]; then
    cat /sys/kernel/debug/ion/heaps
else
    echo "无法读取 ION 堆信息"
fi
echo ""

# 3. 显示 size_pool 堆统计
echo "=== size_pool 堆详情 ==="
if [ -f /sys/kernel/debug/ion/heaps/size_pool ]; then
    cat /sys/kernel/debug/ion/heaps/size_pool
else
    echo "size_pool 堆信息不可用"
fi
echo ""

# 4. 显示 CMA 堆统计
echo "=== CMA 堆详情 ==="
if [ -f /sys/kernel/debug/ion/heaps/cma ]; then
    cat /sys/kernel/debug/ion/heaps/cma
else
    echo "CMA 堆信息不可用"
fi
echo ""

# 5. 显示 ION 客户端
echo "=== ION 客户端（进程使用情况） ==="
if [ -f /sys/kernel/debug/ion/clients ]; then
    cat /sys/kernel/debug/ion/clients | head -50
else
    echo "客户端信息不可用"
fi
echo ""

# 6. 总体 CMA 使用情况（从 /proc/meminfo）
echo "=== 系统 CMA 使用情况 ==="
cat /proc/meminfo | grep -E "CmaTotal|CmaFree"
CMA_TOTAL=$(cat /proc/meminfo | awk '/CmaTotal/ {print $2}')
CMA_FREE=$(cat /proc/meminfo | awk '/CmaFree/ {print $2}')
CMA_USED=$((CMA_TOTAL - CMA_FREE))
CMA_PERCENT=$((CMA_USED * 100 / CMA_TOTAL))
echo "CMA 使用率: ${CMA_PERCENT}%"
echo ""

# 7. 物理内存映射
echo "=== size_pool 物理内存映射 ==="
cat /proc/iomem | grep -E "82000000|ion|cma" | head -10
echo ""

echo "=========================================="
echo "检查完成 - $(date)"
echo "=========================================="
```

**使用方法**：

```bash
# 保存脚本
cat > /mnt/UDISK/scripts/check_ion_memory.sh << 'EOF'
# (上面的脚本内容)
EOF

chmod +x /mnt/UDISK/scripts/check_ion_memory.sh

# 运行
/mnt/UDISK/scripts/check_ion_memory.sh
```

---

## 修改 ION 配置

### 增大 ION 堆大小

**编辑文件**: `device/config/chips/v821/configs/avaota_f1/board.dts`

```dts
ion-heap {
    heap-base = <0x82000000>;
    heap-size = <0x01800000>;  /* 改为 24 MB (原来 20 MB) */
    heap-type = "ion_size_pool";
    thrs = <100>;
    sizes = <0 20480>;
    fall_to_big_pool = <1>;
};
```

### 调整小/大池阈值

```dts
ion-heap {
    heap-base = <0x82000000>;
    heap-size = <0x01400000>;
    heap-type = "ion_size_pool";
    thrs = <200>;  /* 改为 200 KB (原来 100 KB) */
    sizes = <0 20480>;
    fall_to_big_pool = <1>;
};
```

**影响**：
- `thrs` 越大：更多分配从小池进行，减少碎片
- `thrs` 越小：更多分配从大池进行，适合大缓冲应用

### 重新编译

```bash
# 修改设备树后
./build.sh dtb
./build.sh kernel
./build.sh tina
./build.sh pack
```

---

## 常见问题

### Q1: size_pool 和 CMA 有什么区别？

**A**:
- **size_pool**: ION 专用的 20MB 内存池，专门用于多媒体缓冲区分配
- **CMA**: 2MB 可重用连续内存，空闲时可被普通进程使用

### Q2: 为什么 size_pool 是 28MB，但 ION 堆只有 20MB？

**A**:
- `size_pool` 节点定义了 28MB 区域
- `ion-heap` 配置只使用了其中的 20MB (`heap-size = 0x01400000`)
- 剩余 8MB 可被普通 Linux 内存使用

### Q3: 如何查看 ION 是否在工作？

**A**:
```bash
# 检查 ION 设备节点
ls -l /dev/ion

# 应该看到
crw-rw---- 1 root video 10, 56 Jan  1 00:00 /dev/ion

# 检查 ION 堆
cat /sys/kernel/debug/ion/heaps

# 运行录像程序后查看客户端
cat /sys/kernel/debug/ion/clients
```

### Q4: ION 分配失败怎么办？

**A**: 检查步骤：
1. 查看堆是否耗尽：
   ```bash
   cat /sys/kernel/debug/ion/heaps/size_pool
   ```
2. 查看 CMA 是否可用：
   ```bash
   cat /proc/meminfo | grep Cma
   ```
3. 查看是否有内存泄漏：
   ```bash
   cat /sys/kernel/debug/ion/clients
   ```

### Q5: 可以禁用 ION 吗？

**A**: 不建议！V821 的视频编解码器依赖 ION 分配连续物理内存。禁用 ION 会导致：
- ❌ 摄像头无法工作
- ❌ 视频编码失败
- ❌ ISP 处理异常

---

## 总结

### size_pool 内存区域的作用

```
28 MB size_pool 区域 (0x82000000 - 0x83BFFFFF)
│
├─ 20 MB: ION size_pool 堆
│  ├─ 小池: < 100KB 分配 (频繁、快速)
│  └─ 大池: >= 100KB 分配 (视频帧)
│
├─ 2 MB: CMA (可重用连续内存)
│
└─ 6 MB: 普通 Linux 内存
```

### 关键配置

| 参数 | 值 | 说明 |
|-----|---|------|
| **size_pool 总大小** | 28 MB | 设备树 `size_pool` 节点 |
| **ION 堆大小** | 20 MB | `ion-heap` 的 `heap-size` |
| **CMA 大小** | 2 MB | `linux,cma` 的 `size` |
| **小/大池阈值** | 100 KB | `thrs` 参数 |

### 查看命令速查

```bash
# ION 堆列表
cat /sys/kernel/debug/ion/heaps

# size_pool 使用情况
cat /sys/kernel/debug/ion/heaps/size_pool

# ION 客户端
cat /sys/kernel/debug/ion/clients

# CMA 使用
cat /proc/meminfo | grep Cma

# 物理内存映射
cat /proc/iomem | grep 82000000

# 运行监控脚本
/mnt/UDISK/scripts/check_ion_memory.sh
```

---

**相关文档**：
- [DDR_MEMORY_LAYOUT.md](DDR_MEMORY_LAYOUT.md) - DDR 内存完整布局
- [MEMORY_MANAGEMENT.md](MEMORY_MANAGEMENT.md) - 内存使用管理
- [FLASH_PARTITION_LAYOUT.md](FLASH_PARTITION_LAYOUT.md) - Flash 分区布局

**更新日期**：2025-01-16
