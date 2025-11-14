# /proc 文件系统指南

`/proc` 是Linux的虚拟文件系统，提供内核和进程信息的接口。它不占用实际磁盘空间，所有内容都是内核动态生成的。

## 目录结构

### 1. 进程目录（数字命名）

每个数字目录对应一个进程ID (PID)：

```bash
/proc/1/      # PID=1 的进程（通常是init或systemd）
/proc/101/    # PID=101 的进程
/proc/self/   # 指向当前进程的符号链接
```

#### 进程目录中的重要文件

| 文件 | 说明 | 示例命令 |
|------|------|----------|
| **cmdline** | 进程启动命令行 | `cat /proc/1/cmdline` |
| **status** | 进程状态详情 | `cat /proc/1/status` |
| **exe** | 可执行文件路径（符号链接） | `ls -l /proc/1/exe` |
| **cwd** | 当前工作目录（符号链接） | `ls -l /proc/1/cwd` |
| **environ** | 环境变量 | `cat /proc/1/environ \| tr '\\0' '\\n'` |
| **maps** | 内存映射 | `cat /proc/1/maps` |
| **fd/** | 打开的文件描述符 | `ls -l /proc/1/fd/` |
| **task/** | 线程信息 | `ls /proc/1/task/` |
| **stat** | 进程统计信息 | `cat /proc/1/stat` |
| **statm** | 内存使用统计 | `cat /proc/1/statm` |
| **limits** | 资源限制 | `cat /proc/1/limits` |

**示例：查看进程信息**
```bash
# 查看当前shell进程
cat /proc/self/cmdline
echo ""

# 查看进程打开的文件
ls -l /proc/$$/fd/

# 查看进程内存映射
cat /proc/$$/maps | head -20
```

### 2. 系统信息文件（根目录下）

| 文件/目录 | 说明 | 用途 |
|-----------|------|------|
| **/proc/cpuinfo** | CPU信息 | 查看CPU型号、核心数、频率 |
| **/proc/meminfo** | 内存信息 | 查看总内存、可用内存、缓存 |
| **/proc/version** | 内核版本 | Linux版本、编译信息 |
| **/proc/uptime** | 系统运行时间 | 启动后运行秒数 |
| **/proc/loadavg** | 系统负载 | 1/5/15分钟平均负载 |
| **/proc/stat** | 系统统计 | CPU时间、中断、上下文切换 |
| **/proc/devices** | 设备列表 | 已注册的字符/块设备 |
| **/proc/interrupts** | 中断统计 | 每个CPU的中断次数 |
| **/proc/iomem** | I/O内存映射 | 外设物理地址映射 |
| **/proc/ioports** | I/O端口映射 | I/O端口占用情况 |
| **/proc/cmdline** | 内核启动参数 | bootargs |
| **/proc/modules** | 已加载模块 | 等同于 `lsmod` |
| **/proc/mounts** | 挂载点信息 | 等同于 `mount` |
| **/proc/partitions** | 分区信息 | 磁盘分区列表 |
| **/proc/swaps** | 交换分区 | swap使用情况 |
| **/proc/filesystems** | 支持的文件系统 | 内核支持的FS类型 |

### 3. 网络信息 (/proc/net/)

| 文件 | 说明 |
|------|------|
| /proc/net/dev | 网络接口统计 |
| /proc/net/tcp | TCP连接表 |
| /proc/net/udp | UDP连接表 |
| /proc/net/route | 路由表 |
| /proc/net/arp | ARP缓存 |

### 4. 系统配置 (/proc/sys/)

可读写的系统参数（sysctl接口）：

| 目录/文件 | 说明 |
|-----------|------|
| /proc/sys/kernel/ | 内核参数 |
| /proc/sys/vm/ | 虚拟内存参数 |
| /proc/sys/net/ | 网络参数 |
| /proc/sys/fs/ | 文件系统参数 |

**示例：修改系统参数**
```bash
# 查看参数
cat /proc/sys/kernel/hostname

# 临时修改（重启后失效）
echo "new-hostname" > /proc/sys/kernel/hostname

# 或使用sysctl命令
sysctl kernel.hostname=new-hostname
```

### 5. 调试信息 (/proc/sys/kernel/debug/)

需要挂载 debugfs：
```bash
mount -t debugfs none /sys/kernel/debug
```

常用调试文件：
- `/sys/kernel/debug/clk/clk_summary` - 时钟树状态
- `/sys/kernel/debug/gpio` - GPIO状态
- `/sys/kernel/debug/pinctrl/` - 引脚控制器状态

## 常用查询命令

### 查看CPU信息
```bash
cat /proc/cpuinfo
```

**V821 (RISC-V) 示例输出：**
```
processor       : 0
hart            : 0
isa             : rv32i2p0m2p0a2p0f2p0d2p0c2p0xv5-0p0
mmu             : sv32
```

