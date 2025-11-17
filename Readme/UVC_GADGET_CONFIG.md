# V821 UVC Gadget 配置指南

## 概述

将 V821 配置为 UVC (USB Video Class) Gadget 设备,可以让它通过 USB 线连接到电脑,电脑会将其识别为标准 USB 摄像头,无需安装额外驱动。

## 架构说明

```
┌─────────────┐  USB   ┌──────────────┐
│   电脑/主机   │◄──────►│  V821 开发板   │
│ (UVC Host)  │        │ (UVC Device) │
└─────────────┘        └──────────────┘
                              │
                              │ 摄像头数据
                              ▼
                       ┌──────────────┐
                       │  GC02M1 传感器 │
                       └──────────────┘
```

**数据流程**:
1. GC02M1 MIPI 传感器 → VIN (Video Input) 驱动
2. eyesee-mpp 或 rt_media → 视频编码 (H.264/MJPEG/YUV)
3. rt_media-uvc 应用 → UVC Gadget 驱动
4. USB 硬件 → 主机电脑

## 当前系统状态

### 已配置项 ✓

1. **USB 硬件模式**: Device 模式
   ```dts
   // device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts:917
   &usbc0 {
       device_type = "usbc0";
       usb_port_type = <0x0>;  // 0=device, 1=host, 2=otg
       status = "okay";
   };
   ```

2. **内核 USB Gadget 支持**: 已启用
   ```
   CONFIG_USB_GADGET=y
   CONFIG_USB_CONFIGFS=y
   ```

3. **UVC 驱动**: 已包含
   - 内核模块: `usb_sunxi_f_uvc.ko`
   - 自动加载脚本: [S01usb](openwrt/target/v821/v821-avaota_f1/busybox-init-base-files/etc/init.d/S01usb)

### 未启用项 ✗

1. **UVC 内核模块**: 未编译
   ```
   # CONFIG_PACKAGE_kmod-sunxi-uvc is not set
   ```

2. **UVC 应用程序**: 未编译
   ```
   # CONFIG_PACKAGE_rt_media-uvc is not set
   ```

## 配置步骤

### 步骤 1: 启用 UVC 内核模块

```bash
# 进入 Tina 根目录
cd /home/f/tina/tina-v821-camera

# 运行 menuconfig
make menuconfig
```

在菜单中导航到:
```
Kernel modules
  └─> USB Support
      └─> <M> kmod-sunxi-uvc .......... sunxi uvc support (staging)
```

按 `M` 选择为模块,或按 `Y` 编译进内核。

**或者直接修改配置文件**:

```bash
# 编辑 defconfig
vim openwrt/target/v821/v821-avaota_f1/defconfig

# 找到并修改:
# CONFIG_PACKAGE_kmod-sunxi-uvc is not set
# 改为:
CONFIG_PACKAGE_kmod-sunxi-uvc=y
```

### 步骤 2: 启用 UVC 应用程序

在 menuconfig 中:
```
Allwinner
  └─> Multimedia
      └─> <*> rt_media-uvc .......... The chip-V uvcout demo
```

**或者直接修改配置文件**:

```bash
# 找到并修改:
# CONFIG_PACKAGE_rt_media-uvc is not set
# 改为:
CONFIG_PACKAGE_rt_media-uvc=y
```

### 步骤 3: 重新编译

```bash
# 编译内核模块
make kernel_menuconfig  # (可选,检查内核配置)
make kernel -j$(nproc)

# 编译软件包
make package/rt_media-uvc/compile V=s
make package/kmod-sunxi-uvc/compile V=s

# 或全量编译
make -j$(nproc)
```

### 步骤 4: 烧录固件

```bash
# 打包固件
pack

# 烧录到设备(根据你的烧录方式)
# 方式 1: SD 卡烧录
# 方式 2: USB 烧录工具
# 方式 3: TFTP 网络更新
```

## 运行 UVC Gadget

### 1. 加载内核模块

系统启动后,`/etc/init.d/S01usb` 会自动加载 UVC 模块:

```bash
# 手动加载(如果未自动加载)
modprobe videobuf2-vmalloc
modprobe usb_sunxi_f_uvc

# 验证模块已加载
lsmod | grep uvc
```

### 2. 运行 UVC 应用程序

```bash
# 运行 rt_media-uvc
rt_media-uvc --help

# 基本使用示例
rt_media-uvc -v 0  # 使用 vipp0 (video input port)

# 高级选项
rt_media-uvc \
    -v 0 \              # VIPP 设备号
    -u 0 \              # UVC 设备号
    -b 2000000 \        # 比特率 2Mbps
    -d 0 \              # 双流模式关闭
    --uac-in 1 \        # 启用 UAC 音频输入
    --uac-out 1         # 启用 UAC 音频输出
```

### 3. 主机端连接

