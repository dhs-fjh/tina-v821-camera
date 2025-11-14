# 设备树参数配置指南

## 如何查看设备树节点可配置的参数

### 方法1：查看驱动源码（最准确）

查找驱动代码中的 `of_property_read_*()` 函数调用，这些函数读取设备树属性：

```bash
# 找到驱动文件
grep -r "of_property_read" bsp/drivers/twi/twi-sunxi.c
```

**常见的 of_property_read 函数：**
- `of_property_read_u32()` - 读取32位整数
- `of_property_read_u64()` - 读取64位整数
- `of_property_read_string()` - 读取字符串
- `of_property_read_bool()` - 读取布尔值（存在即为true）
- `of_property_read_u32_array()` - 读取整数数组

### 方法2：查看设备树绑定文档

Linux内核通常在 `Documentation/devicetree/bindings/` 下有设备树绑定文档。

```bash
find . -path "*/devicetree/bindings/*" -name "*.txt" -o -name "*.yaml"
```

### 方法3：参考其他板子的配置

```bash
# 查找其他板子的相同节点配置
grep -A 10 "&twi0" device/config/chips/v821/configs/*/linux-*/board.dts
```

### 方法4：查看SoC的DTSI基础定义

SoC的 `.dtsi` 文件定义了设备的基础属性：

```bash
cat bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi
```

## 设备树通用属性

这些属性适用于大多数设备节点：

| 属性 | 类型 | 说明 | 必需 |
|------|------|------|------|
| compatible | string array | 设备兼容性字符串 | 是 |
| reg | u32 array | 寄存器地址和长度 | 通常是 |
| status | string | "okay", "disabled", "fail" | 否 |
| interrupts | u32 array | 中断号 | 按需 |
| clocks | phandle array | 时钟引用 | 按需 |
| resets | phandle array | 复位信号 | 按需 |
| power-domains | phandle | 电源域 | 按需 |
| pinctrl-0, pinctrl-1... | phandle | 引脚配置状态 | 按需 |
| pinctrl-names | string array | 引脚配置名称 | 按需 |

## 常见外设参数参考

### TWI/I2C 控制器

**示例：**
```dts
&twi0 {
    clock-frequency = <400000>;           // I2C时钟频率 (Hz)
    pinctrl-0 = <&twi0_pins_default>;     // 默认引脚配置
    pinctrl-1 = <&twi0_pins_sleep>;       // 睡眠引脚配置
    pinctrl-names = "default", "sleep";   // 引脚配置名称
    twi_drv_used = <1>;                   // TWI驱动模式 (0或1)
    twi_pkt_interval = <0>;               // 包间隔
    no_suspend = <0>;                     // 禁止挂起
    status = "okay";                      // 启用设备
};
```

**参数说明：**

| 参数 | 类型 | 说明 | 有效值 |
|------|------|------|--------|
| clock-frequency | u32 | I2C总线频率 | 100000 (100kHz), 400000 (400kHz), 3400000 (3.4MHz) |
| twi_drv_used | u32 | 驱动模式选择 | **0** = legacy mode, **1** = drv-mode |
| twi_pkt_interval | u32 | 数据包之间的间隔延迟 | 0 (无延迟) |
| twi_vol | u32 | 电压配置 | 通常为0 |
| no_suspend | u32 | 系统挂起时保持活跃 | 0 (允许挂起), 1 (禁止挂起) |
| rproc-name | string | 远程处理器名称 | "e907" 等 |

### UART 串口

```dts
&uart0 {
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <&uart0_pins_default>;
    pinctrl-1 = <&uart0_pins_sleep>;
    status = "okay";
};
```

### SPI

```dts
&spi0 {
    clock-frequency = <100000000>;        // SPI时钟频率
    pinctrl-0 = <&spi0_pins_default &spi0_pins_cs>;
    pinctrl-1 = <&spi0_pins_sleep>;
    pinctrl-names = "default", "sleep";
    status = "okay";

    spi_board0 {
        device_type = "spi_board0";
        compatible = "spi-nor";
        spi-max-frequency = <50000000>;   // 最大SPI频率
        reg = <0>;                        // 片选号
        spi-rx-bus-width = <0x1>;        // RX总线宽度
        spi-tx-bus-width = <0x1>;        // TX总线宽度
        status = "okay";
    };
};
```

### GPIO/Pinctrl 引脚配置

```dts
twi0_pins_default: twi0@0 {
    pins = "PA3", "PA4";                  // 引脚名称
    function = "twi0";                    // 引脚功能
    allwinner,drive = <3>;                // 驱动强度 (0-3)
    bias-pull-up;                         // 上拉电阻
    // 或 bias-pull-down;                 // 下拉电阻
    // 或 bias-disable;                   // 禁用偏置
};
```

**驱动强度等级 (allwinner,drive):**
- 0 = 10mA
- 1 = 20mA
- 2 = 30mA
- 3 = 40mA

### Camera Sensor 摄像头传感器

