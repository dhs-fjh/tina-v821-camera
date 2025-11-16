# 磁盘空间管理指南

## 概览

本文档介绍如何在 V821 系统上查看和管理磁盘空间，包括 NOR Flash 分区和 SD 卡存储。

---

## 快速查看空间使用

### 基本命令

```bash
# 查看所有挂载点的空间使用（最常用）
df -h

# 查看文件系统类型
df -hT

# 只查看特定分区
df -h /mnt/UDISK
df -h /mnt/extsd
df -h /
```

### 实际输出示例

```bash
root@(none):/mnt# df -h
Filesystem                Size      Used Available Use% Mounted on
/dev/root                 3.8M      3.8M         0 100% /rom
devtmpfs                 10.4M         0     10.4M   0% /dev
tmpfs                    12.4M      8.0K     12.4M   0% /tmp
/dev/by-name/rootfs_data
                        512.0K    200.0K    312.0K  39% /overlay
overlayfs:/overlay      512.0K    200.0K    312.0K  39% /
/dev/mtdblock9           18.1M    580.0K     17.5M   3% /mnt/UDISK
/dev/mmcblk0p1           29.1G      5.4G     23.7G  19% /mnt/extsd
```

---

## 详细解读

### 分区空间使用情况

| 挂载点 | 设备 | 总大小 | 已用 | 可用 | 使用率 | 说明 |
|--------|------|--------|------|------|--------|------|
| **/** | overlayfs:/overlay | 512 KB | 200 KB | **312 KB** | 39% | 🟡 系统可写空间 |
| **/rom** | /dev/root | 3.8 MB | 3.8 MB | 0 | 100% | 🔴 只读系统（正常满载） |
| **/overlay** | /dev/by-name/rootfs_data | 512 KB | 200 KB | **312 KB** | 39% | 🟡 实际系统可写层 |
| **/mnt/UDISK** | /dev/mtdblock9 | 18.1 MB | 580 KB | **17.5 MB** | 3% | ✅ 用户数据分区 |
| **/mnt/extsd** | /dev/mmcblk0p1 | 29.1 GB | 5.4 GB | **23.7 GB** | 19% | ✅ SD 卡（大容量） |
| **/tmp** | tmpfs | 12.4 MB | 8 KB | **12.4 MB** | 0% | ✅ 内存临时文件 |
| **/dev** | devtmpfs | 10.4 MB | 0 | **10.4 MB** | 0% | 设备文件系统 |

### 关键数据解读

#### 1. 根分区 (/) - overlayfs:/overlay
```
总容量: 512 KB
已使用: 200 KB (39%)
可用:   312 KB
```

**解读**：
- ✅ **健康状态**：使用率 39%，还有 312KB 可用
- ⚠️ **注意**：只有 512KB 总空间，不要存储大文件
- 💡 **建议**：保持使用率低于 80%

**这个分区存储什么？**
- 系统配置文件的修改（如 `/etc/config/*`）
- 安装的软件包
- 新增的系统文件

#### 2. 只读系统 (/rom)
```
总容量: 3.8 MB
已使用: 3.8 MB (100%)
可用:   0
```

**解读**：
- ✅ **正常现象**：这是只读压缩文件系统，100% 使用是正常的
- 📦 **内容**：核心系统文件、库、工具
- 🔒 **不可修改**：所有修改会复制到 overlay 分区

#### 3. UDISK 分区 (/mnt/UDISK)
```
总容量: 18.1 MB
已使用: 580 KB (3%)
可用:   17.5 MB
```

**解读**：
- ✅ **空间充足**：仅使用 3%，还有 17.5MB 可用
- 💾 **推荐用途**：
  - 应用配置文件
  - 数据库文件
  - 小日志文件
  - 临时录像片段

#### 4. SD 卡 (/mnt/extsd)
```
总容量: 29.1 GB
已使用: 5.4 GB (19%)
可用:   23.7 GB
```

