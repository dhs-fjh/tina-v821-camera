# DDR 内存管理指南

## 概览

本文档介绍如何在 V821 系统上查看和管理 DDR 内存使用情况。

**系统内存配置**：
- **总 DDR 容量**: 32 MB (但实际可用约 25 MB，部分被内核和保留区占用)
- **实际可用**: 25468 KB ≈ **24.87 MB**
- **CMA 保留内存**: 2048 KB = **2 MB** (用于视频处理)
- **交换分区**: 无 (嵌入式系统通常不使用 Swap)

---

## 快速查看内存使用

### 1. `free` 命令（最常用）

```bash
# 以人类可读格式显示
free -h

# 以 KB 为单位显示（更精确）
free

# 持续监控（每秒刷新）
free -h -s 1
```

### 实际输出示例（来自你的系统）

```bash
root@(none):/mnt# free -h
              total        used        free      shared  buff/cache   available
Mem:          25468        9992        3184           8       12292       13032
Swap:             0           0           0
```

**字段解读**：

| 字段 | 数值 (KB) | 说明 |
|-----|----------|------|
| **total** | 25468 | 总可用内存 ≈ 24.87 MB |
| **used** | 9992 | 已使用内存 ≈ 9.76 MB (39.2%) |
| **free** | 3184 | 完全空闲内存 ≈ 3.11 MB |
| **shared** | 8 | 共享内存 ≈ 8 KB |
| **buff/cache** | 12292 | 缓冲和缓存 ≈ 12.0 MB |
| **available** | 13032 | **可用内存** ≈ 12.73 MB (51.2%) |

**关键理解**：
- ✅ **available (13 MB)** 是真正可用的内存，包括可释放的缓存
- 📊 **buff/cache (12 MB)** 是系统智能使用的缓存，可以随时释放
- 🔴 **free (3 MB)** 是完全空闲的内存（不包括缓存）

**内存使用状态**：✅ **健康** (可用内存 51.2%)

---

## 详细内存信息

### 2. `/proc/meminfo` 完整信息

```bash
# 查看完整内存信息
cat /proc/meminfo

# 只看关键信息
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|Slab|CmaTotal|CmaFree"
```

### 实际输出详解（来自你的系统）

```bash
root@(none):/proc# cat meminfo
MemTotal:          25468 kB    # 总内存
MemFree:            3116 kB    # 空闲内存
MemAvailable:      12968 kB    # 可用内存（重要！）
Buffers:            8148 kB    # 块设备缓冲
Cached:             1220 kB    # 页缓存
SwapCached:            0 kB    # 交换缓存
Active:             6088 kB    # 活跃使用的内存
Inactive:           3528 kB    # 不活跃内存
Active(anon):        252 kB    # 活跃匿名页（进程堆栈）
Inactive(anon):        4 kB    # 不活跃匿名页
Active(file):       5836 kB    # 活跃文件缓存
Inactive(file):     3524 kB    # 不活跃文件缓存
Unevictable:           0 kB    # 不可回收内存
Mlocked:               0 kB    # 锁定内存
SwapTotal:             0 kB    # 交换空间总量（无）
SwapFree:              0 kB    # 空闲交换空间
Dirty:                 0 kB    # 脏页（待写回）
Writeback:             0 kB    # 正在写回的页
AnonPages:           256 kB    # 匿名页映射
Mapped:              972 kB    # 文件映射
Shmem:                 8 kB    # 共享内存
KReclaimable:       2924 kB    # 内核可回收内存
Slab:               8068 kB    # 内核 Slab 缓存
SReclaimable:       2924 kB    # 可回收 Slab
SUnreclaim:         5144 kB    # 不可回收 Slab
KernelStack:         384 kB    # 内核栈
PageTables:           60 kB    # 页表
VmallocTotal:     524288 kB    # Vmalloc 总空间
VmallocUsed:        2748 kB    # 已使用 Vmalloc
Percpu:               64 kB    # Per-CPU 内存
CmaTotal:           2048 kB    # CMA 总量（视频专用）
CmaFree:            1992 kB    # CMA 空闲
```

---

## 内存使用详细分析

### 内存分配结构图

