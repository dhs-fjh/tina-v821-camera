# V821 NOR Flash 分区布局说明

## 概览

本文档描述 Allwinner V821 (avaota_f1) 开发板的 NOR Flash 存储分区布局和使用策略。

**Flash 规格**：
- 类型：NOR Flash
- 总容量：**32 MB**
- 擦除块大小：64 KB (0x10000)
- 文件系统：SquashFS (只读) + JFFS2 (可读写) + OverlayFS (合并层)

---

## 完整分区表

根据 `/proc/mtd` 的实际分区信息：

| MTD | 分区名 | 大小（十六进制） | 大小（MB/KB） | 用途 | 文件系统 | 挂载点 |
|-----|--------|----------------|--------------|------|---------|--------|
| mtd0 | **uboot** | 0x00100000 | 1 MB | U-Boot 引导加载器 | - | - |
| mtd1 | **boot-resource** | 0x00080000 | 512 KB | 启动资源文件 | - | - |
| mtd2 | **env** | 0x00020000 | 128 KB | U-Boot 环境变量 | - | - |
| mtd3 | **env-redund** | 0x00020000 | 128 KB | 环境变量备份 | - | - |
| mtd4 | **boot** | 0x00500000 | 5 MB | Linux 内核镜像 | - | - |
| mtd5 | **private** | 0x00010000 | 64 KB | 私有数据 | - | - |
| mtd6 | **riscv0** | 0x00130000 | 1.2 MB | RTOS 固件 (E907核) | - | - |
| mtd7 | **rootfs** | 0x00570000 | 5.4 MB | 只读根文件系统 | **SquashFS** | `/rom` |
| mtd8 | **rootfs_data** | 0x00080000 | 512 KB | 可写数据层 | **JFFS2** | `/overlay` |
| mtd9 | **UDISK** | 0x01210000 | 18.1 MB | 用户数据存储 | **JFFS2** | `/mnt/UDISK` |

**总计**：1 + 0.5 + 0.125 + 0.125 + 5 + 0.064 + 1.2 + 5.4 + 0.5 + 18.1 = **32.014 MB**

---

## 分区布局示意图

```
┌─────────────────────────────────── 32 MB NOR Flash ──────────────────────────────────┐
│                                                                                       │
│  ┌─────┬──────┬───┬───┬─────────┬────┬─────┬─────────┬──────┬──────────────────────┐ │
│  │uboot│boot- │env│env│  boot   │priv│riscv│ rootfs  │rootfs│       UDISK          │ │
│  │     │res   │   │red│         │ate │  0  │         │_data │                      │ │
│  │ 1MB │0.5MB │128│128│   5MB   │64KB│1.2MB│  5.4MB  │512KB │      18.1 MB         │ │
│  │     │      │KB │KB │         │    │     │         │      │                      │ │
│  └─────┴──────┴───┴───┴─────────┴────┴─────┴─────────┴──────┴──────────────────────┘ │
│  mtd0  mtd1   mtd2 mtd3  mtd4   mtd5 mtd6    mtd7     mtd8          mtd9            │
│                                                                                       │
│  ◄────────── 引导固件 (7MB) ──────────►◄─系统(6MB)─►◄──── 用户数据 (18MB) ────►      │
│                                                                                       │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 分区功能详解

### 1. 引导与固件分区（不可修改，共 7.01 MB）

#### mtd0: uboot (1 MB)
- **功能**：U-Boot 2018 引导加载器
- **只读**：通过专用工具烧录
- **作用**：系统启动第一阶段，加载内核和设备树

#### mtd1: boot-resource (512 KB)
- **功能**：启动资源文件（Logo、启动画面等）
- **配置文件**：定义在 `sys_partition_nor.fex`

#### mtd2/mtd3: env / env-redund (各 128 KB)
- **功能**：U-Boot 环境变量及备份
- **内容**：启动参数、内核命令行、网络配置等
- **冗余设计**：双备份防止损坏

#### mtd4: boot (5 MB)
- **功能**：Linux 内核镜像 (zImage/Image)
- **文件**：`boot.fex` (由 `./build.sh kernel` 生成)
- **包含**：内核 + 设备树 blob

#### mtd5: private (64 KB)
- **功能**：私有数据存储
- **特性**：重新烧录时数据可保留（如果配置 keydata=1）

#### mtd6: riscv0 (1.2 MB)
- **功能**：FreeRTOS 固件（运行在 E907 RISC-V 核心）
- **文件**：`amp_rv0.fex`
- **用途**：实时任务处理（ISP 调优、实时控制等）

---

### 2. 系统分区（6 MB，OverlayFS 架构）

#### mtd7: rootfs (5.4 MB) - 只读基础系统
- **文件系统**：SquashFS（高压缩比、只读）
- **挂载点**：`/rom`
- **内容**：
  - 核心系统文件（`/bin`, `/sbin`, `/lib`, `/usr`）
  - 基础工具和库
  - 默认配置文件
- **特点**：
  - ✅ 压缩存储，空间利用率高
  - ✅ 只读，防止误操作损坏系统
  - ❌ 无法直接修改

#### mtd8: rootfs_data (512 KB) - 可写层 ⚠️
- **文件系统**：JFFS2（压缩、可读写、断电保护）
- **挂载点**：`/overlay`
- **内容**：
  - `/overlay/upper/` - 所有修改和新增的文件
  - `/overlay/work/` - OverlayFS 工作目录
- **警告**：
  - 🔴 **仅 512 KB**，空间极其紧张！
  - 🔴 修改系统文件会复制到此分区（COW）
  - 🔴 安装软件包会占用此空间
  - 🔴 配置文件修改会占用此空间

#### OverlayFS 合并机制

```
用户看到的根目录 (/)
         ↓
