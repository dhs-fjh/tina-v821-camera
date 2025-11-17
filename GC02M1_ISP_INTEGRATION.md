# GC02M1 摄像头 ISP 集成说明

## 问题背景

GC02M1 摄像头驱动可以加载，I2C通信正常，但 ISP 初始化时找不到 GC02M1 的配置参数，回退使用了 GC2083 的配置：

```
[ISP_WARN]cannot find gc02m1_mipi_1600_1200_30_0_0 isp config,
use gc2083_mipi_1920_1088_15_0_0
```

## 原因分析

V821 的 ISP603 配置是硬编码在代码中的，每个传感器需要：
1. ISP 调试参数文件 (`.h` 格式)
2. 在 `isp_ini_parse.c` 中注册配置
3. 在编译系统中启用对应的宏定义

GC02M1 原本没有这些配置，所以 ISP 找不到对应参数。

## 解决方案

**复用 GC2083 的 ISP 参数**

GC2083 和 GC02M1 都是格科微 (GalaxyCore) 的 200万像素传感器，参数接近，可以先复用 GC2083 的 ISP 调试参数。

## 已完成的修改

### 1. 添加传感器支持 (`isp_ini_parse.c`)

**文件**: `/home/f/tina/tina-v821-release/platform/allwinner/vision/libAWIspApi/isp_mpp/isp_v821/libisp/isp_cfg/isp_ini_parse.c`

#### 修改1：添加到传感器列表 (行32-36)
```c
#if defined(SENSOR_GC2053) || defined(SENSOR_GC1084) || defined(SENSOR_GC2083) || defined(SENSOR_GC02M1) || \
	defined(SENSOR_F37P) || defined(SENSOR_SC2336) || defined(SENSOR_SC3336)|| \
	defined(SENSOR_SC200AI) || defined(SENSOR_BF2257CS) || defined(SENSOR_IMX258) || \
	defined(SENSOR_GC4663) || defined(SENSOR_F58) || defined(SENSOR_OS02G10) || defined(SENSOR_SC1346) || \
	defined(SENSOR_SP1405)
```

#### 修改2：添加 include 头文件 (行64-68)
```c
#ifdef SENSOR_GC02M1
/* GC02M1 reuses GC2083 ISP parameters (both are GalaxyCore 2MP sensors) */
#include "SENSOR_H/gc2083/gc2083_mipi_isp603_20241205_171656_final_rgb_suit.h"
#include "SENSOR_H/gc2083/gc2083_mipi_isp603_20241205_171656_final_ir.h"
#endif
```

#### 修改3：添加配置表条目 (行1045-1049)
```c
#ifdef SENSOR_GC02M1
	/* GC02M1: 1600x1200 @ 30fps, reusing GC2083 ISP parameters */
	{"gc02m1_mipi",  "gc02m1_mipi_isp603_reuse_gc2083_rgb", 1600, 1200, 30, 0, 0, &gc2083_mipi_rgb_isp_cfg},
	{"gc02m1_mipi",  "gc02m1_mipi_isp603_reuse_gc2083_ir", 1600, 1200, 30, 0, 1, &gc2083_mipi_ir_isp_cfg},
#endif
```

**配置表格式说明：**
```c
{"传感器名", "配置描述", 宽度, 高度, 帧率, 保留, IR标志, &配置数据指针}
```
- 传感器名: `gc02m1_mipi` (与驱动 `sensor0_mname` 匹配)
- 分辨率: 1600x1200 (GC02M1 实际分辨率)
- 帧率: 30fps
- IR标志: 0=RGB彩色, 1=IR红外

### 2. 添加编译定义 (`tina.mk`)

**文件**: `/home/f/tina/tina-v821-release/platform/allwinner/vision/libAWIspApi/isp_mpp/isp_v821/libisp/isp_cfg/tina.mk`

#### 修改：添加 GC02M1 编译宏 (行67-70)
```makefile
ifeq ($(findstring gc02m1,$(SENSOR_NAME)), gc02m1)
	LOCAL_CFLAGS += -DSENSOR_GC02M1=1
	LOCAL_CXXFLAGS += -DSENSOR_GC02M1=1
endif
```

这会在传感器名称包含 `gc02m1` 时自动定义 `SENSOR_GC02M1` 宏。

## 编译和测试

