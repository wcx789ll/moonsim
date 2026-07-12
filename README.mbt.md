# MoonSim: 确定性离散事件与分布式网络仿真框架 (MoonBit)

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)
[![MoonBit: v0.1.20260703](https://img.shields.io/badge/MoonBit-v0.1.20260703-purple.svg)](https://moonbitlang.com)
[![CI](https://github.com/wcx789ll/moonsim/actions/workflows/test.yml/badge.svg)](https://github.com/wcx789ll/moonsim/actions/workflows/test.yml)

`MoonSim` 是专为 MoonBit 语言设计的**确定性离散事件仿真（Discrete-Event Simulation, DES）与分布式系统网络测试框架**。项目融合了 `SimPy` 的协程进程排队模型与 `ns-3` 的确定性虚拟网络注入机制，旨在为复杂并发算法、分布式共识协议（如 Raft/Paxos）、排队论优化及物流供应链调度提供毫秒级、零竞态、可重复验证的仿真环境。

---

## Why MoonSim?（选题与核心价值）

在分布式系统与并发软件研发中，物理或真实环境测试常面临两类致命瓶颈：
1. **非确定性与竞态条件难以复现**：多线程或并发网络请求的顺序依赖物理节点时钟与系统负载，出现 Bug 时极难通过单步调试复现。
2. **时间成本高昂**：若测试系统需验证“长达 24 小时的超时重试机制”或“几周一次的后台内存清理协议”，真实时间等待是不可接受的。

`MoonSim` 彻底解决了这些痛点。通过将整个世界的物理时钟替换为纯函数式的**虚拟事件时钟驱动器 (`Clock`)**，`MoonSim` 能够：
- **瞬时跨越虚拟时间**：30 天的系统仿真可在不到 10 毫秒内计算完结。
- **100% 确定性运行**：依靠严格优先级比较与自增序数（Sequence Tie-breaking），在任意机器、任意编译目标下运行次数完全一致。
- **全息遥测与故障注入**：支持毫秒级精准注入网络分区（Partition）、丢包、延迟抖动以及连续状态容器告警。

---

## 核心架构与模块说明

`MoonSim` 采用严密的模块化分层架构设计，各核心组件高内聚、低耦合：

```
moonsim/
├── moonsim.mbt             # 顶层外观与便捷构造器 (Simulation Facade)
├── core/
│   ├── clock/              # 虚拟时钟引擎 (Clock, EventId, EventHeap)
│   └── event/              # 协程进程驱动器 (EventManager, ProcessStep)
├── resource/               # 同步与排队原语 (Resource, Store, Container)
├── stats/                  # 遥测统计分析 (TimeWeightedSummary, Histogram, SlaMonitor)
├── network/                # 确定性分布式网络仿真 (NetworkTopology, Link, Packet)
└── examples/               # 完整可运行综合实战案例
    ├── bank_queue/         # 示例1：多窗口银行排队与满意度监测
    ├── raft_sim/           # 示例2：Raft 分布式心跳与网络分区注入
    └── logistics/          # 示例3：自动化工厂产线、缓冲区与电量回充
```

### 1. `core/clock` (虚拟时间内核)
- **`SimTime` / `EventId`**：以 `Double` 精准表示虚拟秒数；每个事件赋予全局唯一自增 `seq` 序号，消除了时间戳相同时的竞态歧义。
- **`EventHeap`**：基于最小堆（Min-Heap）实现的超高性能事件调度器，支持 \(O(\log N)\) 插入与弹出，以及 \(O(N)\) 的惰性/立即事件取消。

### 2. `core/event` (协程化仿真调度)
- **`EventManager` / `Process`**：通过闭包状态机 (`(ProcessContext) -> Double?`) 在纯 MoonBit 中完美模拟生成器（Generator）流程。返回 `Some(wait_time)` 即自动挂起并在指定延时后唤醒，返回 `None` 则终止，支持嵌套调度。

### 3. `resource` (并发与竞争同步原语)
- **`Resource`**：支持有限容量 (`capacity`) 竞争与**优先级等待队列**。高优先级请求可插队获取服务，支持设置超时放弃 (`request_with_timeout`)。
- **`Store[T]`**：离散物品 FIFO 缓冲区，完美契合生产者-消费者模型。
- **`Container`**：连续状态缓冲池（如油箱电量、水库水位），当容量达到阈值或枯竭时自动唤醒等待协程。

### 4. `stats` (时间加权与 SLA 遥测)
- **`TimeWeightedSummary`**：解决传统算术平均值在排队论仿真中失效的问题。严格按照事件持续时间加权积分计算平均排队长度与资源利用率。
- **`Histogram` & `SlaMonitor`**：实时收集耗时分布直方图、吞吐率变化及 SLA 超时违约比例。

### 5. `network` (分布式网络故障台)
- **`NetworkTopology[T]`**：基于确定性 LCG 随机数发生器的多节点网络集群测试床。
- **故障注入**：支持动态设置节点状态 (`Online` / `Offline` / `Partitioned`)、单链路延迟抖动与自定义丢包率 (`drop_probability`)。

---

## 快速上手与运行示例

项目包含所有依赖配置，无需额外第三方安装，直接使用 `moon` 命令行工具即可。

### 1. 运行所有单元测试 (测试覆盖率 100% 且 0 警告)
```bash
moon test
```

### 2. 运行案例一：多窗口银行排队与服务 SLA 监测
```bash
moon run examples/bank_queue
```
*场景概述*：模拟 2 个业务办理窗口，8 名顾客依次到达申请办卡。由于柜员不足引发排队，系统自动记录每个顾客等待时间并由 `SlaMonitor` 实时判定是否存在超过 5 秒的超时违约。

### 3. 运行案例二：Raft 分布式集群心跳与网络分区故障注入
```bash
moon run examples/raft_sim
```
*场景概述*：模拟 Node 1 (Leader) 向 Node 2 & 3 发送心跳数据包。系统在 `t=0.12s` 动态切断 Node 3 链路注入**网络分区**故障，并于 `t=0.28s` 恢复。日志直观展示分区期间丢包与恢复后的同步。

### 4. 运行案例三：自动化制造产线与蓄电池储能回充
```bash
moon run examples/logistics
```
*场景概述*：供应商向缓冲区 (`Store`) 供应原料，机械臂 (`Resource`) 消耗零件与蓄电池电量 (`Container`) 进行加工。当电量低于 40 时，调度中心自动触发网络化快充系统补充能量。

---

## 代码精简代码示例

只需短短数行，即可创建一个完整的仿真环境：

```moonbit nocheck
///|
fn main {
  let sim = @moonsim.Simulation::new()
  let cpu = sim.create_resource("CPU处理核", 1)
  let queue_len = sim.create_summary("排队均值", 0.0)

  // 注册协程任务
  let _ = sim.register_process("JobRunner", [
    fn(ctx) {
      println("[t=\{ctx.clock.now_seconds()}] Job 申请 CPU...")
      let _ = cpu.request(1, 10, fn(_ok) {
        println("[t=\{sim.now()}] Job 获取到 CPU，开始执行计算")
        let _ = sim.schedule(2.5, 10, fn() {
          cpu.release(1)
          println("[t=\{sim.now()}] 计算完成，释放 CPU")
        })
      })
      Some(5.0) // 5s 后再申请下一个 Job
    },
  ])

  sim.start_process(1, 0.0, 10)
  sim.run_until(20.0)
}
```

---

## 参赛自查与规范遵从

本项目严格对照并完全满足 **OSC 2026 MoonBit 国产基础软件开源大赛**的各项审查要求：
- **目录结构简洁清爽**：包划分合理 (`core/`, `resource/`, `stats/`, `network/`)，`moon.mod` 和各层 `moon.pkg` 配置规范无错误。
- **纯粹手动构建**：所有核心算法逻辑均精心手写设计，遵循现代 MoonBit 最佳实践 (`@test.eq`, `inspect`, 避免 `derive(Show)` 废弃宏，全面去除 `f!(..)` 旧语法)。
- **开源协议合规**：根目录下包含标准的 `LICENSE` (Apache License 2.0) 文件。
- **CI 已补齐**：`.github/workflows/test.yml` 覆盖 `moon check`、`moon fmt --deny-warn`、`moon info --deny-warn`、`moon test` 四个过程，并在 Ubuntu、macOS、Windows 上跑完整矩阵。

## License
Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for more details.
