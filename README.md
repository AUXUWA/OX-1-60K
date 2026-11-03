# OX-1 —— 基于 FPGA 的实时多音色 FM 合成电子乐器引擎

全国大学生嵌入式芯片与系统设计竞赛 2026 · FPGA 创新设计赛道（高云赛道）参赛作品。

一台跑在 FPGA 上的 4 算子 FM 电子乐器：**240 个声部 × 每声部 4 算子 = 960 个同时活跃的独立振荡器**，
音频输出采样率 **48.828 kHz**（振荡器·采样吞吐 4.69 × 10⁷/秒），音频通路 **0 个 DSP 乘法器**。

## 特性

- **音源**：4 算子 FM（OPL3 对数域架构），按 OPL3 硬件行为逐比特对拍验证；
  算子运算核时分复用（4 个物理核轮转 240 声部），状态走 BSRAM
- **音频**：I2S → PT8211-S DAC，48.828 kHz / 16bit；总线混响（4-line FDN + Haas）
- **演奏**：25 半音键（C3~C5）+ 4×EC11 旋钮 + 6 独立功能键（SHIFT 分层）
- **显示**：7 寸 HDMI 1024×600 双页界面 —— PAGE 1 参数面板 + 频谱 / 波形 / 李萨如图区，
  PAGE 2 音序器（4 轨 × 32 步）
- **音序器**：4 轨同奏合唱，真齐奏走引擎声部
- **扩展**：蓝牙 UART 下发曲谱 / 音色，WS2812 键位灯演奏指引

## 硬件

| 项 | 型号 |
| :--- | :--- |
| FPGA | Sipeed **Tang Mega 60K**（GW5AT-LV60PG484AC1/I0，GW5AT-60B） |
| DAC | PT8211-S（板载，I2S，无 I2C） |
| 显示 | 7 寸 HDMI 屏（1024×600 @ 48 MHz 像素时钟） |

## 构建

1. 安装 Gowin IDE（开发用 V1.9.12 验证）；
2. 用 Gowin IDE 打开 `OX-1-60K.gprj`；
3. 直接跑综合 → 布局布线 → 位流，烧写到板即可。

约束文件在 `constraints/`：`OX-1-60K.cst`（引脚）、`fm_synth-60K.sdc`（时序）。
两条踩过的硬件坑（详情见两文件内残留的一行说明与本节）：

- **BANK9 在 60K 上是 1.5 V**：`rst_n` / `key1_n` / `key2_n` 所在 bank 必须
  `LVCMOS15 + BANK_VCCIO=1.5`，照抄 138K 例程的 3.3 V 会烧 bank；
- **TMDS 输出用 `LVCMOS33D + DRIVE=8`**，不要抄 Sipeed 例程的 `DRIVE=3.5`
  （Gowin 只给 WARN CT1108 不报错，驱动强度会落到未知档）。

## 目录结构

```
opensource/
├── OX-1-60K.gprj        Gowin 工程文件（文件清单即综合所需全集）
├── constraints/         引脚约束（.cst）+ 时序约束（.sdc）
└── rtl/
    ├── top/             顶层 fm_synth_top、时钟/复位、TDM 分组、演示控制器
    ├── audio/           FM 引擎（fm_engine / fm_voice）、算子核、共享 LFO-EG
    │   ├── op/          算子运算核（op_core 等，纯组合、无状态）
    │   ├── shared/      logsin/exp ROM、波形查找、芯片级 LFO / EG 定时器
    │   └── mixer/       混音 + 饱和 + 混响效果
    ├── app/             应用层：音符管理、参数编辑、音序器、蓝牙曲谱链路
    ├── io/              设备层：input（键盘/旋钮）、video（HDMI）、audio（I2S）、output（WS2812/UART）
    ├── mem/             TDM 状态存储（相位/包络/参数/音符/曲谱/音色）
    └── common/          共享常量表（.vh：算法掩码 / EG 步进 / 音高 LUT / 参数字段）
```

## 说明

- 本发行版源码注释已精简（每文件保留一行模块说明），Verilog 代码与主开发仓一致。
- `char_rom.v` / `seq_page.v` / `param_panel.v` 通过 `$readmemh` 加载同目录下的
  `font_8x16.hex` / `tpl_rom.hex` / `seq_tpl_rom.hex`（ROM 初值），勿删。

## 许可证

[MIT](LICENSE)
