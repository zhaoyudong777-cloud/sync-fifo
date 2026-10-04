# 同步FIFO

用Verilog写的同步FIFO，额外bit法判断空满。

## 功能

- 同步时钟设计
- 额外bit法空满判断
- 可配置位宽、深度、almost阈值
- data_count输出当前数据个数
- almost_full / almost_empty 预通知
- 寄存器输出，时序稳定
- 写满/读空保护

## 接口

| 信号 | 方向 | 说明 |
|------|------|------|
| clk | input | 时钟 |
| rst_n | input | 异步复位，低有效 |
| wr_en | input | 写使能 |
| rd_en | input | 读使能 |
| data_in | input | 写数据 |
| data_out | output | 读数据（寄存器输出，晚一拍） |
| full | output | 满标志 |
| empty | output | 空标志 |
| almost_full | output | 快满标志 |
| almost_empty | output | 快空标志 |
| data_count | output | FIFO内数据个数 |

## 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| DATA_WIDTH | 8 | 数据位宽 |
| FIFO_DEPTH | 16 | 深度 |
| ALMOST_FULL_TH | 2 | almost_full阈值 |
| ALMOST_EMPTY_TH | 2 | almost_empty阈值 |

## 原理

### 空满判断

指针比地址多一位，最高位当"圈数标记"：
- 空：wr_ptr == rd_ptr（所有位都相等）
- 满：最高位不同，低位相同（写指针多跑了一圈）

### 寄存器输出

读输出打了一拍寄存器，不是组合逻辑直接出：
- 好处：时序稳，没有组合逻辑冒险
- 坏处：数据晚一个周期出来
- 一般设计里这一拍延迟都能接受

### data_count

计数器法：
- 只写 +1
- 只读 -1
- 同时读写不变

## 文件结构

```
sync_fifo/
├── src/
│   └── sync_fifo.v
├── tb/
│   └── tb_sync_fifo.v
├── docs/
│   ├── wave_write_full.png
│   ├── wave_read_empty.png
│   └── wave_rw_test.png
└── README.md
```

## 仿真

用Icarus Verilog + GTKWave：

```bash
iverilog -o fifo_sim src/sync_fifo.v tb/tb_sync_fifo.v
vvp fifo_sim
gtkwave wave.vcd
```

Testbench是自校验的，跑完会打印"全部通过"或者错误数。

## 测试场景

1. 复位状态检查
2. 写5个读5个（校验数据顺序）
3. 写满（多写4个，测满保护）
4. 读空（多读4个，测空保护）
5. data_count 和 almost 标志检查
