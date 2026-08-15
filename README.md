# MoonSim

MoonSim 是一个使用 MoonBit 编写的确定性离散事件仿真框架，面向排队系统、资源竞争、分布式网络故障注入和调度策略验证。它用虚拟时间替代墙钟时间，让同一输入在不同运行中得到相同的事件顺序和统计结果。

## 项目价值与边界

MoonSim 适合以下实际验证任务：

- 复现 Raft/Paxos 等分布式协议中的延迟、丢包、节点下线和网络分区；
- 评估银行窗口、服务线程池、生产线和物流缓冲区的排队与 SLA；
- 验证优先级资源、可抢占资源、截止期调度和批处理吞吐；
- 采集 P50/P95/P99、时间加权均值、直方图、吞吐率和事件追踪数据。

项目不替代真实网络压测、硬件性能测试或生产监控；它提供的是可复现的模型级验证环境。随机行为使用固定种子，模型参数和业务假设应在 README 或实验记录中明确说明。

## 目录

| 路径 | 内容 |
| --- | --- |
| `moonsim.mbt` | `Simulation` 顶层门面 |
| `core/clock` | 虚拟时钟、稳定优先级事件堆和取消/过滤 |
| `core/event` | 动作与多步骤进程调度 |
| `resource` | Resource、Store、Container、PreemptibleResource |
| `scheduler` | FIFO/LIFO/优先级/SJF/EDF 调度器 |
| `network` | 确定性网络拓扑、延迟、丢包、节点状态、带宽队列 |
| `stats` | 时间加权统计、直方图、吞吐、SLA、滑动窗口和百分位 |
| `trace` | 事件记录、筛选、CSV 导出和单调性校验 |
| `benchmarks` | 可重复的事件、网络和调度基准工作负载 |
| `examples` | 银行排队、Raft 分区、物流、云 GPU、微服务和验收基准 |

## 快速开始

需要 MoonBit 0.10.3 或更新版本。

### 克隆与依赖

仓库本身不依赖 Python、Node.js 或其他第三方运行库；只需要安装 MoonBit CLI。CI 会额外安装 Node.js 20，以便验证 JS 后端。

```bash
git clone https://github.com/wcx789ll/moonsim.git
cd moonsim
moon version --all
moon update
```

PowerShell 用户可以执行：

```powershell
git clone https://github.com/wcx789ll/moonsim.git
Set-Location moonsim
moon version --all
moon update
```

`moon update` 用于同步 MoonBit 模块依赖；当前仓库没有额外的第三方包需要手工安装。

```bash
moon check
moon test
moon run examples/bank_queue
moon run examples/raft_sim
moon run examples/logistics
moon run examples/acceptance_benchmark
```

验收基准会运行 10,000 个事件、2,000 个网络包和 1,000 个调度任务，并输出完成数、丢失数、截止期违约数、虚拟耗时、平均等待时间和 P95 延迟。基准代码在 `benchmarks/suite.mbt`，边界测试在 `benchmarks/suite_test.mbt`。

## 当前可复现基线

在本地 MoonBit 0.1.20260703 / Moonc 0.10.3 上运行 `moon run examples/acceptance_benchmark` 的结果为：

| 场景 | 负载 | 完成 | 丢失 | 关键指标 |
| --- | ---: | ---: | ---: | --- |
| 事件派发 | 10,000 | 10,000 | 0 | 虚拟时间 0.099s |
| 网络送达 | 2,000 | 1,892 | 108 | 丢包率 5.4%，P95 延迟 10ms |
| 截止期调度 | 1,000 | 1,000 | 0 | 8 执行器，平均等待 0.867162s |

这些数字是固定种子和固定输入下的模型基线，不应被解读为任何真实硬件或公网链路的性能承诺。修改算法后应重新运行并记录差异。

## 最小示例

```moonbit
fn main {
  let sim = @moonsim.Simulation::new()
  let cpu = sim.create_resource("CPU", 1)
  let _ = sim.schedule(1.0, 10, fn() {
    let _ = cpu.request(1, 10, fn(ok) {
      if ok {
        let _ = sim.schedule(2.0, 10, fn() { cpu.release(1) })
      }
    })
  })
  sim.run_until(10.0)
}
```

## 工程与验收检查

本地推荐按以下顺序执行：

```bash
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon fmt --check
moon info --target all
git diff --exit-code
```

仓库 CI 位于 `.github/workflows/test.yml`，覆盖 Ubuntu、macOS、Windows，并执行检查、格式、接口生成、构建和测试。JS 目标需要本机安装 `node`；没有 Node.js 时，MoonBit 的 JS 测试无法启动，但不影响 wasm/wasm-gc 检查。

## 开源合规

本项目源代码采用 Apache License 2.0，完整文本见 [LICENSE](LICENSE)。项目没有将第三方项目的源代码复制进仓库；SimPy、ns-3、Raft 等名称仅用于说明建模场景和设计对照，不表示代码派生关系。若未来引入外部代码、数据集或生成文件，应在提交前补充来源、版本、许可证和再分发说明，见 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 参考项目与差异范围

- [SimPy](https://simpy.readthedocs.io/en/stable/)：Python 离散事件仿真框架，官方文档标注 MIT License。本项目只借鉴“进程/资源/虚拟事件”的问题域，不复制 SimPy 代码，也不依赖 Python。
- [ns-3](https://www.nsnam.org/)：面向网络研究的离散事件网络模拟器，官方说明为 GNU GPLv2。本项目只参考网络仿真场景和故障注入需求；没有复制 ns-3 代码、模型或文档，MoonSim 继续采用 Apache-2.0。

参考项目的许可证、链接和独立实现范围也登记在 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 项目元数据

- Mooncakes 模块名：`wcx789ll/moonsim`
- GitHub：<https://github.com/wcx789ll/moonsim>
- GitLink：<https://www.gitlink.org.cn/Wcxwcx/moonsim>
- 许可证：Apache-2.0

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