### 1. 编译系统
```bash
cd /home/f/tina/tina-v821-release
make
```

### 2. 打包镜像
```bash
pack
```

### 3. 烧录到设备

### 4. 验证结果

运行 sample_recorder，检查日志应该显示：
```
[ISP]prefer isp config: [gc02m1_mipi], 1600x1200, 30, 0, 0
找到配置: gc02m1_mipi_isp603_reuse_gc2083_rgb
```

**不应该再出现** "cannot find gc02m1_mipi" 的警告。

## 配置匹配逻辑

ISP 根据以下参数匹配配置：
1. **传感器名称**: `sensor0_mname = "gc02m1_mipi"` (board.dts)
2. **分辨率**: 1600x1200
3. **帧率**: 30fps
4. **IR模式**: 0 (RGB)

配置表中的条目：
```c
{"gc02m1_mipi", "...", 1600, 1200, 30, 0, 0, ...}
```

完全匹配后，ISP 会使用 `&gc2083_mipi_rgb_isp_cfg` 的参数进行图像处理。

## 复用 GC2083 参数的影响

### 优点
✅ 快速启动，可以立即测试摄像头功能
✅ GC2083 和 GC02M1 芯片相似，参数基本兼容
✅ 可以先验证硬件连接是否正确

### 缺点
⚠️ 图像质量可能不是最优（色彩、清晰度、降噪等）
⚠️ 特定场景下可能有问题（低光、高对比度等）

### 后续优化
如果需要最佳图像质量，需要：
1. 联系摄像头模组供应商或格科微
2. 索要 **GC02M1 的 ISP603 调试参数文件** (.h 格式)
3. 替换当前复用的 GC2083 参数

## 传感器驱动配置

**设备树配置** (`board.dts`):
```dts
sensor0: sensor@5812000 {
    device_type = "sensor0";
    sensor0_mname = "gc02m1_mipi";       // 传感器名称（必须与配置表匹配）
    sensor0_twi_cci_id = <0>;            // I2C总线0
    sensor0_twi_addr = <0x6e>;           // I2C地址 0x6e
    sensor0_mclk_id = <0>;               // MCLK0
    sensor0_pos = "rear";
    sensor0_isp_used = <1>;              // 启用ISP
    sensor0_fmt = <1>;                   // MIPI格式
    sensor0_stby_mode = <0>;
    sensor0_vflip = <0>;
    sensor0_hflip = <0>;
    sensor0_iovdd_vol = <1800000>;       // IOVDD 1.8V
    sensor0_avdd_vol = <2800000>;        // AVDD 2.8V
    sensor0_dvdd_vol = <1500000>;        // DVDD 1.5V
    sensor0_reset = <&pio PA 2 GPIO_ACTIVE_LOW>;
    status = "okay";
};
```

## 传感器驱动代码

**文件**: `/home/f/tina/tina-v821-release/bsp/drivers/vin/modules/sensor/gc02m1_mipi.c`

**关键参数**:
```c
#define MCLK              (24 * 1000 * 1000)  // 24MHz
#define I2C_ADDR          0x6e                // I2C地址
#define V4L2_IDENT_SENSOR 0x02E0              // 传感器ID
```

## 参考资料

- GC2083 ISP配置: `SENSOR_H/gc2083/gc2083_mipi_isp603_20241205_171656_final_rgb_suit.h`
- ISP配置解析: `isp_ini_parse.c`
- 设备树配置: `device/config/chips/v821/configs/avaota_f1/linux-5.4-ansc/board.dts`
- 传感器驱动: `bsp/drivers/vin/modules/sensor/gc02m1_mipi.c`

## 故障排查

### 问题1：仍然提示 "cannot find gc02m1_mipi"
**原因**: 编译时没有定义 `SENSOR_GC02M1` 宏
**解决**: 检查 `SENSOR_NAME` 环境变量是否包含 `gc02m1`

### 问题2：图像质量差
**原因**: GC2083 参数不完全适配 GC02M1
**解决**: 向供应商索要 GC02M1 专用的 ISP 调试参数

### 问题3：编译错误
**原因**: 缺少 GC2083 的头文件
**解决**: 确保 `SENSOR_H/gc2083/` 目录下的 `.h` 文件存在

---

**文档创建时间**: 2025-11-17
**适用芯片**: Allwinner V821 (sun300iw1p1)
**ISP版本**: ISP603
