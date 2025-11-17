# GC02M1 ISP603 参数转换说明

## 概述

由于没有 GC02M1 的 ISP603 原生参数，本配置是从 GC2083 ISP603 参数转换而来。

## 文件位置

**新创建的配置文件**:
```
platform/allwinner/vision/libAWIspApi/isp_mpp/isp_v821/libisp/isp_cfg/SENSOR_H/gc02m1/
└── gc02m1_mipi_isp603_converted_from_gc2083.h
```

**修改的文件**:
1. `isp_ini_parse.c` - 添加 GC02M1 include 和配置条目
2. `tina.mk` - 添加 GC02M1 编译宏

## 转换过程

### 1. 基础转换
- 复制 GC2083 ISP603 配置作为模板
- 替换所有变量名: `gc2083_mipi_rgb` → `gc02m1_mipi_rgb`
- 替换所有宏定义: `GC2083_MIPI_RGB` → `GC02M1_MIPI_RGB`
- 更新头部注释，标注分辨率为 1600x1200@30fps

### 2. 参数适配（基于 ISP522 GC02M1）

**已从 ISP522 GC02M1 适配的参数**:
- ✅ **曝光范围** (exp_line_start: 160, exp_line_end: 32000)
- ✅ **增益范围** (gain_start: 16, gain_end: 256)
- ✅ **默认曝光/增益** (isp_gain: 360, isp_exp_line: 1200)
- ✅ **色温** (isp_color_temp: 6500K)
- ✅ **AE 最大亮度** (ae_max_lv: 1380)
- ✅ **AE 曝光表** (ae_table_preview/capture/video - 使用 ISP522 的值)

**保持 GC2083 ISP603 的参数**（因为 ISP522 结构差异太大）:
- ISP 模块开关 (ae_en, awb_en, denoise_en 等)
- 图像处理参数 (降噪、锐化、色彩校正、去马赛克等)
- WDR、PLTM、GCA 等 ISP603 特有模块参数
- LSC/LCA 参数（需要实际镜头标定数据）

## 配置注册

在 `isp_ini_parse.c` 中的配置:

```c
#ifdef SENSOR_GC02M1
    #include "SENSOR_H/gc02m1/gc02m1_mipi_isp603_converted_from_gc2083.h"
#endif

// 配置表
{"gc02m1_mipi", "gc02m1_mipi_isp603_converted_rgb", 1600, 1200, 30, 0, 0, &gc02m1_mipi_rgb_isp_cfg}
```

## 使用方法

### 1. 编译
```bash
cd /home/f/tina/tina-v821-release
make package/allwinner/vision/libAWIspApi/clean
make package/allwinner/vision/libAWIspApi/compile
make package/allwinner/eyesee-mpp/compile
pack
```

### 2. 烧录
将新镜像烧录到设备

### 3. 验证
运行 sample_recorder，检查日志：
```
[ISP]prefer isp config: [gc02m1_mipi], 1600x1200, 30, 0, 0
[ISP]find gc02m1_mipi_1600_1200_30_0 [gc02m1_mipi_isp603_converted_rgb] isp config
```

应该显示找到 `gc02m1_mipi_isp603_converted_rgb` 配置。

## 预期效果

### 优点
✅ 有了专门的 GC02M1 配置文件
✅ 关键 3A 参数（曝光、增益、AE 表）已基于 ISP522 GC02M1 适配
✅ 曝光范围和增益范围符合 GC02M1 传感器特性
✅ 色温设置更合理（6500K vs 20000K）
✅ 代码结构清晰，未来容易替换为原厂调试参数

### 限制
⚠️ 图像处理参数（降噪、锐化等）仍然基于 GC2083
⚠️ LSC/LCA 镜头校正参数需要实际标定
⚠️ 某些场景（低光、高对比度）可能需要进一步调优
⚠️ 最佳画质仍需原厂提供的 GC02M1 专用 ISP603 参数

## 图像质量对比

| 场景 | 当前配置(转换自GC2083) | 专用GC02M1参数 |
|------|----------------------|---------------|
| 正常光照 | ✅ 良好 | ⭐ 优秀 |
| 低光环境 | ⚠️ 可用 | ⭐ 优秀 |
| 高对比度 | ⚠️ 可用 | ⭐ 优秀 |
| 色彩还原 | ✅ 良好 | ⭐ 优秀 |
| 动态场景 | ✅ 良好 | ⭐ 优秀 |

## 获取专用参数

如需最佳图像质量，建议向以下渠道索要 **GC02M1 的 ISP603 专用调试参数**：

### 1. 摄像头模组供应商
提供模组的厂商通常会有调试好的参数文件。

### 2. 格科微 (GalaxyCore)
作为传感器原厂，可能提供技术支持。

### 3. 全志科技
Allwinner 作为 V821 芯片厂商，可能有参考参数。

**索要时需要提供的信息**:
- 芯片型号: Allwinner V821
- ISP 版本: ISP603
- 传感器型号: GC02M1
- 分辨率: 1600x1200
- 帧率: 30fps
- 需要的文件格式: `.h` 格式的 ISP 参数文件

### 4. 替换流程

当获得专用参数后：

1. 将新的 `.h` 文件放到:
   ```
   platform/allwinner/vision/libAWIspApi/isp_mpp/isp_v821/libisp/isp_cfg/SENSOR_H/gc02m1/
   ```

2. 修改 `isp_ini_parse.c` 的 include:
   ```c
   #ifdef SENSOR_GC02M1
   #include "SENSOR_H/gc02m1/gc02m1_mipi_isp603_专用参数文件名.h"
   #endif
   ```

3. 更新配置表中的变量名和描述

4. 重新编译和烧录

## 参考文件

**GC2083 ISP603 原始配置** (转换模板):
```
SENSOR_H/gc2083/gc2083_mipi_isp603_20241205_171656_final_rgb_suit.h
```

**GC02M1 ISP522 配置** (仅供参考，不兼容ISP603):
```
openwrt/package/allwinner/vision/libAWIspApi/src/isp522/libisp/isp_cfg/SENSOR_H/gc02m1_mipi_r818.h
```

## 技术细节

### ISP522 vs ISP603 结构差异

**ISP522 (旧版):**
- 较少的图像处理模块
- 简化的 3A 算法
- 不支持某些高级功能 (如 WDR split/stitch)

**ISP603 (新版):**
- 更多的图像处理模块 (PLTM, LCA, CTC, GCA 等)
- 改进的 3A 算法
- 支持 WDR 高动态范围
- 更精细的降噪和锐化控制

### 为什么不能直接用 ISP522 的参数？

1. **结构体定义不同** - 字段数量和类型不匹配
2. **模块数量不同** - ISP603 有更多的处理模块
3. **参数范围不同** - 某些参数的有效范围变化了
4. **算法升级** - 3A 算法的实现方式改变了

## 故障排查

### 问题1: 编译错误 "undefined reference to gc02m1_mipi_rgb_isp_cfg"
**原因**: 配置文件中的变量名不一致
**解决**: 检查 `.h` 文件末尾的总配置结构名称是否为 `gc02m1_mipi_rgb_isp_cfg`

### 问题2: 运行时找不到配置
**原因**: `SENSOR_GC02M1` 宏未定义
**解决**: 确认 `make menuconfig` 中 `use sensor gc02m1` 已勾选

### 问题3: 图像偏色
**原因**: 白平衡参数不适合 GC02M1
**解决**: 需要真正的 GC02M1 专用参数，或手动调试 AWB 参数

---

**创建时间**: 2025-11-17
**适用版本**: V821 ISP603
**状态**: 转换版本（建议替换为专用参数）
