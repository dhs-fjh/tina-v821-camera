# V821 PWM 使用指南

## 概述

PWM (Pulse Width Modulation，脉宽调制) 是一种通过改变脉冲宽度来控制电路输出的技术。V821 提供了一个支持 **12 个通道** 的 PWM 控制器。

## 硬件配置

### PWM9 配置示例

您已经启用的 PWM9 配置如下：

**设备树配置**: [board.dts:438](device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts#L438)

```dts
&pwm0_9 {
    pinctrl-names = "active", "sleep";
    pinctrl-0 = <&pwm9_pins_active>;   // 激活状态引脚配置
    pinctrl-1 = <&pwm9_pins_sleep>;    // 休眠状态引脚配置
    status = "okay";                    // 启用 PWM9
};
```

**引脚定义**: [board.dts:229](device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts#L229)

```dts
pwm9_pins_active: pwm9@0 {
    pins = "PD19";           // PWM9 输出引脚
    function = "pwm0_9";     // 复用功能
};

pwm9_pins_sleep: pwm9@1 {
    pins = "PD19";
    function = "gpio_in";    // 休眠时切换为 GPIO 输入
    bias-pull-down;          // 下拉
};
```

### PWM 控制器硬件信息

位置: [sun300iw1p1.dtsi:657](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi#L657)

```dts
pwm0: pwm@42000c00 {
    compatible = "allwinner,sunxi-pwm-v205";
    reg = <0x0 0x42000c00 0x0 0x400>;          // PWM 控制器基地址
    clocks = <&ccu CLK_PWM>, <&aon_ccu CLK_DCXO>;
    clock-names = "bus", "clk_hosc";
    resets = <&ccu RST_BUS_PWM>;
    interrupts-extended = <&plic0 19 IRQ_TYPE_LEVEL_HIGH>;
    pwm-number = <12>;                          // 支持 12 个通道
    pwm-base = <0x0>;
    sunxi-pwms = <&pwm0_0>, <&pwm0_1>, ..., <&pwm0_11>;
};
```

**PWM9 子节点**: [sun300iw1p1.dtsi:745](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi#L745)

```dts
pwm0_9: pwm0@42000c19 {
    compatible = "allwinner,sunxi-pwm9";
    reg = <0x0 0x42000c19 0x0 0x4>;            // PWM9 寄存器偏移
    reg_base = <0x42000c00>;                   // 基地址
    status = "disabled";                        // 默认禁用 (您已在 board.dts 中启用)
};
```

### 引脚映射总结

| PWM 通道 | 引脚 | 复用功能 | 寄存器地址 |
|---------|------|---------|-----------|
| PWM9 | **PD19** | pwm0_9 | 0x42000c19 |

## 如何使用 PWM

### 方法 1: sysfs 接口 (推荐用于测试)

启用 PWM 后，系统会在 `/sys/class/pwm/` 下创建对应的设备节点。

#### 1. 查找 PWM 设备

```bash
# 列出所有 PWM 控制器
ls /sys/class/pwm/
# 输出示例: pwmchip0

# 查看该控制器支持的 PWM 通道数
cat /sys/class/pwm/pwmchip0/npwm
# 输出: 12 (表示支持 12 个通道)
```

#### 2. 导出 PWM9 通道

```bash
# 导出 PWM9 通道 (通道编号从 0 开始，PWM9 = 通道 9)
echo 9 > /sys/class/pwm/pwmchip0/export

# 检查是否导出成功
ls /sys/class/pwm/pwmchip0/
# 应该能看到 pwm9 目录
```

#### 3. 配置 PWM 参数

```bash
cd /sys/class/pwm/pwmchip0/pwm9

# 设置周期 (单位: 纳秒)
# 例如: 1000000 ns = 1 ms → 频率 1 kHz
echo 1000000 > period

# 设置占空比 (单位: 纳秒，必须 <= period)
# 例如: 500000 ns = 50% 占空比
echo 500000 > duty_cycle

# 设置极性 (可选)
# "normal" - 高电平有效
# "inversed" - 低电平有效
echo "normal" > polarity

# 启用 PWM 输出
echo 1 > enable
```

#### 4. 修改参数示例

```bash
# 改变占空比 (调整亮度/速度)
echo 250000 > duty_cycle   # 25% 占空比
echo 750000 > duty_cycle   # 75% 占空比

# 改变频率
echo 500000 > period       # 2 kHz
echo 100000 > duty_cycle   # 20% 占空比

# 停止 PWM 输出
echo 0 > enable
```

#### 5. 释放 PWM 通道

```bash
# 使用完毕后释放
echo 9 > /sys/class/pwm/pwmchip0/unexport
```

### 方法 2: Shell 脚本控制

创建一个 PWM 控制脚本：

```bash
#!/bin/sh
# pwm_control.sh - PWM 控制脚本

PWM_CHIP="/sys/class/pwm/pwmchip0"
PWM_CHANNEL=9
PWM_DIR="${PWM_CHIP}/pwm${PWM_CHANNEL}"

# 导出 PWM
if [ ! -d "$PWM_DIR" ]; then
    echo $PWM_CHANNEL > ${PWM_CHIP}/export
    sleep 0.1
fi

# 配置 PWM
PERIOD=$1       # 第一个参数: 周期 (ns)
DUTY=$2         # 第二个参数: 占空比 (ns)

if [ -z "$PERIOD" ] || [ -z "$DUTY" ]; then
    echo "用法: $0 <周期ns> <占空比ns>"
    echo "示例: $0 1000000 500000  # 1kHz, 50%占空比"
    exit 1
fi

# 设置参数
echo 0 > ${PWM_DIR}/enable           # 先禁用
echo $PERIOD > ${PWM_DIR}/period
echo $DUTY > ${PWM_DIR}/duty_cycle
echo "normal" > ${PWM_DIR}/polarity
echo 1 > ${PWM_DIR}/enable           # 启用

echo "PWM9 已启动: 周期=${PERIOD}ns, 占空比=${DUTY}ns"
```

**使用方法**:

```bash
# 1kHz, 50% 占空比
./pwm_control.sh 1000000 500000

# 10kHz, 30% 占空比
./pwm_control.sh 100000 30000
```

### 方法 3: C 语言程序

创建 `pwm_demo.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

#define PWM_CHIP_PATH "/sys/class/pwm/pwmchip0"
#define PWM_CHANNEL 9

int pwm_export(int channel) {
    int fd;
    char buf[64];

    snprintf(buf, sizeof(buf), "%s/pwm%d", PWM_CHIP_PATH, channel);
    if (access(buf, F_OK) == 0) {
        printf("PWM%d 已经导出\n", channel);
        return 0;
    }

    fd = open(PWM_CHIP_PATH "/export", O_WRONLY);
    if (fd < 0) {
        perror("无法打开 export");
        return -1;
    }

    snprintf(buf, sizeof(buf), "%d", channel);
    write(fd, buf, strlen(buf));
    close(fd);

    usleep(100000);  // 等待 100ms
    return 0;
}

int pwm_set_period(int channel, unsigned long period_ns) {
    int fd;
    char path[128], buf[64];

    snprintf(path, sizeof(path), "%s/pwm%d/period", PWM_CHIP_PATH, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("无法设置 period");
        return -1;
    }

    snprintf(buf, sizeof(buf), "%lu", period_ns);
    write(fd, buf, strlen(buf));
    close(fd);
    return 0;
}

int pwm_set_duty_cycle(int channel, unsigned long duty_ns) {
    int fd;
    char path[128], buf[64];

    snprintf(path, sizeof(path), "%s/pwm%d/duty_cycle", PWM_CHIP_PATH, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("无法设置 duty_cycle");
        return -1;
    }

    snprintf(buf, sizeof(buf), "%lu", duty_ns);
    write(fd, buf, strlen(buf));
    close(fd);
    return 0;
}

int pwm_set_polarity(int channel, const char *polarity) {
    int fd;
    char path[128];

    snprintf(path, sizeof(path), "%s/pwm%d/polarity", PWM_CHIP_PATH, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("无法设置 polarity");
        return -1;
    }

    write(fd, polarity, strlen(polarity));
    close(fd);
    return 0;
}

int pwm_enable(int channel, int enable) {
    int fd;
    char path[128];

    snprintf(path, sizeof(path), "%s/pwm%d/enable", PWM_CHIP_PATH, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("无法设置 enable");
        return -1;
    }

    write(fd, enable ? "1" : "0", 1);
    close(fd);
    return 0;
}

int main(int argc, char *argv[]) {
    unsigned long period_ns, duty_ns;

    if (argc != 3) {
        printf("用法: %s <周期ns> <占空比ns>\n", argv[0]);
        printf("示例: %s 1000000 500000  # 1kHz, 50%%占空比\n", argv[0]);
        return 1;
    }

    period_ns = strtoul(argv[1], NULL, 10);
    duty_ns = strtoul(argv[2], NULL, 10);

    if (duty_ns > period_ns) {
        printf("错误: 占空比不能大于周期\n");
        return 1;
    }

    printf("配置 PWM%d...\n", PWM_CHANNEL);

    // 1. 导出 PWM
    if (pwm_export(PWM_CHANNEL) < 0) {
        return 1;
    }

    // 2. 禁用 PWM (修改参数前)
    pwm_enable(PWM_CHANNEL, 0);

    // 3. 设置参数
    if (pwm_set_period(PWM_CHANNEL, period_ns) < 0) {
        return 1;
    }

    if (pwm_set_duty_cycle(PWM_CHANNEL, duty_ns) < 0) {
        return 1;
    }

    if (pwm_set_polarity(PWM_CHANNEL, "normal") < 0) {
        return 1;
    }

    // 4. 启用 PWM
    if (pwm_enable(PWM_CHANNEL, 1) < 0) {
        return 1;
    }

    printf("PWM%d 已启动:\n", PWM_CHANNEL);
    printf("  周期: %lu ns (%.2f Hz)\n", period_ns, 1000000000.0 / period_ns);
    printf("  占空比: %lu ns (%.1f%%)\n", duty_ns, 100.0 * duty_ns / period_ns);
    printf("  输出引脚: PD19\n");

    return 0;
}
```

**编译和使用**:

```bash
# 编译
riscv32-linux-gcc -o pwm_demo pwm_demo.c

# 运行 (1kHz, 50% 占空比)
./pwm_demo 1000000 500000

# 运行 (50Hz, 10% 占空比 - 适合舵机)
./pwm_demo 20000000 2000000
```

## 常见应用场景

### 1. LED 调光

```bash
# 导出 PWM9
echo 9 > /sys/class/pwm/pwmchip0/export
cd /sys/class/pwm/pwmchip0/pwm9

# 设置 1kHz 频率
echo 1000000 > period

# 逐渐增加亮度
for i in 0 100000 200000 500000 800000 1000000; do
    echo $i > duty_cycle
    echo 1 > enable
    sleep 1
done

# 关闭
echo 0 > enable
```

### 2. 蜂鸣器控制

```bash
# 播放 1kHz 音调
echo 1000000 > period
echo 500000 > duty_cycle   # 50% 占空比
echo 1 > enable
sleep 1
echo 0 > enable

# 播放 2kHz 音调
echo 500000 > period
echo 250000 > duty_cycle
echo 1 > enable
sleep 1
echo 0 > enable
```

### 3. 舵机控制

舵机通常需要 **50Hz (20ms 周期)** 的 PWM 信号:
- 1.0 ms (5%) → 0°
- 1.5 ms (7.5%) → 90°
- 2.0 ms (10%) → 180°

```bash
cd /sys/class/pwm/pwmchip0/pwm9

# 设置 50Hz 频率
echo 20000000 > period   # 20ms

# 0° 位置
echo 1000000 > duty_cycle   # 1ms
echo 1 > enable
sleep 1

# 90° 位置
echo 1500000 > duty_cycle   # 1.5ms
sleep 1

# 180° 位置
echo 2000000 > duty_cycle   # 2ms
sleep 1

# 停止
echo 0 > enable
```

### 4. 电机调速 (直流电机)

```bash
cd /sys/class/pwm/pwmchip0/pwm9

# 设置 10kHz 频率 (电机常用)
echo 100000 > period

# 低速 (20%)
echo 20000 > duty_cycle
echo 1 > enable
sleep 2

# 中速 (50%)
echo 50000 > duty_cycle
sleep 2

# 高速 (80%)
echo 80000 > duty_cycle
sleep 2

# 停止
echo 0 > enable
```

## 参数计算

### 频率 → 周期转换

```
周期 (ns) = 1,000,000,000 / 频率 (Hz)
```

**示例**:
- 1 Hz → 1,000,000,000 ns (1 秒)
- 50 Hz → 20,000,000 ns (20 ms) - 舵机
- 1 kHz → 1,000,000 ns (1 ms)
- 10 kHz → 100,000 ns (0.1 ms)
- 100 kHz → 10,000 ns (0.01 ms)

### 占空比计算

```
占空比 (ns) = 周期 (ns) × 占空比百分比
```

**示例 (1kHz PWM)**:
- 10% → 1,000,000 × 0.1 = 100,000 ns
- 50% → 1,000,000 × 0.5 = 500,000 ns
- 75% → 1,000,000 × 0.75 = 750,000 ns

## 调试命令

### 查看 PWM 状态

```bash
# 查看 PWM9 当前配置
cat /sys/class/pwm/pwmchip0/pwm9/period
cat /sys/class/pwm/pwmchip0/pwm9/duty_cycle
cat /sys/class/pwm/pwmchip0/pwm9/polarity
cat /sys/class/pwm/pwmchip0/pwm9/enable

# 查看引脚复用状态
cat /sys/kernel/debug/pinctrl/42000000.pinctrl/pinmux-pins | grep PD19
```

### 检查设备树加载

```bash
# 检查 PWM9 是否启用
cat /proc/device-tree/pwm0_9/status
# 输出: okay

# 检查引脚配置
ls /proc/device-tree/soc/pinctrl@42000000/
```

### 内核日志

```bash
# 查看 PWM 驱动加载日志
dmesg | grep -i pwm

# 示例输出:
# [    2.345678] sunxi-pwm 42000c00.pwm: sunxi pwm_v205 probe success
# [   15.123456] pwm-9 (pwm9): requested
# [   15.234567] pwm-9 (pwm9): period: 1000000 ns, duty: 500000 ns
```

## 常见问题

### 1. 找不到 /sys/class/pwm/pwmchip0

**原因**: PWM 驱动未加载或 PWM 未在设备树中启用

**解决方法**:
```bash
# 检查设备树状态
cat /proc/device-tree/pwm0_9/status
# 应该输出: okay

# 检查驱动是否加载
lsmod | grep pwm

# 手动加载驱动 (如果需要)
modprobe pwm-sunxi
```

### 2. echo 9 > export 报错: "Device or resource busy"

**原因**: PWM9 已经被导出

**解决方法**:
```bash
# 检查是否已存在
ls /sys/class/pwm/pwmchip0/pwm9

# 如果已存在,直接使用即可
cd /sys/class/pwm/pwmchip0/pwm9
```

### 3. 修改 duty_cycle 报错: "Invalid argument"

**原因**: duty_cycle 大于 period

**解决方法**:
```bash
# 确保 duty_cycle <= period
# 正确顺序: 先设置 period, 再设置 duty_cycle

echo 0 > enable            # 先禁用
echo 1000000 > period      # 设置周期
echo 500000 > duty_cycle   # 设置占空比 (必须 <= period)
echo 1 > enable            # 启用
```

### 4. echo 1 > enable 报错: "can't parse pwm device" / "No such device"

**错误信息**:
```
[  569.204611] sunxi:pwm-42000c00.pwm:[ERR]: can't parse pwm device
sh: write error: No such device
```

**原因**: Allwinner PWM 驱动设计问题 - 驱动期望 PWM 子设备绑定驱动，但实际上 PWM 子设备不需要独立驱动

**诊断步骤**:
```bash
# 1. 确认设备树节点存在且启用
ls /sys/firmware/devicetree/base/soc@2002000/pwm0@42000c19/
cat /sys/firmware/devicetree/base/soc@2002000/pwm0@42000c19/status
# 应该输出: okay

# 2. 确认 platform_device 已注册
ls /sys/devices/platform/soc@2002000/42000c19.pwm0/
# 如果存在,设备已注册

# 3. 检查是否绑定驱动
ls -la /sys/devices/platform/soc@2002000/42000c19.pwm0/ | grep driver
# 如果没有 driver 符号链接,说明未绑定驱动 (这是问题所在)

# 4. 检查驱动加载情况
ls /sys/bus/platform/drivers/sunxi_pwm/
# 应该只看到 42000c00.pwm (主控制器),没有子设备
```

**解决方案 1: 修改驱动源码** (推荐,需要重新编译内核)

编辑 `bsp/drivers/pwm/pwm-sunxi.c`,找到 [pwm-sunxi.c:1002-1006](bsp/drivers/pwm/pwm-sunxi.c#L1002)：

```c
pwm_pdevice = of_find_device_by_node(sub_np);
if (!pwm_pdevice) {
    sunxi_err(chip->pwm_chip.dev, "can't parse pwm device\n");
    return -ENODEV;
}
```

修改为允许 NULL device:

```c
pwm_pdevice = of_find_device_by_node(sub_np);
if (!pwm_pdevice) {
    sunxi_warn(chip->pwm_chip.dev, "pwm sub-device not found, using parent device\n");
    pwm_pdevice = to_platform_device(chip->pwm_chip.dev);
}
```

然后重新编译:
```bash
cd /home/f/tina/tina-v821-camera
./build.sh kernel
./build.sh pack
# 烧录新固件
```

**解决方案 2: 使用其他 PWM 通道** (临时方案)

尝试使用 PWM0-PWM8 或 PWM10-PWM11 通道,某些通道可能不受此问题影响:

```bash
# 尝试 PWM0
echo 0 > /sys/class/pwm/pwmchip0/export
cd /sys/class/pwm/pwmchip0/pwm0
echo 1000000 > period
echo 500000 > duty_cycle
echo 1 > enable
```

注意：不同的 PWM 通道映射到不同的引脚,需要查看设备树中的 pinctrl 配置。

**解决方案 3: 手动创建 PWM 驱动绑定** (实验性)

尝试手动将设备绑定到驱动 (可能不工作):

```bash
# 尝试手动绑定
echo "42000c19.pwm0" > /sys/bus/platform/drivers/sunxi_pwm/bind

# 如果成功,检查
ls -la /sys/devices/platform/soc@2002000/42000c19.pwm0/ | grep driver
```

**解决方案 4: 修改设备树,移除子设备节点** (不推荐)

如果只需要一个 PWM 通道,可以简化设备树,直接使用主控制器的某个通道,而不依赖子设备。这需要修改 DTSI 和驱动代码,较为复杂。

### 5. PWM 输出没有信号

**检查步骤**:

```bash
# 1. 确认已启用
cat /sys/class/pwm/pwmchip0/pwm9/enable
# 应该输出: 1

# 2. 检查引脚复用
cat /sys/kernel/debug/pinctrl/42000000.pinctrl/pinmux-pins | grep "pin 115"
# PD19 = 32×3 + 19 = 115
# 应该显示: function pwm0_9

# 3. 检查硬件连接
# 使用万用表或示波器测量 PD19 引脚电压

# 4. 尝试调整参数
echo 0 > enable
echo 1000000 > period       # 使用较低频率测试
echo 500000 > duty_cycle
echo 1 > enable
```

## 硬件连接示例

### LED 连接

```
V821 (3.3V)
   │
   PD19 ──┬── 330Ω 电阻 ──┬── LED (+)
          │                │
          │                LED (-)
          │                │
         GND ─────────────┴── GND
```

### 蜂鸣器连接 (有源蜂鸣器)

```
V821 (3.3V)              NPN 三极管 (如 2N2222)
   │
   PD19 ──── 1kΩ ──── B (基极)
                       │
                       C (集电极) ──── 蜂鸣器(+) ──── VCC (5V)
                       │
                       E (发射极) ──── GND

蜂鸣器(-) ──── GND
```

### 舵机连接

```
舵机 (3线)
   ├── 红线 (VCC) ──── 5V 电源
   ├── 棕线 (GND) ──── GND
   └── 橙线 (信号) ──── PD19
```

## 性能指标

### PWM 控制器规格

| 参数 | 值 |
|------|---|
| 通道数量 | 12 |
| 最大频率 | ~24 MHz (取决于时钟源) |
| 最小频率 | ~0.023 Hz (42.9 秒周期) |
| 分辨率 | 32 位 |
| 时钟源 | DCXO (24 MHz) |

### 常用频率范围

| 应用 | 推荐频率 | 周期 (ns) |
|-----|---------|----------|
| 舵机 | 50 Hz | 20,000,000 |
| 直流电机 | 1-25 kHz | 1,000,000 - 40,000 |
| LED 调光 | 1-10 kHz | 1,000,000 - 100,000 |
| 蜂鸣器 | 1-5 kHz | 1,000,000 - 200,000 |

## 完整测试脚本

创建 `pwm_test.sh` 用于快速测试:

```bash
#!/bin/sh
# PWM9 功能测试脚本

PWM_CHIP="/sys/class/pwm/pwmchip0"
PWM_CHANNEL=9
PWM_PATH="${PWM_CHIP}/pwm${PWM_CHANNEL}"

echo "========== PWM9 测试脚本 =========="
echo "引脚: PD19"
echo ""

# 导出 PWM
if [ ! -d "$PWM_PATH" ]; then
    echo "导出 PWM${PWM_CHANNEL}..."
    echo $PWM_CHANNEL > ${PWM_CHIP}/export
    sleep 0.2
fi

cd $PWM_PATH

# 禁用 PWM
echo 0 > enable

# 测试 1: 1kHz, 50% 占空比
echo "测试 1: 1kHz, 50% 占空比"
echo 1000000 > period
echo 500000 > duty_cycle
echo "normal" > polarity
echo 1 > enable
sleep 2

# 测试 2: 1kHz, 25% 占空比
echo "测试 2: 1kHz, 25% 占空比"
echo 250000 > duty_cycle
sleep 2

# 测试 3: 1kHz, 75% 占空比
echo "测试 3: 1kHz, 75% 占空比"
echo 750000 > duty_cycle
sleep 2

# 测试 4: 10kHz, 50% 占空比
echo "测试 4: 10kHz, 50% 占空比"
echo 100000 > period
echo 50000 > duty_cycle
sleep 2

# 停止
echo 0 > enable
echo "测试完成!"

# 显示当前配置
echo ""
echo "当前配置:"
echo "  周期: $(cat period) ns"
echo "  占空比: $(cat duty_cycle) ns"
echo "  极性: $(cat polarity)"
echo "  状态: $(cat enable)"
```

**运行测试**:

```bash
chmod +x pwm_test.sh
./pwm_test.sh
```

## 相关文档

- [GPIO_PIO_RTCPIO_EXPLANATION.md](GPIO_PIO_RTCPIO_EXPLANATION.md) - GPIO 控制器详解
- [DEVICE_TREE_PARAMETER_GUIDE.md](DEVICE_TREE_PARAMETER_GUIDE.md) - 设备树参数指南
- [CLAUDE.md](../CLAUDE.md) - 项目开发指南
- 设备树: [board.dts](device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts)
- SoC 定义: [sun300iw1p1.dtsi](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi)
- PWM 驱动: [pwm-sunxi.c](bsp/drivers/pwm/pwm-sunxi.c)

## 快速参考

### sysfs 路径速查

```bash
# PWM 控制器
/sys/class/pwm/pwmchip0/

# PWM9 通道
/sys/class/pwm/pwmchip0/pwm9/
  ├── period         # 周期 (ns)
  ├── duty_cycle     # 占空比 (ns)
  ├── polarity       # 极性 (normal/inversed)
  └── enable         # 使能 (0/1)
```

### 常用命令速查

```bash
# 导出 PWM9
echo 9 > /sys/class/pwm/pwmchip0/export

# 配置 PWM (1kHz, 50%)
cd /sys/class/pwm/pwmchip0/pwm9
echo 1000000 > period
echo 500000 > duty_cycle
echo 1 > enable

# 停止 PWM
echo 0 > enable

# 释放 PWM
echo 9 > /sys/class/pwm/pwmchip0/unexport
```

### 频率换算速查表

| 频率 | 周期 (ns) | 用途 |
|------|----------|------|
| 50 Hz | 20,000,000 | 舵机 |
| 1 kHz | 1,000,000 | LED 调光 |
| 10 kHz | 100,000 | 电机控制 |
| 100 kHz | 10,000 | 高频应用 |

---

**编写时间**: 2025-01-16
**适用版本**: Tina Linux V821
**作者**: Claude Code