```dts
sensor0: sensor@5812000 {
    device_type = "sensor0";
    sensor0_mname = "gc02m1_mipi";        // 传感器模块名
    sensor0_twi_cci_id = <0>;             // I2C总线号
    sensor0_twi_addr = <0x6e>;            // I2C地址 (8位)
    sensor0_mclk_id = <0>;                // MCLK时钟ID
    sensor0_pos = "rear";                 // 位置: "rear"或"front"
    sensor0_isp_used = <1>;               // 是否使用ISP
    sensor0_fmt = <1>;                    // 格式类型
    sensor0_stby_mode = <0>;              // 待机模式
    sensor0_vflip = <0>;                  // 垂直翻转
    sensor0_hflip = <0>;                  // 水平翻转
    sensor0_iovdd-supply = <>;            // IOVDD电源
    sensor0_iovdd_vol = <1800000>;        // IOVDD电压 (μV)
    sensor0_avdd-supply = <>;             // AVDD电源
    sensor0_avdd_vol = <2800000>;         // AVDD电压 (μV)
    sensor0_dvdd-supply = <>;             // DVDD电源
    sensor0_dvdd_vol = <1500000>;         // DVDD电压 (μV)
    sensor0_power_en = <>;                // 电源使能GPIO
    sensor0_reset = <&pio PA 2 GPIO_ACTIVE_LOW>;  // 复位GPIO
    sensor0_pwdn = <>;                    // 断电GPIO
    status = "okay";
};
```

### CSI 摄像头接口

```dts
csi0: csi@45820000 {
    pinctrl-names = "csi_sm-default", "csi_sm-sleep";
    pinctrl-0 = <&csi_mclk0_pins_a>;
    pinctrl-1 = <&csi_mclk0_pins_b>;
};
```

### PMU 电源管理单元

```dts
&soc_pmu0 {
    status = "okay";

    pmu_soc_ldo1: ldo1 {
        regulator-name = "ldo1";
        regulator-min-microvolt = <2250000>;
        regulator-max-microvolt = <3000000>;
        regulator-enable-ramp-delay = <1000>;
    };
};
```

### SD/MMC 存储控制器

```dts
&sdc0 {
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <&sdc0_pins_default>;
    pinctrl-1 = <&sdc0_pins_sleep>;
    bus-width = <4>;                      // 数据线宽度
    cd-gpios = <&pio PB 4 GPIO_ACTIVE_LOW>;  // 卡检测GPIO
    vmmc-supply = <&reg_3v3>;             // 主电源
    vqmmc-supply = <&reg_1v8>;            // I/O电源
    max-frequency = <50000000>;           // 最大频率
    cap-sd-highspeed;                     // 支持高速SD
    status = "okay";
};
```

## GPIO 引用格式

```dts
sensor0_reset = <&pio PA 2 GPIO_ACTIVE_LOW>;
//              ^^^^^^ ^^ ^ ^^^^^^^^^^^^^^^^
//                |    |  |        |
//                |    |  |        +-- 有效电平 (LOW/HIGH)
//                |    |  +----------- 引脚号
//                |    +-------------- 端口 (PA, PB, PC...)
//                +------------------- GPIO控制器引用
```

**有效电平标志：**
- `GPIO_ACTIVE_HIGH` (1) - 高电平有效
- `GPIO_ACTIVE_LOW` (0) - 低电平有效

## 常见错误

### ❌ 错误1：参数值超出范围
```dts
twi_drv_used = <2>;  // 错误！只能是0或1
```

### ❌ 错误2：缺少必需的pinctrl
```dts
&twi0 {
    status = "okay";
    // 缺少 pinctrl-0 和 pinctrl-names
};
```

### ❌ 错误3：引用不存在的phandle
```dts
sensor0_avdd-supply = <&nonexistent_ldo>;  // 引用的LDO不存在
```

### ❌ 错误4：GPIO极性错误
```dts
sensor0_reset = <&pio PA 2 GPIO_ACTIVE_HIGH>;
// 如果硬件是低电平复位，这会导致传感器一直处于复位状态
```

## 调试技巧

### 1. 检查设备树编译输出
```bash
# 编译后的设备树在这里
ls out/v821/avaota_f1/openwrt/staging_dir/target/boot/*.dtb
```

### 2. 反编译设备树查看实际内容
```bash
dtc -I dtb -O dts out/.../sunxi.dtb -o /tmp/check.dts
```

### 3. 运行时查看设备树
```bash
# 在设备上
ls /proc/device-tree/
cat /proc/device-tree/soc/twi@*/clock-frequency | xxd
```

### 4. 查看驱动probe日志
```bash
dmesg | grep -i "twi\|i2c"
```

## 参考资料

1. **Linux内核文档**: `Documentation/devicetree/bindings/`
2. **驱动源码**: `bsp/drivers/`
3. **SoC DTSI**: `bsp/configs/linux-5.4-ansc/sun300iw1p1.dtsi`
4. **参考板配置**: `device/config/chips/v821/configs/*/board.dts`

---

**提示**: 修改设备树后必须重新编译并烧录才能生效！