```
┌────────────────────────── 32 MB 物理 DDR ──────────────────────────┐
│                                                                     │
│  ┌──────────┬───────────────────────────────────────────────────┐  │
│  │ 内核保留  │           用户可用内存 (25468 KB)                  │  │
│  │ ~7 MB    │                                                   │  │
│  └──────────┴───────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

用户可用内存分配 (25468 KB ≈ 24.87 MB):

┌───────────────────────────────────────────────────────────────┐
│                    25468 KB 总内存                             │
├───────────────┬───────────────┬───────────────────────────────┤
│   进程使用     │  Buffers      │        Free                   │
│   ~10 MB      │   ~8 MB       │        ~3 MB                  │
│  (39.2%)      │  (32.0%)      │       (12.2%)                 │
└───────────────┴───────────────┴───────────────────────────────┘
│◄──────────── Used ──────────►│◄────── Cache ────►│◄─ Free ─►│
     9992 KB (39.2%)              12292 KB            3184 KB

可用内存 (Available): 13032 KB = Free + 可回收的 Cache/Buffers
```

### 内存使用占比

根据你的实际数据：

| 类型 | 大小 (KB) | 大小 (MB) | 占比 | 说明 |
|-----|----------|----------|------|------|
| **进程实际使用** | 9,992 | 9.76 | 39.2% | 应用程序占用的内存 |
| **Buffers** | 8,148 | 7.96 | 32.0% | 块设备 I/O 缓冲（可释放） |
| **Cached** | 1,220 | 1.19 | 4.8% | 文件缓存（可释放） |
| **Slab (内核)** | 8,068 | 7.88 | 31.7% | 内核对象缓存 |
| **Free** | 3,116 | 3.04 | 12.2% | 完全空闲 |
| **Available** | 12,968 | 12.66 | 50.9% | **可用内存（关键指标）** |

### CMA 内存（视频专用）

```
CMA (Contiguous Memory Allocator):
总量: 2048 KB = 2 MB
空闲: 1992 KB ≈ 1.95 MB (97.3% 空闲)
已用: 56 KB ≈ 0.05 MB (2.7% 使用)
```

**CMA 说明**：
- 🎥 **用途**: 为视频编解码、ISP 处理保留的连续物理内存
- 📌 **特点**: 不计入普通可用内存，专用于视频处理
- ✅ **状态**: 几乎未使用（视频处理未启动时为空闲）

---

## 常用查看命令

### 1. 快速查看总览

```bash
# 最常用
free -h

# 持续监控（每秒刷新）
watch -n 1 free -h

# 高亮变化
watch -n 1 -d free -h
```

### 2. 查看详细信息

```bash
# 完整内存信息
cat /proc/meminfo

# 只看关键指标
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|Slab|Active|Inactive|CmaTotal|CmaFree"

# 实时监控 meminfo
watch -n 1 'cat /proc/meminfo | head -25'
```

### 3. 查看进程内存使用

```bash
# 查看所有进程（按内存排序）
ps aux --sort=-%mem | head -20

# 只看内存占用前 10 的进程
ps aux --sort=-%mem | awk 'NR==1 || NR<=11 {printf "%-8s %-6s %-10s %s\n", $2, $4"%", $6"KB", $11}'

# 查看特定进程
ps aux | grep sample_recorder

# 查看进程详细内存
cat /proc/<pid>/status | grep -E "Vm"
```

**示例输出**：
```bash
PID      %MEM   RSS(KB)    COMMAND
456      8.5    2164KB     sample_recorder
123      3.2    815KB      dropbear
789      2.1    535KB      /usr/sbin/telnetd
```

### 4. 使用 `top` 实时监控

```bash
# 启动 top（按 q 退出）
top

# 只显示一次
top -n 1

# 按内存排序（在 top 中按 Shift+M）
top -o %MEM
```

**top 输出示例**：
```
Mem: 25468K total, 22352K used, 3116K free, 8148K buffers
     ↑ 总内存      ↑ 已用      ↑ 空闲    ↑ 缓冲

  PID  USER     %MEM   VSZ   RSS  COMMAND
  456  root      8.5  4532  2164  sample_recorder
  123  root      3.2  2048   815  dropbear
```

---

## 内存监控脚本

### 自动监控脚本

