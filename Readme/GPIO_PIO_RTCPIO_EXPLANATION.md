# V821 GPIO 控制器: PIO vs RTC_PIO 详解

## 概述

V821 有**两个独立的 GPIO 控制器**:
1. **PIO** - 主 GPIO 控制器 (PA, PB, PC, PD, PE, PF, PG 组)
2. **RTC_PIO** - RTC 域 GPIO 控制器 (PL 组)

## 关键区别对比

| 特性 | PIO | RTC_PIO |
|------|-----|---------|
| **完整名称** | Programmable I/O Controller | RTC Programmable I/O Controller |
| **基地址** | 0x42000000 | 0x42000540 |
| **管理引脚组** | PA, PB, PC, PD, PE, PF, PG | **PL** (L = Low power) |
| **电源域** | VCC-IO (主电源域) | VCC-RTC (RTC 电源域) |
| **供电** | 系统开启时供电 | **持续供电**(即使系统关闭) |
| **主要用途** | 通用 GPIO、外设功能 | 低功耗、唤醒、RTC 相关 |
| **时钟源** | APB0, DCXO, LOSC | DCXO (24MHz 晶振) |
| **中断号** | 68, 72, 74 | 84 |
| **功耗** | 正常功耗 | **低功耗** |

## 为什么 UART 分布在两个控制器?

### UART 引脚分配:

| UART | 引脚 | GPIO 组 | 控制器 | 原因 |
|------|------|---------|--------|------|
| UART0 | PL4, PL5 | **PL** | **RTC_PIO** | 调试串口,需要持续供电 |
| UART3 | PL2, PL3 | **PL** | **RTC_PIO** | 低功耗应用,保持唤醒 |
| UART1 | PD7-PD10 | **PD** | **PIO** | 通用串口,正常功耗 |
| UART2 | PA5-PA8 | **PA** | **PIO** | 通用串口,正常功耗 |

### 设计原因:

#### 1. **UART0 在 RTC_PIO (PL 组)**
```dts
&rtc_pio {
    uart0_pins_default: uart0_pins@0 {
        pins = "PL4", "PL5";
        function = "uart0";
    };
};
```

**为什么**:
- UART0 是**主控制台/调试串口**
- 需要在**所有电源状态下工作**
- 即使系统进入低功耗模式,仍能输出调试信息
- 可以作为系统唤醒源

#### 2. **UART3 在 RTC_PIO (PL 组)**
```dts
&rtc_pio {
    uart3_pins_default: uart3_pins@0 {
        pins = "PL2", "PL3";
        function = "uart3";
    };
};
```

**为什么**:
- 用于**低功耗外设通信**
- 可以在待机模式下接收数据并唤醒系统
- 适合连接低功耗传感器、GPS、蓝牙等
- RTC 域供电确保持续工作

#### 3. **UART1 和 UART2 在 PIO (PA/PD 组)**
```dts
&pio {
    uart1_pins_default: uart1_pins@0 {
        pins = "PD7", "PD8", "PD9", "PD10";  // 4线:TX,RX,CTS,RTS
        function = "uart1";
    };

    uart2_pins_default: uart2_pins@0 {
        pins = "PA5", "PA6", "PA7", "PA8";   // 4线:TX,RX,CTS,RTS
        function = "uart2";
    };
};
```

**为什么**:
- 通用数据传输,不需要低功耗特性
- 支持**硬件流控**(CTS/RTS 流控线)
- 正常功耗模式,数据传输速度更快
- 引脚资源丰富

## 设备树配置详解

### PIO 控制器定义