**解读**：
- ✅ **大容量存储**：还有 23.7GB 可用
- 🎥 **推荐用途**：
  - 录像文件
  - 大日志文件
  - 固件备份
  - 数据导出

#### 5. 临时文件系统 (/tmp)
```
总容量: 12.4 MB (RAM)
已使用: 8 KB
可用:   12.4 MB
```

**解读**：
- ✅ **内存文件系统**：使用 RAM，速度快
- ⚠️ **重启丢失**：数据不持久化
- 💡 **适用场景**：临时处理文件、缓存

---

## 常用查看命令

### 1. 查看分区使用情况

```bash
# 所有分区（人类可读格式）
df -h

# 显示文件系统类型
df -hT

# 只显示本地文件系统（排除虚拟文件系统）
df -hl

# 显示 inode 使用情况
df -i
```

### 2. 查看目录大小

```bash
# 查看当前目录总大小
du -sh .

# 查看当前目录下所有子目录大小
du -h --max-depth=1

# 查看并排序（找出最大的目录）
du -h --max-depth=1 | sort -hr

# 查看 overlay 实际占用（重要！）
du -sh /overlay/upper

# 查看 overlay 下各目录大小
du -h /overlay/upper/* | sort -hr
```

### 3. 查看大文件

```bash
# 查找大于 100KB 的文件
find / -type f -size +100k 2>/dev/null | xargs ls -lh

# 在 overlay 中查找大文件
find /overlay/upper -type f -size +10k -exec ls -lh {} \;

# 在 UDISK 中查找大文件
find /mnt/UDISK -type f -size +1M -exec ls -lh {} \;

# 在系统中查找最大的 20 个文件
find / -type f -exec ls -s {} \; 2>/dev/null | sort -n -r | head -20
```

### 4. 查看特定目录空间

```bash
# 查看日志目录大小
du -sh /var/log
du -sh /mnt/UDISK/logs

# 查看配置目录
du -sh /etc
du -sh /overlay/upper/etc

# 查看录像目录
du -sh /mnt/extsd/recordings
du -sh /mnt/UDISK/recordings
```

---

## 空间监控与告警

### 检查空间使用脚本

```bash
#!/bin/sh
# 空间监控脚本

# 检查根分区使用率
ROOT_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $ROOT_USAGE -gt 80 ]; then
    echo "警告: 根分区使用率 ${ROOT_USAGE}%，请清理空间！"
fi

# 检查 UDISK 使用率
UDISK_USAGE=$(df /mnt/UDISK | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $UDISK_USAGE -gt 90 ]; then
    echo "警告: UDISK 使用率 ${UDISK_USAGE}%，空间不足！"
fi

# 检查 SD 卡使用率
if mountpoint -q /mnt/extsd; then
    SD_USAGE=$(df /mnt/extsd | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $SD_USAGE -gt 90 ]; then
        echo "警告: SD卡使用率 ${SD_USAGE}%，空间不足！"
    fi
else
    echo "提示: SD卡未挂载"
fi

# 显示详细信息
echo ""
echo "=== 空间使用详情 ==="
df -h | grep -E "(Filesystem|overlay|mtdblock|mmcblk)"
```