┌────────────────────────────┐
│   OverlayFS 合并文件系统    │
│   (透明合并上下两层)        │
└────────────────────────────┘
         ↓
    ┌─────────────────┬──────────────────┐
    │   下层 (只读)     │    上层 (可写)     │
    │   /rom           │    /overlay/upper │
    │   mtd7 (5.4MB)   │    mtd8 (512KB)   │
    │   SquashFS       │    JFFS2          │
    └─────────────────┴──────────────────┘
         原始系统文件        修改/新增文件
```

**工作原理**：
1. **读取文件**：优先从 `/overlay/upper` 读，如果不存在则从 `/rom` 读
2. **修改文件**：将文件从 `/rom` 复制到 `/overlay/upper` 再修改（Copy-on-Write）
3. **新增文件**：直接写入 `/overlay/upper`
4. **删除文件**：在 `/overlay/upper` 创建 whiteout 标记

**示例**：
```bash
# 原始文件
/rom/etc/config/network  (只读，在 mtd7)

# 用户修改后
/overlay/upper/etc/config/network  (可写副本，在 mtd8)

# 用户看到的
/etc/config/network  (OverlayFS 合并后的视图)
```

---

### 3. 用户数据分区

#### mtd9: UDISK (18.1 MB) - 主要用户存储 ✅
- **文件系统**：JFFS2
- **挂载点**：`/mnt/UDISK`
- **用途**：
  - 应用程序数据
  - 日志文件
  - 配置数据库
  - 小容量录像文件
- **特点**：
  - ✅ 最大的可用存储空间
  - ✅ 断电保护
  - ✅ 压缩存储
  - ⚠️ 18MB 仍然有限，大文件建议用 SD 卡

---

### 4. 外部存储（可选）

#### SD 卡：/dev/mmcblk0p1
- **文件系统**：VFAT (FAT32)
- **挂载点**：`/mnt/extsd`
- **容量**：可扩展（通常 4GB - 128GB）
- **推荐用途**：
  - ✅ 录像文件存储
  - ✅ 大容量日志
  - ✅ 固件备份
  - ✅ 数据导出

---

## 实际挂载点列表

根据 `/proc/mounts`：

```bash
# 核心文件系统
/dev/root              → /rom              # SquashFS 只读根
/dev/by-name/rootfs_data → /overlay        # JFFS2 可写层
overlayfs:/overlay     → /                 # OverlayFS 合并视图（实际根目录）

# 用户存储
/dev/mtdblock9         → /mnt/UDISK        # 用户数据分区
/dev/mmcblk0p1         → /mnt/extsd        # SD 卡（如果插入）

# 虚拟文件系统（RAM）
devtmpfs               → /dev              # 设备文件系统
proc                   → /proc             # 进程信息
tmpfs                  → /tmp              # 临时文件（RAM，重启丢失）
sysfs                  → /sys              # 系统信息
debugfs                → /sys/kernel/debug # 调试接口
configfs               → /sys/kernel/config# 内核配置接口

# USB 功能
adb                    → /dev/usb-ffs/adb  # ADB 功能
```

---

## 空间使用策略

### 🔴 严重限制区域（避免使用）

| 位置 | 容量 | 注意事项 |
|-----|------|---------|
| **根目录 (/)** | 512 KB (rootfs_data) | • 只存小配置文件<br>• 避免安装大软件包<br>• 避免创建日志文件<br>• 定期清理 |
| **/var/log** | 占用 rootfs_data | • 日志文件会快速占满空间<br>• 建议重定向到 UDISK 或 tmpfs |
| **/home** | 占用 rootfs_data | • 不要在这里存储用户数据 |

### ✅ 推荐使用区域

| 位置 | 容量 | 适用场景 |
|-----|------|---------|
| **/mnt/UDISK** | 18.1 MB | • 应用配置文件<br>• 小日志文件<br>• 数据库文件<br>• 缓存文件 |
| **/mnt/extsd** | 可扩展 (GB级) | • 录像文件（推荐）<br>• 大日志文件<br>• 备份数据<br>• 导出数据 |
| **/tmp** | RAM (约10MB) | • 临时文件<br>• 处理中间文件<br>• 临时日志<br>• **重启后丢失** |

---

## 开发建议

### 1. 应用程序文件路径规划

```bash
# ❌ 错误做法 - 占用宝贵的 rootfs_data
/home/app/recordings/video.mp4           # 会写入 overlay
/var/log/app.log                         # 会写入 overlay
/etc/app/large_config.db                 # 会写入 overlay