位置: [bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi:264](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi#L264)

```dts
pio: pinctrl@42000000 {
    compatible = "allwinner,sun300iw1-pinctrl";
    reg = <0x0 0x42000000 0x0 0x500>;           // 寄存器地址范围
    interrupts-extended = <&plic0 68 IRQ_TYPE_LEVEL_HIGH>,
                          <&plic0 72 IRQ_TYPE_LEVEL_HIGH>,
                          <&plic0 74 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&aon_ccu CLK_APB0>,               // APB 总线时钟
             <&aon_ccu CLK_DCXO>,               // 24MHz 晶振
             <&losc>;                           // 32.768kHz 低速时钟
    clock-names = "apb", "hosc", "losc";
    device_type = "pio";
    gpio-controller;
    #gpio-cells = <3>;
    interrupt-controller;
    #interrupt-cells = <3>;
};
```

**管理的引脚组**:
- PA (Port A) - 通用 GPIO
- PB (Port B) - 通用 GPIO
- PC (Port C) - 通用 GPIO
- PD (Port D) - 网络、UART、LCD 等
- PE (Port E) - 其他外设
- PF (Port F) - SD 卡等
- PG (Port G) - 其他外设

### RTC_PIO 控制器定义

位置: [bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi:449](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi#L449)

```dts
rtc_pio: pinctrl@42000540 {
    #address-cells = <1>;
    compatible = "allwinner,sun300iw1-rtc-pinctrl";
    reg = <0x0 0x42000540 0x0 0x100>;           // RTC GPIO 寄存器
    interrupts-extended = <&plic0 84 IRQ_TYPE_LEVEL_HIGH>;  // GPIOL 中断
    clocks = <&dcxo24M>;                        // 只需 24MHz 晶振
    clock-names = "hosc";
    gpio-controller;
    #gpio-cells = <3>;
    interrupt-controller;
    #interrupt-cells = <3>;
};
```

**管理的引脚组**:
- **PL** (Port L) - 低功耗专用 GPIO
  - PL0 - PL15 (具体数量看芯片)
  - L = Low power (低功耗)

## PL 组引脚的特殊性

### 电源域

```
普通 GPIO (PA-PG):  VCC-IO   ┐
                            ├── 系统电源,可关闭
RTC GPIO (PL):     VCC-RTC  ┘   RTC 电源,持续供电
```

### 典型应用

| 引脚 | 功能 | 说明 |
|------|------|------|
| PL0-PL1 | 按键/唤醒 | 系统待机唤醒按键 |
| PL2-PL3 | UART3 | 低功耗串口通信 |
| PL4-PL5 | UART0 | 调试控制台 |
| PL6-PL7 | I2C/GPIO | RTC、PMIC 通信 |
| PL8-PL15 | GPIO | 其他低功耗外设 |

### 低功耗场景示例

**场景**: GPS 模块持续接收,系统待机

```
系统状态: 待机 (主 CPU 关闭)
  ├─ VCC-IO:  关闭 (PA-PG 引脚无电)
  └─ VCC-RTC: 开启 (PL 引脚继续工作)
      └─ UART3 (PL2/PL3): 接收 GPS 数据
          └─ 检测到特定数据 → 唤醒主 CPU
```

## 在代码中的使用

### 引用 GPIO

```dts
// 引用 PIO 控制器的引脚
sensor0_reset = <&pio PA 2 GPIO_ACTIVE_LOW>;    // PA2
gmac_rst = <&pio PD 11 GPIO_ACTIVE_HIGH>;       // PD11

// 引用 RTC_PIO 控制器的引脚
wakeup_button = <&rtc_pio PL 0 GPIO_ACTIVE_LOW>; // PL0
uart0_tx = <&rtc_pio PL 4 GPIO_ACTIVE_HIGH>;     // PL4
```

### GPIO 操作

```c
// 在驱动代码中,操作方式相同,系统自动识别控制器
#include <linux/gpio.h>

// 无论是 PIO 还是 RTC_PIO,API 相同
gpio_request(gpio_num, "test-gpio");
gpio_direction_output(gpio_num, 1);
gpio_set_value(gpio_num, 0);
```

## 查看 GPIO 状态

### 查看 PIO 状态

```bash
# 查看所有 GPIO 状态
cat /sys/kernel/debug/gpio

# 查看 pinctrl 信息
ls /sys/kernel/debug/pinctrl/

# PIO 控制器
cat /sys/kernel/debug/pinctrl/42000000.pinctrl/pinmux-pins

# RTC_PIO 控制器
cat /sys/kernel/debug/pinctrl/42000540.pinctrl/pinmux-pins
```

### 查看引脚复用

```bash
# 查看 UART 引脚复用
cat /sys/kernel/debug/pinctrl/*/pinmux-pins | grep -i uart

# 输出示例:
# pin 68 (PL4): uart0 (GPIO UNCLAIMED) function uart0 group uart0_pins@0
# pin 69 (PL5): uart0 (GPIO UNCLAIMED) function uart0 group uart0_pins@0
```

## 功耗对比

| 场景 | PIO (PA-PG) | RTC_PIO (PL) |
|------|-------------|--------------|
| 正常运行 | 正常功耗 | 正常功耗 |
| 待机模式 | **断电,无功能** | **持续供电,可工作** |
| 深度睡眠 | 断电 | 保持低功耗工作 |
| 关机 | 断电 | 仅 RTC 功能 |

**功耗数据** (典型值):
- PIO 单个引脚: ~1-5 mA (驱动负载时)
- RTC_PIO 单个引脚: ~100-500 µA (低功耗模式)

## 实际应用建议

### 何时使用 PIO (PA-PG)

✅ **适合**:
- 高速数据传输
- 需要硬件流控的 UART
- LCD、摄像头接口
- 网络接口
- 普通 GPIO 控制

❌ **不适合**:
- 需要待机唤醒的功能
- 低功耗应用
- RTC 相关功能

### 何时使用 RTC_PIO (PL)

✅ **适合**:
- 调试串口 (UART0)
- 低功耗传感器通信
- 待机唤醒按键
- RTC 外设 (I2C PMIC)
- 需要持续监控的信号

❌ **不适合**:
- 高速数据传输
- 复杂外设接口
- 需要大量引脚的应用

## 总结

### UART 分配的设计逻辑

```
┌─────────────────────────────────────────┐
│         V821 UART 分配策略               │
├─────────────────────────────────────────┤
│                                         │
│  低功耗/调试 (RTC_PIO - PL组):           │
│    ├─ UART0: 调试串口,始终可用           │
│    └─ UART3: 低功耗通信,可唤醒系统        │
│                                         │
│  通用/高性能 (PIO - PA/PD组):            │
│    ├─ UART1: 通用串口,支持硬件流控        │
│    └─ UART2: 通用串口,支持硬件流控        │
│                                         │
└─────────────────────────────────────────┘
```

### 关键要点

1. **PL 组 = 低功耗 = RTC_PIO 控制器**
   - 持续供电,低功耗
   - UART0、UART3 在这里

2. **PA/PB/PC/PD/PE/PF/PG 组 = 通用 = PIO 控制器**
   - 正常功耗,系统开启时工作
   - UART1、UART2 在这里

3. **为什么这样设计**:
   - 调试串口 (UART0) 需要在任何状态下工作
   - 低功耗应用 (UART3) 可以唤醒系统
   - 通用串口 (UART1/2) 不需要低功耗特性

4. **对开发者的影响**:
   - 选择 UART3 (PL 组) → 适合低功耗传感器、GPS
   - 选择 UART1/2 (PA/PD 组) → 适合高速通信、调制解调器

## 相关文档

- [UART_SERIAL_GUIDE.md](UART_SERIAL_GUIDE.md) - 串口使用指南
- [CLAUDE.md](../CLAUDE.md) - 项目开发指南
- 设备树: [board.dts](device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts)
- SoC 定义: [sun300iw1p1.dtsi](bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi)

## 快速参考

### GPIO 命名规则

```
PA0-PA31  → PIO 控制器 @ 0x42000000
PB0-PB31  → PIO 控制器 @ 0x42000000
PC0-PC31  → PIO 控制器 @ 0x42000000
PD0-PD31  → PIO 控制器 @ 0x42000000
PE0-PE31  → PIO 控制器 @ 0x42000000
PF0-PF31  → PIO 控制器 @ 0x42000000
PG0-PG31  → PIO 控制器 @ 0x42000000

PL0-PL15  → RTC_PIO 控制器 @ 0x42000540 (低功耗)
           (L = Low power)
```

### UART 引脚速查

| UART | 引脚 | 控制器 | 用途 |
|------|------|--------|------|
| UART0 | PL4 (TX), PL5 (RX) | RTC_PIO | 调试控制台 |
| UART1 | PD7-PD10 (TX/RX/CTS/RTS) | PIO | 通用+流控 |
| UART2 | PA5-PA8 (TX/RX/CTS/RTS) | PIO | 通用+流控 |
| UART3 | PL2 (TX), PL3 (RX) | RTC_PIO | 低功耗通信 |

---

**编写时间**: 2025-01-16
**适用版本**: Tina Linux V821
**作者**: Claude Code