### 查看内存信息
```bash
cat /proc/meminfo
```

**关键字段：**
- `MemTotal` - 总内存
- `MemFree` - 空闲内存
- `MemAvailable` - 可用内存
- `Buffers` - 缓冲区
- `Cached` - 缓存

### 查看内核版本
```bash
cat /proc/version
```

### 查看系统运行时间
```bash
cat /proc/uptime
# 输出：uptime_seconds idle_seconds
```

转换为可读格式：
```bash
uptime  # 或使用uptime命令
```

### 查看系统负载
```bash
cat /proc/loadavg
# 输出：1分钟 5分钟 15分钟 运行进程/总进程 最后PID
```

### 查看外设地址映射
```bash
cat /proc/iomem
```

### 查看已加载的内核模块
```bash
cat /proc/modules
# 或
lsmod
```

### 查看挂载的文件系统
```bash
cat /proc/mounts
# 或
mount
```

### 查找特定进程
```bash
# 通过进程名查找PID
ps | grep sample_recorder

# 查看该进程的详细信息
cat /proc/<PID>/status
cat /proc/<PID>/cmdline
ls -l /proc/<PID>/exe
```

### 查看进程打开的文件
```bash
ls -l /proc/<PID>/fd/
```

### 查看内核启动参数
```bash
cat /proc/cmdline
```

**V821示例：**
```
earlyprintk=sunxi-uart,0x42500000 loglevel=8 console=ttyAS0 init=/init
```

## 摄像头调试相关

### 查看V4L2设备
```bash
# 查看视频设备节点
ls -l /dev/video*

# 通过/proc查看对应进程
lsof /dev/video0  # 需要lsof工具
```

### 查看I2C设备
```bash
# I2C设备在/sys，不在/proc
ls /sys/class/i2c-dev/
ls /sys/bus/i2c/devices/
```

### 查看GPIO使用情况
```bash
# GPIO信息在debugfs
cat /sys/kernel/debug/gpio
```

### 查看时钟树
```bash
cat /sys/kernel/debug/clk/clk_summary | grep -i csi
```

### 查看中断统计
```bash
cat /proc/interrupts | grep -i "csi\|mipi\|vin"
```

## 常见进程PID

| PID | 进程 | 说明 |
|-----|------|------|
| **1** | init/systemd | 系统第一个进程 |
| **2** | kthreadd | 内核线程守护进程 |
| **self** | (符号链接) | 指向当前进程 |
| **thread-self** | (符号链接) | 指向当前线程 |

### 查看PID=1的进程
```bash
cat /proc/1/cmdline
echo ""
# V821输出可能是: /init
```

## 权限说明

- 大部分 `/proc` 文件只读
- `/proc/sys/` 下的文件可写（需root权限）
- 进程相关信息只有进程所有者和root可以访问

## 实用脚本示例

### 1. 查看所有进程及其命令行
```bash
#!/bin/sh
for pid in /proc/[0-9]*; do
    pid=$(basename $pid)
    cmd=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
    [ -n "$cmd" ] && echo "$pid: $cmd"
done
```

### 2. 查看内存使用TOP 10进程
```bash
#!/bin/sh
echo "PID    VSZ    RSS    CMD"
for pid in /proc/[0-9]*; do
    pid=$(basename $pid)
    if [ -f /proc/$pid/status ]; then
        vmsize=$(grep VmSize /proc/$pid/status | awk '{print $2}')
        vmrss=$(grep VmRSS /proc/$pid/status | awk '{print $2}')
        cmd=$(cat /proc/$pid/cmdline | tr '\0' ' ')
        [ -n "$vmrss" ] && echo "$pid $vmsize $vmrss $cmd"
    fi
done | sort -k3 -rn | head -10
```

### 3. 监控摄像头进程
```bash
#!/bin/sh
# 查找sample_recorder进程
PID=$(ps | grep sample_recorder | grep -v grep | awk '{print $1}')
if [ -n "$PID" ]; then
    echo "=== Process Info ==="
    cat /proc/$PID/cmdline
    echo ""
    echo "=== Memory ==="
    grep -E "Vm|Rss" /proc/$PID/status
    echo "=== Open Files ==="
    ls -l /proc/$PID/fd/
else
    echo "sample_recorder not running"
fi
```

## 注意事项

1. **/proc 是虚拟文件系统**，不占用磁盘空间
2. **内容动态生成**，每次读取时实时生成
3. **某些文件需要root权限**才能读取
4. **进程目录会随进程退出而消失**
5. **不要依赖/proc做持久化存储**

## 参考资料

- Linux内核文档: `Documentation/filesystems/proc.txt`
- man手册: `man 5 proc`

---

**提示**: 在嵌入式系统中，/proc是诊断系统状态的重要工具！