```bash
#!/bin/sh
# /mnt/UDISK/scripts/check_memory.sh
# 内存使用情况监控脚本

echo "=========================================="
echo "        V821 系统内存使用情况"
echo "=========================================="
echo ""

# 1. 总体内存信息
echo "=== 总体内存 (free -h) ==="
free -h
echo ""

# 2. 详细内存信息
echo "=== 详细内存信息 ==="
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|Active|Inactive|Slab|CmaTotal|CmaFree" | while read line; do
    printf "%-20s %s\n" $(echo $line | cut -d: -f1): $(echo $line | cut -d: -f2)
done
echo ""

# 3. 内存使用百分比
MEM_TOTAL=$(cat /proc/meminfo | awk '/MemTotal/ {print $2}')
MEM_FREE=$(cat /proc/meminfo | awk '/MemFree/ {print $2}')
MEM_AVAIL=$(cat /proc/meminfo | awk '/MemAvailable/ {print $2}')
MEM_USED=$((MEM_TOTAL - MEM_FREE))
MEM_USED_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
MEM_AVAIL_PERCENT=$((MEM_AVAIL * 100 / MEM_TOTAL))

echo "=== 内存使用率 ==="
printf "总内存:     %8d KB (%.2f MB)\n" $MEM_TOTAL $(awk "BEGIN {printf \"%.2f\", $MEM_TOTAL/1024}")
printf "已使用:     %8d KB (%.2f MB) - %d%%\n" $MEM_USED $(awk "BEGIN {printf \"%.2f\", $MEM_USED/1024}") $MEM_USED_PERCENT
printf "空闲内存:   %8d KB (%.2f MB) - %d%%\n" $MEM_FREE $(awk "BEGIN {printf \"%.2f\", $MEM_FREE/1024}") $((MEM_FREE * 100 / MEM_TOTAL))
printf "可用内存:   %8d KB (%.2f MB) - %d%%\n" $MEM_AVAIL $(awk "BEGIN {printf \"%.2f\", $MEM_AVAIL/1024}") $MEM_AVAIL_PERCENT
echo ""

# 4. CMA 内存
CMA_TOTAL=$(cat /proc/meminfo | awk '/CmaTotal/ {print $2}')
CMA_FREE=$(cat /proc/meminfo | awk '/CmaFree/ {print $2}')
CMA_USED=$((CMA_TOTAL - CMA_FREE))
CMA_USED_PERCENT=$((CMA_USED * 100 / CMA_TOTAL))

echo "=== CMA 内存（视频处理专用） ==="
printf "CMA 总量:   %8d KB (%.2f MB)\n" $CMA_TOTAL $(awk "BEGIN {printf \"%.2f\", $CMA_TOTAL/1024}")
printf "CMA 已用:   %8d KB (%.2f MB) - %d%%\n" $CMA_USED $(awk "BEGIN {printf \"%.2f\", $CMA_USED/1024}") $CMA_USED_PERCENT
printf "CMA 空闲:   %8d KB (%.2f MB) - %d%%\n" $CMA_FREE $(awk "BEGIN {printf \"%.2f\", $CMA_FREE/1024}") $((CMA_FREE * 100 / CMA_TOTAL))
echo ""

# 5. 内存使用 Top 5 进程
echo "=== 内存使用 Top 5 进程 ==="
printf "%-8s %-6s %-10s %-10s %s\n" "PID" "%MEM" "VSZ" "RSS" "COMMAND"
ps aux --sort=-%mem | awk 'NR>1 {printf "%-8s %-6s %-10s %-10s %s\n", $2, $4"%", $5, $6, $11}' | head -5
echo ""

# 6. 内存压力检查
echo "=== 内存状态评估 ==="
if [ $MEM_AVAIL_PERCENT -lt 10 ]; then
    echo "🔴 严重警告: 可用内存不足 10%！"
    echo "   建议: 立即检查并终止不必要的进程"
elif [ $MEM_AVAIL_PERCENT -lt 20 ]; then
    echo "🟡 警告: 可用内存低于 20%"
    echo "   建议: 检查内存占用情况，考虑优化"
elif [ $MEM_AVAIL_PERCENT -lt 40 ]; then
    echo "🟢 注意: 可用内存在 20-40% 之间"
    echo "   建议: 持续监控内存使用"
else
    echo "✅ 正常: 可用内存充足 (${MEM_AVAIL_PERCENT}%)"
fi

echo ""
echo "=========================================="
echo "检查完成 - $(date)"
echo "=========================================="
```

**保存并使用**：

```bash
# 创建脚本目录
mkdir -p /mnt/UDISK/scripts

# 保存脚本
cat > /mnt/UDISK/scripts/check_memory.sh << 'EOF'
# (上面的脚本内容)
EOF

# 添加执行权限
chmod +x /mnt/UDISK/scripts/check_memory.sh

# 运行脚本
/mnt/UDISK/scripts/check_memory.sh

# 定时监控（每小时执行一次）
echo "0 * * * * /mnt/UDISK/scripts/check_memory.sh >> /mnt/UDISK/logs/memory.log 2>&1" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## 内存问题诊断

### 1. 查找内存占用大户

```bash
# 查找占用内存最多的进程
ps aux --sort=-%mem | head -10