**Linux 主机**:
```bash
# 连接 USB 线后,检测 UVC 设备
lsusb  # 应该看到 UVC 设备

# 查看视频设备
ls /dev/video*

# 使用 v4l2 工具测试
v4l2-ctl --list-devices
v4l2-ctl -d /dev/video0 --list-formats-ext

# 使用 ffplay 查看
ffplay /dev/video0

# 使用 VLC
vlc v4l2:///dev/video0

# 录制视频
ffmpeg -i /dev/video0 -c:v copy output.h264
```

**Windows 主机**:
- 插入 USB 线后,设备管理器中应出现"USB 视频设备"
- 打开"相机"应用或 OBS Studio 即可使用
- 使用 VLC: 媒体 → 打开捕获设备 → 视频设备名称

**macOS 主机**:
- 插入 USB 线
- 打开 Photo Booth、FaceTime 或其他摄像头应用
- 在摄像头列表中选择 V821 UVC 设备

## ConfigFS 配置 (高级)

UVC Gadget 使用 ConfigFS 进行配置,通常由 `rt_media-uvc` 自动处理。手动配置示例:

```bash
# 挂载 configfs (通常系统已自动挂载)
mount -t configfs none /sys/kernel/config

# 创建 gadget
cd /sys/kernel/config/usb_gadget
mkdir g1
cd g1

# 配置设备描述符
echo 0x1d6b > idVendor    # Linux Foundation
echo 0x0104 > idProduct   # Multifunction Composite Gadget
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# 配置字符串
mkdir strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "Allwinner" > strings/0x409/manufacturer
echo "V821 UVC Camera" > strings/0x409/product

# 创建配置
mkdir configs/c.1
mkdir configs/c.1/strings/0x409
echo "UVC" > configs/c.1/strings/0x409/configuration
echo 500 > configs/c.1/MaxPower

# 创建 UVC 功能
mkdir functions/uvc.0

# 链接功能到配置
ln -s functions/uvc.0 configs/c.1/

# 绑定到 UDC (USB Device Controller)
echo $(ls /sys/class/udc) > UDC
```

## rt_media-uvc 源码说明

**主要文件**:
- [rt_media-uvc.c](openwrt/package/allwinner/multimedia/rt_media-uvc/src/rt_media-uvc.c) - 主应用
- [configfs_parser.c](openwrt/package/allwinner/multimedia/rt_media-uvc/src/utils/configfs_parser/configfs_parser.c) - ConfigFS 解析
- [uvc.c](openwrt/package/allwinner/multimedia/rt_media-uvc/src/uvc/libuvc/uvc.c) - UVC 流控制

**功能特性**:
- 支持多种格式: MJPEG, H.264, YUV
- 支持多分辨率: 1920x1080, 1280x720, 640x480 等
- 支持双流模式(同时提供两个视频流)
- 支持 UAC (USB Audio Class) 音频传输
- 支持 AEC (回声消除), AGC (自动增益), ANS (降噪)

## 参数配置

### rt_media-uvc 命令行参数

```bash
rt_media-uvc 参数说明:
  -v, --vipp <num>              VIPP 设备号 (默认: 0)
  -u, --uvc <num>               UVC 设备号 (默认: 0)
  -b, --bitrate <bps>           视频比特率 (默认: 2000000)
  -d, --dual-stream <0|1>       双流模式 (默认: 0)
  --dual-stream-vipp <num>      双流 VIPP 设备号
  --uvc-bulk                    使用 Bulk 传输模式(默认 Isochronous)

  # UAC (音频) 参数
  --uac-in <0|1>                启用音频输入
  --uac-out <0|1>               启用音频输出
  --uac-sr <rate>               音频采样率 (8000/16000/44100/48000)
  --uac-ch <1|2>                音频通道数
  --uac-bw <8|16|24>            音频位宽
  --uac-aec <0|1>               启用 AEC 回声消除
  --uac-agc <0|1>               启用 AGC 自动增益
  --uac-ans <0|1>               启用 ANS 降噪
```

### 典型使用场景

**场景 1: 基本 USB 摄像头**
```bash
rt_media-uvc -v 0 -b 2000000
```

**场景 2: 高质量视频会议**
```bash
rt_media-uvc \
    -v 0 \
    -b 4000000 \
    --uac-in 1 \
    --uac-sr 48000 \
    --uac-ch 1 \
    --uac-aec 1 \
    --uac-agc 1 \
    --uac-ans 1
```

**场景 3: 低延迟监控**
```bash
rt_media-uvc -v 0 -b 1000000 --uvc-bulk
```

## 故障排查

### 问题 1: 主机无法识别设备

**检查步骤**:
```bash
# 1. 确认 USB 处于 device 模式
cat /sys/class/udc/*/device/mode  # 应显示 "device"

# 2. 确认 UVC 模块已加载
lsmod | grep uvc

# 3. 检查 UVC 设备节点
ls -l /dev/video*

# 4. 查看 USB 枚举日志
dmesg | grep -i usb | tail -20
```

**常见原因**:
- USB 线缆不支持数据传输(仅充电线)
- USB 模式配置错误
- UVC 应用未运行

### 问题 2: 视频有图像但卡顿