# ✅ 正确做法
/mnt/UDISK/app/recordings/video.mp4      # 使用 UDISK
/mnt/extsd/recordings/video_$(date).mp4  # 大文件用 SD 卡
/tmp/processing.tmp                       # 临时文件用 RAM
/mnt/UDISK/logs/app.log                  # 日志放 UDISK
```

### 2. 日志管理策略

```bash
# 方案 1: 日志输出到 UDISK
LOG_DIR=/mnt/UDISK/logs
mkdir -p $LOG_DIR
/usr/bin/app > $LOG_DIR/app.log 2>&1

# 方案 2: 日志输出到 tmpfs（不占 Flash，重启丢失）
LOG_DIR=/tmp/logs
mkdir -p $LOG_DIR
/usr/bin/app > $LOG_DIR/app.log 2>&1

# 方案 3: 使用 logrotate 限制日志大小
cat > /etc/logrotate.d/app << EOF
/mnt/UDISK/logs/app.log {
    size 1M
    rotate 2
    compress
    missingok
}
EOF
```

### 3. 配置文件管理

```bash
# 小配置文件（< 10KB）: 可以放系统目录
/etc/sample_recorder.conf                # 自动存到 overlay

# 大配置文件或频繁更新: 放 UDISK
/mnt/UDISK/config/camera_settings.json
/mnt/UDISK/config/database.sqlite

# 应用中读取配置的示例
CONFIG_FILE=/mnt/UDISK/config/app.conf
if [ ! -f "$CONFIG_FILE" ]; then
    cp /etc/app.conf.default $CONFIG_FILE  # 首次运行创建默认配置
fi
```

### 4. 录像文件存储策略

```bash
# 检测 SD 卡是否挂载
if mountpoint -q /mnt/extsd; then
    RECORD_DIR=/mnt/extsd/recordings
else
    # SD 卡未挂载，使用 UDISK（容量有限，需要定期清理）
    RECORD_DIR=/mnt/UDISK/recordings
fi

mkdir -p $RECORD_DIR
/usr/bin/sample_recorder -o $RECORD_DIR/video_$(date +%Y%m%d_%H%M%S).mp4

# 定期清理旧文件（如果用 UDISK）
find $RECORD_DIR -name "*.mp4" -mtime +1 -delete
```

---

## 空间监控命令

### 查看分区使用情况

```bash
# 查看所有挂载点的空间使用
df -h

# 重点关注这些分区
df -h | grep -E "(overlay|UDISK|extsd)"

# 示例输出
Filesystem           Size  Used Avail Use% Mounted on
overlayfs:/overlay   5.3M  2.1M  3.2M  40% /
/dev/mtdblock9       17.7M 5.2M 12.5M  30% /mnt/UDISK
/dev/mmcblk0p1       7.4G  1.2G  6.2G  16% /mnt/extsd
```

### 查看 overlay 详细使用情况

```bash
# 查看 overlay 上层目录大小（重要！）
du -sh /overlay/upper

# 查看哪些目录占用最多
du -h /overlay/upper | sort -hr | head -10

# 查看具体文件
find /overlay/upper -type f -exec ls -lh {} \; | sort -k5 -hr | head -20
```

### 查看 MTD 分区信息

```bash
# 查看分区列表
cat /proc/mtd