**使用方法**：
```bash
# 保存脚本
cat > /mnt/UDISK/check_space.sh << 'EOF'
# (上面的脚本内容)
EOF

chmod +x /mnt/UDISK/check_space.sh

# 运行
/mnt/UDISK/check_space.sh

# 添加到定时任务（每小时检查一次）
echo "0 * * * * /mnt/UDISK/check_space.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## 空间清理策略

### 1. 清理根分区 (overlay)

```bash
# 查看 overlay 占用
du -sh /overlay/upper
du -h /overlay/upper/* | sort -hr

# 清理临时文件
rm -rf /overlay/upper/tmp/*

# 清理旧日志
rm -rf /overlay/upper/var/log/*.old
rm -rf /overlay/upper/var/log/*.gz

# 卸载不用的软件包
opkg list-installed
opkg remove <package-name>

# 清理软件包缓存
opkg clean
```

### 2. 清理 UDISK

```bash
# 查看 UDISK 占用
du -sh /mnt/UDISK/*

# 清理旧日志（保留最近 3 天）
find /mnt/UDISK/logs -name "*.log" -mtime +3 -delete

# 清理旧录像（保留最近 1 天）
find /mnt/UDISK/recordings -name "*.mp4" -mtime +1 -delete

# 清理临时文件
rm -rf /mnt/UDISK/tmp/*
```

### 3. 清理 SD 卡

```bash
# 查看 SD 卡占用
du -sh /mnt/extsd/*

# 清理旧录像（保留最近 7 天）
find /mnt/extsd/recordings -name "*.mp4" -mtime +7 -delete

# 清理备份文件
find /mnt/extsd/backup -name "*.bak" -mtime +30 -delete
```

### 4. 清理临时文件

```bash
# 清理 /tmp（重启后自动清空）
rm -rf /tmp/*

# 清理进程缓存
sync
echo 3 > /proc/sys/vm/drop_caches
```

---

## MTD 分区原始信息

### 查看 MTD 分区

```bash
# 查看分区列表
cat /proc/mtd

# 示例输出
dev:    size   erasesize  name
mtd0: 00100000 00010000 "uboot"
mtd1: 00080000 00010000 "boot-resource"
mtd2: 00020000 00010000 "env"
mtd3: 00020000 00010000 "env-redund"
mtd4: 00500000 00010000 "boot"
mtd5: 00010000 00010000 "private"
mtd6: 00130000 00010000 "riscv0"
mtd7: 00570000 00010000 "rootfs"
mtd8: 00080000 00010000 "rootfs_data"
mtd9: 01210000 00010000 "UDISK"
```

### 查看 MTD 设备信息

```bash
# 查看所有 MTD 设备
ls -l /dev/mtd*

# 查看 sysfs 信息
cat /sys/class/mtd/mtd8/size          # 分区大小（字节）
cat /sys/class/mtd/mtd8/erasesize     # 擦除块大小
cat /sys/class/mtd/mtd8/name          # 分区名称
cat /sys/class/mtd/mtd8/type          # 类型（nor/nand）

# 查看所有 MTD 分区大小
for i in 0 1 2 3 4 5 6 7 8 9; do
    name=$(cat /sys/class/mtd/mtd$i/name)
    size=$(cat /sys/class/mtd/mtd$i/size)
    size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
    printf "mtd%-2d %-15s %10d bytes  %.2f MB\n" $i "$name" $size $size_mb
done
```

---

## 挂载点管理

### 查看挂载信息

```bash
# 查看所有挂载点
mount

# 查看挂载点（简洁格式）
cat /proc/mounts

# 只看存储设备挂载
mount | grep -E "(mtdblock|mmcblk|overlay)"

# 检查某个目录是否是挂载点
mountpoint /mnt/UDISK
mountpoint /mnt/extsd
```

### 手动挂载/卸载

```bash
# 挂载 UDISK（如果未自动挂载）
mkdir -p /mnt/UDISK
mount -t jffs2 /dev/mtdblock9 /mnt/UDISK

# 挂载 SD 卡
mkdir -p /mnt/extsd
mount -t vfat /dev/mmcblk0p1 /mnt/extsd

# 卸载（确保没有进程使用）
umount /mnt/UDISK
umount /mnt/extsd

# 强制卸载（慎用）
umount -f /mnt/extsd

# 查看哪些进程在使用挂载点
lsof /mnt/extsd
fuser -m /mnt/extsd
```

### 重新挂载

```bash
# 重新挂载为只读
mount -o remount,ro /mnt/UDISK

# 重新挂载为可写
mount -o remount,rw /mnt/UDISK
```

---

## 存储性能测试

### 写入速度测试

```bash
# 测试 UDISK 写入速度
dd if=/dev/zero of=/mnt/UDISK/test.dat bs=1M count=10
rm /mnt/UDISK/test.dat

# 测试 SD 卡写入速度
dd if=/dev/zero of=/mnt/extsd/test.dat bs=1M count=100
rm /mnt/extsd/test.dat

# 测试 tmpfs 写入速度
dd if=/dev/zero of=/tmp/test.dat bs=1M count=10
```

### 读取速度测试

```bash
# 先创建测试文件
dd if=/dev/zero of=/mnt/extsd/test.dat bs=1M count=100

# 测试读取速度
dd if=/mnt/extsd/test.dat of=/dev/null bs=1M

# 清理
rm /mnt/extsd/test.dat
```

---

## 常见问题

### Q1: 为什么 `/` 和 `/overlay` 显示的空间相同？

**A**: 因为 `/` 是 OverlayFS 挂载点，它显示的是 `/overlay`（实际存储在 mtd8）的空间。

```
/overlay (mtd8, 512KB) → / (OverlayFS 合并视图)
```

### Q2: `/rom` 显示 100% 使用正常吗？

**A**: 完全正常。`/rom` 是只读压缩文件系统（SquashFS），它被完全填满是预期行为。

### Q3: 如何判断哪些文件占用了 overlay 空间？

**A**:
```bash
# 查看 overlay 实际占用的文件
du -h /overlay/upper | sort -hr | head -20

# 查看具体大文件
find /overlay/upper -type f -size +10k -exec ls -lh {} \;
```

### Q4: SD 卡未自动挂载怎么办？

**A**:
```bash
# 检查 SD 卡是否被识别
dmesg | grep mmc

# 查看块设备
ls -l /dev/mmcblk*

# 手动挂载
mkdir -p /mnt/extsd
mount /dev/mmcblk0p1 /mnt/extsd

# 检查是否挂载成功
df -h /mnt/extsd
```

### Q5: UDISK 空间满了怎么办？

**A**:
```bash
# 1. 查看占用
du -sh /mnt/UDISK/*

# 2. 删除大文件
find /mnt/UDISK -type f -size +1M -exec ls -lh {} \;

# 3. 清理日志
find /mnt/UDISK/logs -name "*.log" -mtime +3 -delete

# 4. 如果彻底损坏，重新格式化（数据会丢失！）
umount /mnt/UDISK
flash_eraseall /dev/mtd9
mount -t jffs2 /dev/mtdblock9 /mnt/UDISK
```

### Q6: 如何查看实时的磁盘 I/O？

**A**:
```bash
# 查看块设备 I/O 统计
cat /proc/diskstats

# 如果有 iostat（openwrt 通常没有）
iostat -x 1

# 查看进程 I/O
cat /proc/<pid>/io
```

---

## 空间使用建议

### ✅ 推荐做法

| 数据类型 | 推荐位置 | 原因 |
|---------|---------|------|
| **小配置文件** (< 10KB) | `/etc` | 自动保存到 overlay |
| **大配置文件** | `/mnt/UDISK/config` | 不占用宝贵的 overlay |
| **数据库** | `/mnt/UDISK/db` | UDISK 空间较大 |
| **小日志** (< 1MB) | `/mnt/UDISK/logs` | 支持断电保护 |
| **大日志** | `/mnt/extsd/logs` | SD 卡容量大 |
| **录像文件** | `/mnt/extsd/recordings` | 必须用 SD 卡 |
| **临时文件** | `/tmp` | RAM 速度快，重启清空 |
| **处理中间文件** | `/tmp` | 不占 Flash 空间 |

### 🔴 避免做法

| 操作 | 危害 | 替代方案 |
|-----|------|---------|
| 在 `/` 下创建大文件 | 快速耗尽 overlay 空间 | 用 `/mnt/UDISK` 或 `/mnt/extsd` |
| 日志直接写 `/var/log` | 占用 overlay | 重定向到 `/mnt/UDISK/logs` |
| 安装大软件包 | 耗尽 overlay | 编译时集成到系统 |
| 频繁写入 Flash | 降低寿命 | 用 `/tmp` 做缓存 |

---

## 空间管理脚本示例

### 自动清理旧文件脚本

```bash
#!/bin/sh
# /mnt/UDISK/scripts/auto_cleanup.sh

# 配置
UDISK_LOG_DIR="/mnt/UDISK/logs"
UDISK_RECORDING_DIR="/mnt/UDISK/recordings"
SD_RECORDING_DIR="/mnt/extsd/recordings"

LOG_RETENTION_DAYS=3
UDISK_RECORDING_RETENTION_DAYS=1
SD_RECORDING_RETENTION_DAYS=7

# 清理 UDISK 日志
echo "清理 UDISK 旧日志（保留 ${LOG_RETENTION_DAYS} 天）..."
find $UDISK_LOG_DIR -name "*.log" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null
find $UDISK_LOG_DIR -name "*.log.*" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null

# 清理 UDISK 录像
if [ -d "$UDISK_RECORDING_DIR" ]; then
    echo "清理 UDISK 旧录像（保留 ${UDISK_RECORDING_RETENTION_DAYS} 天）..."
    find $UDISK_RECORDING_DIR -name "*.mp4" -mtime +$UDISK_RECORDING_RETENTION_DAYS -delete 2>/dev/null
fi

# 清理 SD 卡录像
if mountpoint -q /mnt/extsd && [ -d "$SD_RECORDING_DIR" ]; then
    echo "清理 SD 卡旧录像（保留 ${SD_RECORDING_RETENTION_DAYS} 天）..."
    find $SD_RECORDING_DIR -name "*.mp4" -mtime +$SD_RECORDING_RETENTION_DAYS -delete 2>/dev/null
fi

# 清理临时文件
echo "清理临时文件..."
rm -rf /tmp/*.tmp 2>/dev/null

# 检查空间
echo ""
echo "=== 清理后空间使用情况 ==="
df -h | grep -E "(Filesystem|overlay|mtdblock|mmcblk)"

echo ""
echo "清理完成！"
```

**设置定时任务**：
```bash
# 每天凌晨 2 点执行清理
echo "0 2 * * * /mnt/UDISK/scripts/auto_cleanup.sh >> /mnt/UDISK/logs/cleanup.log 2>&1" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## 总结

### 关键指标监控

定期检查以下指标：

1. **根分区使用率** < 80%
   ```bash
   df -h / | tail -1 | awk '{print $5}'
   ```

2. **UDISK 使用率** < 90%
   ```bash
   df -h /mnt/UDISK | tail -1 | awk '{print $5}'
   ```

3. **SD 卡使用率** < 90%
   ```bash
   df -h /mnt/extsd | tail -1 | awk '{print $5}'
   ```

4. **overlay 实际占用** < 400KB
   ```bash
   du -sh /overlay/upper
   ```

### 快速参考

```bash
# 查看空间
df -h

# 查看目录大小
du -sh <directory>

# 查找大文件
find / -type f -size +100k 2>/dev/null

# 清理空间
rm -rf /tmp/*
opkg clean

# 监控实时使用
watch -n 1 'df -h | grep -E "(overlay|UDISK|extsd)"'
```

---

**相关文档**：
- [FLASH_PARTITION_LAYOUT.md](FLASH_PARTITION_LAYOUT.md) - Flash 分区布局详解
- [PROC_FILESYSTEM_GUIDE.md](PROC_FILESYSTEM_GUIDE.md) - /proc 文件系统指南

**更新日期**：2025-01-16
