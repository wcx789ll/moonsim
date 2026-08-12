# OSC 2026 MoonBit 参赛项目：MoonSim

## 项目与仓库

- 项目名称：MoonSim
- Mooncakes 模块：`wcx789ll/moonsim`
- GitHub：<https://github.com/wcx789ll/moonsim>
- GitLink：<https://www.gitlink.org.cn/Wcxwcx/moonsim>
- 许可证：Apache License 2.0
- 类型：原创 MoonBit 仿真基础软件；未复制 SimPy、ns-3 或其他项目源代码

## 项目摘要

MoonSim 是使用 MoonBit 实现的确定性离散事件仿真框架，统一支持虚拟时钟、稳定事件排序、多步骤进程、资源竞争、截止期调度、确定性网络故障注入和可复现统计。它用于在秒级运行中验证数小时或数天的排队、网络和分布式系统模型。

## 核心功能与应用场景

1. `core/clock`：最小堆、优先级和序列号联合排序、取消、过滤和目标时间。
2. `resource`：容量资源、FIFO Store、连续 Container 和优先级抢占。
3. `scheduler`：FIFO、LIFO、优先级、SJF、EDF 等队列策略及截止期统计。
4. `network`：节点状态、链路延迟、固定种子丢包、带宽/缓冲区和分区恢复。
5. `stats` 与 `trace`：时间加权均值、P50/P95/P99、SLA、吞吐、CSV 追踪。
6. `benchmarks`：事件 10,000、网络 2,000、调度 1,000 的标准可复现基线。

可运行案例包括银行窗口排队、Raft 心跳分区、物流生产线、云 GPU 抢占、微服务灰度流量和验收基准。

## 工程量与验证

核心包、基准包和门面实现合计超过 3,000 行 MoonBit 实现代码；测试覆盖时钟、事件、资源、网络、调度、统计、追踪、门面和基准边界。当前本地 wasm 与 wasm-gc 全量测试各为 40 个通过；JS 目标需要 Node.js 才能运行。

标准复核命令：

```bash
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon fmt --check
moon info --target all
moon run examples/acceptance_benchmark
```

## 交付物

- 可发布的 MoonBit 模块与根目录 Apache-2.0 许可证；
- README、快速开始、案例命令、边界说明和基准结果；
- `.github/workflows/test.yml` 多平台 CI；
- `benchmarks/suite.mbt` 与对应测试，便于验收复测；
- `THIRD_PARTY.md` 开源来源与再分发登记说明。