**优化方法**:
```bash
# 1. 降低比特率
rt_media-uvc -v 0 -b 1000000  # 从 2Mbps 降到 1Mbps

# 2. 降低分辨率(需在 ConfigFS 中配置)

# 3. 使用 Bulk 传输模式
rt_media-uvc -v 0 --uvc-bulk

# 4. 增加 ION 内存(参考 DDR_LINUX_ION_RELATIONSHIP.md)
```

### 问题 3: 传感器初始化失败

参考 [GC02M1_SENSOR_DEBUG.md](GC02M1_SENSOR_DEBUG.md) 进行传感器调试。

### 问题 4: 音频不工作

```bash
# 检查 UAC 模块
lsmod | grep uac

# 手动加载 UAC 模块
modprobe usb_sunxi_f_uac1

# 检查 ALSA 设备
aplay -l
arecord -l

# 测试音频录制
arecord -D hw:0,0 -f S16_LE -r 48000 -c 1 -d 5 test.wav
```

## 性能优化

### 1. ION 内存分配

UVC 需要大量连续内存用于视频缓冲,建议:
```dts
// board.dts
heap_size_pool@0 {
    heap-size = <0x01C00000>;  // 28 MB (与 size_pool 相同)
};
```

参考: [DDR_LINUX_ION_RELATIONSHIP.md](DDR_LINUX_ION_RELATIONSHIP.md)

### 2. USB 带宽计算

**USB 2.0 高速模式**:
- 理论带宽: 480 Mbps
- 实际可用: ~300 Mbps (受协议开销影响)

**视频格式带宽需求**:
- 1080p30 MJPEG: ~50-100 Mbps (取决于质量)
- 1080p30 H.264: ~2-4 Mbps
- 720p30 MJPEG: ~20-40 Mbps
- 720p30 H.264: ~1-2 Mbps

**建议**: 使用 H.264 编码以降低带宽需求。

### 3. CPU 负载优化

```bash
# 使用硬件编码器 (eyesee-mpp)
# rt_media-uvc 默认使用硬件编码

# 监控 CPU 使用率
top

# 调整编码器优先级
renice -n -10 $(pidof rt_media-uvc)
```

## 自动启动配置

创建启动脚本:

```bash
# 编辑 /etc/init.d/S99uvc
vi /etc/init.d/S99uvc
```

内容:
```bash
#!/bin/sh

start() {
    echo "Starting UVC gadget..."

    # 确保模块已加载
    modprobe usb_sunxi_f_uvc
    modprobe usb_sunxi_f_uac1

    # 等待设备准备
    sleep 2

    # 启动 UVC 应用
    rt_media-uvc -v 0 -b 2000000 --uac-in 1 --uac-sr 48000 &

    echo "UVC gadget started"
}

stop() {
    echo "Stopping UVC gadget..."
    killall rt_media-uvc
    rmmod usb_sunxi_f_uvc
    rmmod usb_sunxi_f_uac1
    echo "UVC gadget stopped"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac

exit 0
```

```bash
# 添加执行权限
chmod +x /etc/init.d/S99uvc
```

## 相关文档

- [CLAUDE.md](../CLAUDE.md) - 项目开发指南
- [GC02M1_SENSOR_DEBUG.md](GC02M1_SENSOR_DEBUG.md) - 传感器调试
- [DDR_LINUX_ION_RELATIONSHIP.md](DDR_LINUX_ION_RELATIONSHIP.md) - 内存管理
- [FLASH_PARTITION_LAYOUT.md](FLASH_PARTITION_LAYOUT.md) - 存储分区

## 参考资料

- Linux USB Gadget 文档: https://www.kernel.org/doc/html/latest/usb/gadget.html
- UVC 规范: https://www.usb.org/document-library/video-class-v15-document-set
- V4L2 文档: https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/v4l2.html

## 快速检查清单

使用此清单确认 UVC Gadget 配置:

- [ ] USB 硬件配置为 Device 模式 (`usb_port_type = 0`)
- [ ] 内核启用 `CONFIG_USB_GADGET=y`
- [ ] 编译 `kmod-sunxi-uvc` 模块
- [ ] 编译 `rt_media-uvc` 应用
- [ ] 传感器驱动正常工作
- [ ] ION 内存配置充足(≥20MB)
- [ ] UVC 模块自动加载或手动加载成功
- [ ] `rt_media-uvc` 应用运行无错误
- [ ] USB 连接到主机后设备被识别
- [ ] 主机端能看到视频流

## 总结

V821 UVC Gadget 配置涉及:
1. **硬件**: USB Device 模式配置
2. **内核**: USB Gadget 框架和 UVC 驱动
3. **应用**: rt_media-uvc 应用程序
4. **集成**: 传感器 → eyesee-mpp → UVC Gadget

关键配置命令:
```bash
# 1. menuconfig 启用 UVC
make menuconfig

# 2. 编译
make -j$(nproc)

# 3. 运行
rt_media-uvc -v 0 -b 2000000
```