# 查看某个分区的详细信息
cat /sys/class/mtd/mtd8/size        # 大小（字节）
cat /sys/class/mtd/mtd8/erasesize   # 擦除块大小
cat /sys/class/mtd/mtd8/name        # 分区名称
```

### 清理空间

```bash
# 清理 overlay 缓存
rm -rf /overlay/upper/tmp/*
rm -rf /overlay/upper/var/log/*

# 清理软件包缓存
opkg clean

# 查找大文件
find / -type f -size +100k 2>/dev/null | xargs ls -lh
```

---

## 分区配置文件

### 分区表定义文件

**位置**：`device/config/chips/v821/configs/avaota_f1/sys_partition_nor.fex`

```ini
[mbr]
size = 16              # MBR 大小 (KB)

[partition_start]

[partition]
name         = boot-resource
size         = 1024    # 单位：扇区 (512字节)，即 512KB
user_type    = 0x8000

[partition]
name         = env
size         = 256     # 128 KB
downloadfile = "env.fex"
user_type    = 0x8000

[partition]
name         = boot
size         = 10240   # 5 MB
downloadfile = "boot.fex"
user_type    = 0x8000

[partition]
name         = riscv0
size         = 2432    # 1.2 MB
downloadfile = "amp_rv0.fex"
user_type    = 0x8000

[partition]
name         = rootfs
size         = 11136   # 5.4 MB
downloadfile = "rootfs_nor.fex"
user_type    = 0x8000

[partition]
name         = rootfs_data
size         = 1024    # 512 KB
user_type    = 0x8000

# UDISK 分区会自动使用剩余空间
```

### 修改分区大小

⚠️ **警告**：修改分区表需要重新烧录整个固件，数据会丢失！

```bash
# 1. 编辑分区表
vim device/config/chips/v821/configs/avaota_f1/sys_partition_nor.fex

# 2. 重新编译固件
./build.sh tina

# 3. 打包固件
./build.sh pack

# 4. 烧录新固件（数据会丢失！）
```

**调整建议**：
- 如果需要更大的用户空间，可以减小 `rootfs` 大小（需要确保系统能放下）
- `rootfs_data` 建议保持至少 512KB
- `UDISK` 会自动占用剩余空间

---

## 常见问题

### Q1: 为什么 `df -h` 显示根目录只有 5.3MB？

A: 因为 OverlayFS 显示的是 `rootfs` (5.4MB) 的大小，实际可写空间是 `rootfs_data` (512KB)。

### Q2: `/overlay/upper` 满了怎么办？

A:
1. 删除不必要的文件：`rm -rf /overlay/upper/tmp/*`
2. 卸载不用的软件包：`opkg remove <package>`
3. 将日志/数据迁移到 `/mnt/UDISK`
4. 最后手段：恢复出厂设置 `firstboot && reboot`

### Q3: 如何判断文件在哪个分区？

A:
```bash
# 查看文件实际位置
ls -la /etc/config/network

# 如果是符号链接或 overlay 文件
find /overlay/upper -name network  # 在 rootfs_data
find /rom -name network            # 在 rootfs (只读)
```

### Q4: SD 卡没有自动挂载？

A:
```bash
# 手动挂载
mkdir -p /mnt/extsd
mount /dev/mmcblk0p1 /mnt/extsd

# 添加自动挂载（修改 /etc/fstab 或使用 hotplug）
```

### Q5: JFFS2 文件系统损坏怎么办？

A:
```bash
# 检查 MTD 设备
cat /proc/mtd

# 重新格式化 UDISK（数据会丢失！）
umount /mnt/UDISK
flash_erase /dev/mtd9 0 0
mount -t jffs2 /dev/mtdblock9 /mnt/UDISK
```

---

## 总结

### 空间分配总览

| 类别 | 分区 | 容量 | 可写 | 用途 |
|-----|------|------|------|------|
| **引导** | uboot, boot-resource, env, boot | 7 MB | ❌ | 系统启动 |
| **固件** | riscv0 | 1.2 MB | ❌ | RTOS 固件 |
| **系统** | rootfs | 5.4 MB | ❌ | 只读系统 |
| **系统可写** | rootfs_data | 512 KB | ✅ | 系统修改 |
| **用户数据** | UDISK | 18.1 MB | ✅ | 应用数据 |
| **扩展** | SD 卡 | GB 级 | ✅ | 大容量存储 |

### 最佳实践

1. ✅ **系统配置**：小文件（< 10KB）可以放 `/etc`，会自动保存到 overlay
2. ✅ **应用数据**：放 `/mnt/UDISK`
3. ✅ **录像文件**：放 SD 卡 `/mnt/extsd`
4. ✅ **临时文件**：放 `/tmp`（RAM）
5. ⚠️ **日志文件**：定期清理或重定向到 UDISK/SD卡
6. 🔴 **避免**：在根目录下安装大软件包或存储大文件

### 空间监控

定期检查空间使用：
```bash
df -h | grep overlay    # 检查系统可写空间
df -h /mnt/UDISK        # 检查用户数据空间
du -sh /overlay/upper   # 查看实际占用
```

当 `rootfs_data` 使用超过 80% 时，务必清理文件！

---

**参考文档**：
- [sys_partition_nor.fex](../device/config/chips/v821/configs/avaota_f1/sys_partition_nor.fex) - 分区表配置
- [PROC_FILESYSTEM_GUIDE.md](PROC_FILESYSTEM_GUIDE.md) - /proc 文件系统指南
- [DEVICE_TREE_PARAMETER_GUIDE.md](DEVICE_TREE_PARAMETER_GUIDE.md) - 设备树参数指南

**更新日期**：2025-01-16