# 查看具体进程的详细内存
PID=$(pidof sample_recorder)
cat /proc/$PID/status | grep -E "Vm"

# 输出示例
VmPeak:     4532 kB  # 峰值虚拟内存
VmSize:     4532 kB  # 当前虚拟内存
VmRSS:      2164 kB  # 实际物理内存
VmData:     1024 kB  # 数据段
VmStk:       136 kB  # 栈
VmExe:       256 kB  # 代码段
```

### 2. 检测内存泄漏

```bash
# 持续监控特定进程的内存使用
PID=$(pidof sample_recorder)
echo "监控 PID: $PID"
while [ -d /proc/$PID ]; do
    RSS=$(cat /proc/$PID/status 2>/dev/null | awk '/VmRSS/ {print $2}')
    if [ -n "$RSS" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - RSS: $RSS KB"
    fi
    sleep 5
done
```

**如果 RSS 持续增长**，可能存在内存泄漏。

### 3. 查看 Slab 缓存详情

```bash
# 查看内核 Slab 使用情况
cat /proc/slabinfo | head -20

# 或使用 slabtop（如果可用）
slabtop -o

# 查看最大的 slab 对象
cat /proc/slabinfo | awk 'NR>2 {print $1, $3*$4}' | sort -k2 -nr | head -10
```

### 4. 清理缓存（释放内存）

```bash
# 同步数据到磁盘
sync

# 清理页缓存（Cached）
echo 1 > /proc/sys/vm/drop_caches

# 清理 dentries 和 inodes
echo 2 > /proc/sys/vm/drop_caches

# 清理所有缓存
echo 3 > /proc/sys/vm/drop_caches

# 查看清理效果
free -h
```

⚠️ **注意**：
- 清理缓存是临时性的，系统会自动重新缓存
- 频繁清理会降低系统性能
- 一般情况下不需要手动清理

---

## V821 内存配置

### 设备树中的内存定义

内存配置在设备树中定义，位置：
```
device/config/chips/v821/configs/avaota_f1/board.dts
```

**典型配置示例**：

```dts
/ {
    memory@40000000 {
        device_type = "memory";
        reg = <0x0 0x40000000 0x0 0x2000000>;  /* 32MB DDR */
        //     ↑   ↑ 起始地址   ↑   ↑ 大小
    };

    reserved-memory {
        #address-cells = <2>;
        #size-cells = <2>;
        ranges;

        /* CMA 保留内存：用于视频处理 */
        cma_pool: cma@82000000 {
            compatible = "shared-dma-pool";
            reg = <0x0 0x82000000 0x0 0x200000>;  /* 2MB */
            reusable;
            linux,cma-default;
        };

        /* 其他保留区域 */
        ion_cma: ion_cma {
            compatible = "shared-dma-pool";
            size = <0x0 0x800000>;  /* 8MB for ION */
            alignment = <0x0 0x1000>;
            reusable;
        };
    };
};
```

### 查看实际内存配置

```bash
# 在设备上查看设备树中的内存信息
ls /proc/device-tree/memory*/

# 查看内存节点
cat /proc/device-tree/memory@*/reg | hexdump -C

# 查看保留内存区域
ls /proc/device-tree/reserved-memory/

# 查看 CMA 配置
cat /proc/device-tree/reserved-memory/cma*/reg | hexdump -C
```

### 从启动日志查看内存信息

```bash
# 查看内存初始化日志
dmesg | grep -i "memory\|ddr\|cma"

# 可能的输出示例
[    0.000000] Memory: 25468K/32768K available (2048K kernel code, 256K rwdata, 512K rodata, 1024K init, 256K bss, 7300K reserved, 2048K cma-reserved)
[    0.000000] cma: Reserved 2 MiB at 0x82000000
```

**解读**：
- `32768K` = 32 MB：物理 DDR 总量
- `25468K` = 24.87 MB：用户可用内存
- `7300K` = 7.13 MB：内核保留（包括内核代码、数据等）
- `2048K` = 2 MB：CMA 保留内存

---

## 内存优化建议

### 1. 应用程序优化

```c
// 避免内存泄漏
void* ptr = malloc(1024);
// ... 使用 ptr
free(ptr);  // 务必释放

// 使用栈变量代替堆分配（如果可能）
char buffer[256];  // 栈上分配，自动释放

// 及时释放大块内存
if (large_buffer) {
    free(large_buffer);
    large_buffer = NULL;
}
```

### 2. 减少内存占用

```bash
# 关闭不必要的服务
/etc/init.d/telnetd stop
/etc/init.d/dropbear stop  # 如果不需要 SSH

# 卸载不用的内核模块
lsmod
rmmod <module_name>

# 限制进程内存使用（使用 ulimit）
ulimit -v 10240  # 限制虚拟内存为 10MB
```

### 3. 合理使用缓存

- ✅ **Buffers/Cached** 是系统自动管理的，提高 I/O 性能
- ✅ 不要频繁清理缓存
- ✅ 关注 **Available** 内存，而不是 **Free**

### 4. 监控内存趋势

```bash
# 定期记录内存使用
while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> /mnt/UDISK/logs/memory_trend.log
    cat /proc/meminfo | grep -E "MemAvailable|CmaFree" >> /mnt/UDISK/logs/memory_trend.log
    echo "" >> /mnt/UDISK/logs/memory_trend.log
    sleep 300  # 每 5 分钟记录一次
done &
```

---

## 常见问题

### Q1: 为什么总内存只有 25 MB，不是 32 MB？

**A**: 32 MB 是物理 DDR 容量，但部分内存被占用：
- 内核代码和数据结构：约 2-3 MB
- 设备驱动保留区：约 1-2 MB
- CMA 保留区：2 MB
- 其他保留区：约 2-3 MB

**总计**：32 MB - 7 MB ≈ 25 MB 用户可用

### Q2: CMA 内存是什么？为什么不能用？

**A**: CMA (Contiguous Memory Allocator) 是为视频编解码预留的连续物理内存。
- 只能被视频驱动使用（ISP、VENC、VDEC）
- 保证视频处理有足够的连续物理内存
- 用户进程不能直接使用

### Q3: 为什么没有 Swap？

**A**: 嵌入式系统通常不使用交换分区，原因：
- Flash 写入次数有限，频繁 swap 会损坏 Flash
- Swap 性能远低于 RAM
- 32MB 内存对于嵌入式摄像头系统足够

### Q4: Buffers 占用 8 MB 正常吗？

**A**: 完全正常。Buffers 是块设备 I/O 缓冲：
- 提高 Flash 读写性能
- 可以随时释放
- 已计入 `available` 内存

### Q5: 如何判断系统内存是否不足？

**A**: 关注 `MemAvailable` 值：
- **> 40%**: ✅ 正常
- **20-40%**: 🟡 注意监控
- **10-20%**: 🟠 需要优化
- **< 10%**: 🔴 严重不足

---

## 快速参考命令

```bash
# 查看内存总览
free -h

# 查看详细信息
cat /proc/meminfo | grep -E "MemTotal|MemAvailable|CmaTotal|CmaFree"

# 查看进程内存排行
ps aux --sort=-%mem | head -10

# 实时监控
watch -n 1 free -h

# 检查内存状态
/mnt/UDISK/scripts/check_memory.sh

# 查看 CMA 使用
cat /proc/meminfo | grep Cma

# 查看内核内存
cat /proc/meminfo | grep -E "Slab|KReclaimable"

# 清理缓存（慎用）
sync && echo 3 > /proc/sys/vm/drop_caches
```

---

## 内存使用指标总结（根据实际数据）

| 指标 | 数值 | 状态 | 说明 |
|-----|------|------|------|
| **总内存** | 24.87 MB | - | 用户可用内存 |
| **可用内存** | 12.66 MB | ✅ 正常 | 51.2% 可用 |
| **已用内存** | 9.76 MB | ✅ 正常 | 39.2% 使用 |
| **Buffers** | 7.96 MB | ✅ 正常 | 提高 I/O 性能 |
| **CMA 空闲** | 1.95 MB | ✅ 正常 | 97.3% 空闲 |

**系统内存健康度**: ✅ **优秀** (可用内存 > 50%)

---

**相关文档**：
- [FLASH_PARTITION_LAYOUT.md](FLASH_PARTITION_LAYOUT.md) - Flash 分区布局
- [DISK_SPACE_MANAGEMENT.md](DISK_SPACE_MANAGEMENT.md) - 磁盘空间管理
- [DEVICE_TREE_PARAMETER_GUIDE.md](DEVICE_TREE_PARAMETER_GUIDE.md) - 设备树参数指南

**更新日期**：2025-01-16
