# V821 串口使用指南

## 概述

V821 支持 4 个 UART (UART0-UART3),本文档重点介绍 **UART3 (ttyS3)** 的配置和使用。

## 硬件配置

### UART3 引脚定义

| 信号 | GPIO | 功能 | 说明 |
|------|------|------|------|
| TX | PL2 | 发送 | 数据输出 |
| RX | PL3 | 接收 | 数据输入 |

**电平**: 3.3V TTL

**设备节点**: `/dev/ttyS3`

### 设备树配置

位置: [device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts](device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts#L375-L380)

```dts
&uart3 {
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <&uart3_pins_default>;
    pinctrl-1 = <&uart3_pins_sleep>;
    status = "okay";
};

// GPIO 引脚配置
uart3_pins_default: uart3_pins@0 {
    pins = "PL2", "PL3";
    function = "uart3";
};
```

### 驱动信息

从内核日志可以看到 UART3 已成功初始化:

```
uart-ng3: ttyS3 at MMIO 0x42500c00 (irq = 135, base_baud = 12000000) is a SUNXI
```

- **基地址**: 0x42500C00
- **中断号**: 135
- **基础波特率**: 12 MHz
- **驱动**: uart-ng (Allwinner 新一代 UART 驱动)

## 支持的波特率

```
300, 600, 1200, 2400, 4800, 9600, 19200, 38400,
57600, 115200, 230400, 460800, 921600, 1000000,
1500000, 2000000, 3000000, 4000000
```

常用: **9600**, **115200**, **230400**, **921600**

## 设置波特率

### 使用 stty 命令 (推荐)

如果系统已包含 stty 命令,可以直接使用:

```bash
# 查看当前配置
stty -F /dev/ttyS3 -a

# 设置为 115200, 8N1 (8数据位, 无校验, 1停止位)
stty -F /dev/ttyS3 115200 cs8 -cstopb -parenb

# 原始模式配置 (推荐,用于数据传输)
stty -F /dev/ttyS3 115200 cs8 -cstopb -parenb raw -echo

# 只查看波特率
stty -F /dev/ttyS3 speed

# 验证配置是否生效
stty -F /dev/ttyS3 -a | head -n 1
```

**常用波特率配置:**

```bash
# 9600 (GPS模块常用)
stty -F /dev/ttyS3 9600 cs8 -cstopb -parenb

# 38400 (蓝牙AT模式)
stty -F /dev/ttyS3 38400 cs8 -cstopb -parenb

# 115200 (Arduino/通用设备)
stty -F /dev/ttyS3 115200 cs8 -cstopb -parenb

# 230400 (高速传输)
stty -F /dev/ttyS3 230400 cs8 -cstopb -parenb

# 921600 (超高速,短距离)
stty -F /dev/ttyS3 921600 cs8 -cstopb -parenb
```

**stty 参数说明:**

| 参数 | 说明 |
|------|------|
| `-F /dev/ttyS3` | 指定设备 |
| `115200` | 波特率 |
| `cs8` | 8数据位 (cs7=7位, cs6=6位, cs5=5位) |
| `-cstopb` | 1停止位 (cstopb=2停止位) |
| `-parenb` | 无校验 (parenb=启用校验) |
| `parenb parodd` | 奇校验 |
| `parenb -parodd` | 偶校验 |
| `raw` | 原始模式,无字符处理 |
| `-echo` | 不回显输入 |
| `clocal` | 忽略调制解调器控制线 |
| `-crtscts` | 禁用硬件流控 |

**完整配置示例:**

```bash
# 115200, 8N1, 原始模式, 无流控
stty -F /dev/ttyS3 115200 cs8 -cstopb -parenb raw -echo clocal -crtscts

# 9600, 8E1 (8数据位,偶校验,1停止位)
stty -F /dev/ttyS3 9600 cs8 parenb -parodd -cstopb

# 19200, 7E1 (7数据位,偶校验,1停止位) - Modbus常用
stty -F /dev/ttyS3 19200 cs7 parenb -parodd -cstopb
```

### 如果系统缺少 stty 命令

某些精简固件可能**没有包含 stty 工具**,需要通过以下方式之一解决:

### 方法1: 启用 stty 命令(推荐)

修改 busybox 配置,重新编译固件:

```bash
# 在 Tina 根目录
cd /home/f/tina/tina-v821-camera

# 配置 menuconfig
make menuconfig
```

导航到:
```
Base system
  └─> busybox
      └─> Configuration
          └─> Coreutils
              └─> [*] stty
```

保存后重新编译:
```bash
make package/utils/busybox/compile V=s
make package/utils/busybox/install V=s
pack
```

烧录新固件后,stty 命令就可以使用了。

### 方法2: 使用自定义 C 程序

创建 `setbaud.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int fd, baud;
    struct termios tty;

    if (argc != 3) {
        printf("Usage: %s <device> <baudrate>\n", argv[0]);
        printf("Example: %s /dev/ttyS3 115200\n", argv[0]);
        printf("\nSupported baudrates:\n");
        printf("  9600, 19200, 38400, 57600, 115200\n");
        printf("  230400, 460800, 921600\n");
        return 1;
    }

    fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) {
        perror("Error opening device");
        return 1;
    }

    if (tcgetattr(fd, &tty) != 0) {
        perror("Error getting attributes");
        close(fd);
        return 1;
    }

    baud = atoi(argv[2]);
    speed_t speed;

    switch(baud) {
        case 9600:   speed = B9600; break;
        case 19200:  speed = B19200; break;
        case 38400:  speed = B38400; break;
        case 57600:  speed = B57600; break;
        case 115200: speed = B115200; break;
        case 230400: speed = B230400; break;
        case 460800: speed = B460800; break;
        case 921600: speed = B921600; break;
        default:
            printf("Unsupported baudrate: %d\n", baud);
            printf("Use one of: 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600\n");
            close(fd);
            return 1;
    }

    // 设置波特率
    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    // 配置为 8N1
    tty.c_cflag &= ~PARENB;        // 无校验
    tty.c_cflag &= ~CSTOPB;        // 1停止位
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;            // 8数据位
    tty.c_cflag &= ~CRTSCTS;       // 无硬件流控
    tty.c_cflag |= CREAD | CLOCAL; // 使能接收,本地模式

    // 原始模式
    tty.c_lflag &= ~ICANON;        // 非规范模式
    tty.c_lflag &= ~ECHO;          // 不回显
    tty.c_lflag &= ~ECHOE;
    tty.c_lflag &= ~ISIG;

    // 禁用软件流控
    tty.c_iflag &= ~(IXON | IXOFF | IXANY);

    // 原始输出
    tty.c_oflag &= ~OPOST;

    // 超时设置
    tty.c_cc[VMIN] = 0;
    tty.c_cc[VTIME] = 10;  // 1秒超时

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        perror("Error setting attributes");
        close(fd);
        return 1;
    }

    printf("✓ %s configured: %d baud, 8N1\n", argv[1], baud);

    close(fd);
    return 0;
}
```

**交叉编译:**

```bash
# 在 Tina 目录
cd /home/f/tina/tina-v821-camera

# 加载环境变量
source build/envsetup.sh

# 编译
riscv32-unknown-linux-gnu-gcc setbaud.c -o setbaud

# 传输到设备(通过网络或 SD 卡)
# 例如通过 scp:
scp setbaud root@<设备IP>:/usr/bin/

# 或放到 SD 卡
cp setbaud /mnt/extsd/
```

**在设备上使用:**

```bash
# 添加执行权限
chmod +x /usr/bin/setbaud

# 设置波特率
setbaud /dev/ttyS3 115200

# 验证
setbaud /dev/ttyS3 9600
```

### 方法3: Python 脚本(如果系统有 Python)

创建 `uart_config.py`:

```python
#!/usr/bin/env python3
import sys
import serial

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <device> <baudrate>")
    print(f"Example: {sys.argv[0]} /dev/ttyS3 115200")
    sys.exit(1)

device = sys.argv[1]
baudrate = int(sys.argv[2])

try:
    ser = serial.Serial(
        port=device,
        baudrate=baudrate,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1
    )
    print(f"✓ {device} configured: {baudrate} baud, 8N1")
    ser.close()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
```

使用:
```bash
python3 uart_config.py /dev/ttyS3 115200
```

## 基本使用

### 查看设备

```bash
# 检查设备节点
ls -l /dev/ttyS*

# 输出示例:
# crw------- 1 root root 246, 0 Jan  1 00:00 /dev/ttyS0
# crw------- 1 root root 246, 3 Jan  1 00:00 /dev/ttyS3
```

### 修改权限

```bash
# 允许所有用户访问
chmod 666 /dev/ttyS3

# 验证
ls -l /dev/ttyS3
# crw-rw-rw- 1 root root 246, 3 ...
```

### 发送数据

```bash
# 简单发送
echo "Hello UART3" > /dev/ttyS3

# 发送十六进制数据
echo -ne '\x41\x42\x43' > /dev/ttyS3  # 发送 ABC

# 持续发送(每秒一次)
while true; do
    echo "Heartbeat $(date +%s)" > /dev/ttyS3
    sleep 1
done
```

### 接收数据

```bash
# 阻塞读取
cat /dev/ttyS3

# 后台读取
cat /dev/ttyS3 &

# 查看十六进制
cat /dev/ttyS3 | hexdump -C

# 查看可打印字符
cat /dev/ttyS3 | od -A x -t x1z -v
```

### 自测试(回环测试)

**硬件连接**: 短接 PL2 和 PL3

```bash
# 终端1: 监听
cat /dev/ttyS3 &

# 终端2: 发送
echo "Loopback test" > /dev/ttyS3

# 应该在终端1看到 "Loopback test"

# 停止监听
killall cat
```

## 编程示例

### C 语言完整示例

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>

// 配置串口
int uart_init(const char *device, int baud) {
    int fd = open(device, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fd == -1) {
        perror("open");
        return -1;
    }

    struct termios options;
    tcgetattr(fd, &options);

    // 设置波特率
    speed_t speed;
    switch(baud) {
        case 9600:   speed = B9600; break;
        case 115200: speed = B115200; break;
        case 230400: speed = B230400; break;
        case 921600: speed = B921600; break;
        default:
            fprintf(stderr, "Unsupported baud rate\n");
            close(fd);
            return -1;
    }

    cfsetispeed(&options, speed);
    cfsetospeed(&options, speed);

    // 8N1
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;
    options.c_cflag &= ~CRTSCTS;
    options.c_cflag |= (CLOCAL | CREAD);

    // 原始模式
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_oflag &= ~OPOST;
    options.c_iflag &= ~(IXON | IXOFF | IXANY);

    options.c_cc[VMIN] = 0;
    options.c_cc[VTIME] = 10;

    tcsetattr(fd, TCSANOW, &options);

    return fd;
}

// 发送数据
int uart_send(int fd, const char *data, int len) {
    int n = write(fd, data, len);
    if (n < 0) {
        perror("write");
        return -1;
    }
    return n;
}

// 接收数据
int uart_recv(int fd, char *buffer, int max_len) {
    int n = read(fd, buffer, max_len);
    if (n < 0) {
        perror("read");
        return -1;
    }
    return n;
}

int main() {
    int fd;
    char buffer[256];
    int n;

    // 打开并配置串口
    fd = uart_init("/dev/ttyS3", 115200);
    if (fd < 0) {
        fprintf(stderr, "Failed to initialize UART\n");
        return 1;
    }

    printf("UART3 initialized at 115200 baud\n");

    // 发送测试
    const char *msg = "Hello from V821\r\n";
    uart_send(fd, msg, strlen(msg));
    printf("Sent: %s", msg);

    // 接收测试(等待5秒)
    printf("Waiting for data...\n");
    for (int i = 0; i < 50; i++) {
        n = uart_recv(fd, buffer, sizeof(buffer) - 1);
        if (n > 0) {
            buffer[n] = '\0';
            printf("Received (%d bytes): %s\n", n, buffer);
        }
        usleep(100000); // 100ms
    }

    close(fd);
    return 0;
}
```

编译:
```bash
riscv32-unknown-linux-gnu-gcc uart_example.c -o uart_example
```

### Shell 脚本示例

```bash
#!/bin/sh
# uart_test.sh - UART3 测试脚本

DEVICE="/dev/ttyS3"

# 检查设备
if [ ! -c "$DEVICE" ]; then
    echo "Error: $DEVICE not found"
    exit 1
fi

# 设置权限
chmod 666 $DEVICE

# 配置波特率(如果有 setbaud 工具)
if [ -x /usr/bin/setbaud ]; then
    /usr/bin/setbaud $DEVICE 115200
fi

echo "Starting UART3 test..."

# 后台接收
cat $DEVICE > /tmp/uart_rx.log &
CAT_PID=$!

# 发送测试数据
for i in $(seq 1 10); do
    echo "Test message $i" > $DEVICE
    echo "Sent: Test message $i"
    sleep 1
done

# 停止接收
sleep 2
kill $CAT_PID 2>/dev/null

# 显示接收到的数据
echo "Received data:"
cat /tmp/uart_rx.log

rm -f /tmp/uart_rx.log
```

## 连接外部设备

### GPS 模块

```bash
# GPS 通常使用 9600 波特率
setbaud /dev/ttyS3 9600

# 读取 NMEA 数据
cat /dev/ttyS3

# 应该看到类似:
# $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
# $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
```

### Arduino

```bash
# Arduino 默认 9600 或 115200
setbaud /dev/ttyS3 9600

# 发送命令
echo "LED_ON" > /dev/ttyS3

# 接收响应
cat /dev/ttyS3
```

### 蓝牙模块 (HC-05/HC-06)

```bash
# AT 模式 38400
setbaud /dev/ttyS3 38400

# 发送 AT 命令
echo -e "AT\r\n" > /dev/ttyS3

# 接收响应(应返回 OK)
timeout 1 cat /dev/ttyS3
```

### 传感器 (UART 协议)

示例: 读取温湿度传感器

```bash
#!/bin/sh
# 发送查询命令(假设 0x01 0x03 0x00 0x00)
echo -ne '\x01\x03\x00\x00' > /dev/ttyS3

# 读取响应
timeout 1 cat /dev/ttyS3 | hexdump -C
```

## 调试技巧

### 查看内核日志

```bash
# 查看 UART 初始化信息
dmesg | grep -i uart

# 查看实时日志
dmesg -w | grep -i uart
```

### 检查中断

```bash
# 查看 UART 中断计数
cat /proc/interrupts | grep uart

# 输出示例:
# 135:        0  SiFive PLIC  uart-ng3
```

### 查看驱动状态

```bash
# 查看所有 TTY 驱动
cat /proc/tty/drivers

# 查看设备树配置
ls /proc/device-tree/soc@*/uart3/
cat /proc/device-tree/soc@*/uart3/status
```

### GPIO 状态

```bash
# 查看 UART3 引脚复用
cat /sys/kernel/debug/pinctrl/*/pinmux-pins | grep -i uart3
```

## 常见问题

### Q1: 设备节点不存在

**症状**: `ls /dev/ttyS3` 显示 "No such file or directory"

**解决**:
1. 检查设备树: `cat /proc/device-tree/soc@*/uart3/status`
2. 查看内核日志: `dmesg | grep uart3`
3. 确认驱动加载: `cat /proc/tty/drivers | grep uart`

### Q2: 权限被拒绝

**症状**: "Permission denied" when accessing /dev/ttyS3

**解决**:
```bash
chmod 666 /dev/ttyS3
```

或永久修改 (创建 udev 规则):
```bash
echo 'KERNEL=="ttyS3", MODE="0666"' > /etc/udev/rules.d/99-serial.rules
```

### Q3: 数据乱码

**原因**: 波特率不匹配

**解决**:
1. 确认对端设备波特率
2. 重新配置: `stty -F /dev/ttyS3 <正确的波特率> cs8 -cstopb -parenb`
3. 检查数据位、停止位、校验位配置

### Q4: 没有数据

**检查清单**:
1. ✓ 硬件连接正确 (TX→RX, RX→TX)
2. ✓ 电平匹配 (都是 3.3V)
3. ✓ GND 共地
4. ✓ 波特率一致
5. ✓ 设备已上电
6. ✓ 回环测试通过

### Q5: 如何确认波特率设置成功

**方法**:
```bash
# 查看完整配置
stty -F /dev/ttyS3 -a

# 只查看波特率
stty -F /dev/ttyS3 speed

# 或查看第一行(包含波特率)
stty -F /dev/ttyS3 -a | head -n 1
```

## 自动启动配置

创建 `/etc/init.d/S10uart`:

```bash
#!/bin/sh

start() {
    echo "Configuring UART3..."

    # 修改权限
    chmod 666 /dev/ttyS3

    # 配置波特率 (使用 stty)
    stty -F /dev/ttyS3 115200 cs8 -cstopb -parenb raw -echo

    echo "UART3 ready: 115200 8N1"
}

stop() {
    echo "Stopping UART3 services..."
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

添加执行权限:
```bash
chmod +x /etc/init.d/S10uart
```

## 性能参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 最大波特率 | 4 Mbps | 理论值 |
| 常用波特率 | 115200 | 稳定可靠 |
| FIFO 大小 | 128 字节 | 硬件缓冲 |
| 中断号 | 135 | UART3 IRQ |
| 基地址 | 0x42500C00 | MMIO 地址 |
| DMA 支持 | 否 | 当前未启用 |

## 相关文件

- 设备树配置: [device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts](device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts)
- SoC 定义: [bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi)
- 驱动源码: `bsp/drivers/uart/` (uart-ng 驱动)

## 参考文档

- [CLAUDE.md](../CLAUDE.md) - 项目开发指南
- [UVC_GADGET_CONFIG.md](UVC_GADGET_CONFIG.md) - USB 虚拟串口
- Linux Serial HOWTO: https://tldp.org/HOWTO/Serial-HOWTO.html
- Termios 编程: https://man7.org/linux/man-pages/man3/termios.3.html

## 快速参考

### 常用命令速查

```bash
# 检查设备
ls -l /dev/ttyS3

# 修改权限
chmod 666 /dev/ttyS3

# 查看当前配置
stty -F /dev/ttyS3 -a

# 设置波特率为 115200, 8N1
stty -F /dev/ttyS3 115200 cs8 -cstopb -parenb raw -echo

# 只查看波特率
stty -F /dev/ttyS3 speed

# 发送数据
echo "Hello" > /dev/ttyS3

# 接收数据
cat /dev/ttyS3

# 后台接收
cat /dev/ttyS3 &

# 回环测试(短接 TX/RX)
cat /dev/ttyS3 & echo "Test" > /dev/ttyS3

# 查看十六进制数据
cat /dev/ttyS3 | hexdump -C

# 查看内核日志
dmesg | grep uart3
```

### 引脚连接图

```
V821 开发板                外部设备
┌─────────────┐          ┌─────────────┐
│             │          │             │
│  PL2 (TX) ──┼─────────►│ RX          │
│             │          │             │
│  PL3 (RX) ◄─┼──────────┤ TX          │
│             │          │             │
│  GND ───────┼──────────┤ GND         │
│             │          │             │
└─────────────┘          └─────────────┘

注意: TX 连接 RX, RX 连接 TX
```

### 波特率速查表

| 应用场景 | 推荐波特率 | 说明 |
|----------|-----------|------|
| GPS 模块 | 9600 | 标准 NMEA |
| 蓝牙 AT | 38400 | HC-05/HC-06 |
| Arduino | 9600/115200 | 根据代码 |
| 调试输出 | 115200 | 通用 |
| 高速传输 | 921600 | 短距离 |
| 工业总线 | 9600/19200 | Modbus 等 |

---

**编写时间**: 2025-01-16
**适用版本**: Tina Linux V821
**作者**: Claude Code
