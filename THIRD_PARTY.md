# Third-party and generated material notice

MoonSim 当前的核心实现、测试和示例均由本项目维护者使用 MoonBit 编写。仓库没有复制 SimPy、ns-3、Raft 实现或商业软件源代码；这些名称只用于描述适用场景、算法背景或模型对照。

| 项目 | 官方链接 | 许可证 | 在 MoonSim 中的关系 |
| --- | --- | --- | --- |
| SimPy | https://simpy.readthedocs.io/en/stable/ | MIT | 仅参考进程/资源仿真问题域，不复制代码、不引入 Python 依赖 |
| ns-3 | https://www.nsnam.org/ | GNU GPLv2 | 仅参考网络离散事件和故障注入场景，不复制代码、模型或文档 |

MoonSim 的独立实现采用 Apache License 2.0；参考项目的许可证不被带入 MoonSim 源码。

当前测试使用项目自造的确定性参数和消息，不依赖外部数据集。`pkg.generated.mbti` 文件由 MoonBit `moon info` 生成，属于本项目构建接口记录，不是第三方源代码。

如果后续提交引入第三方代码、测试数据、图片、协议文本或生成产物，必须在此文件登记名称、来源 URL、版本、原许可证、修改范围和再分发条件，并在相应目录保留必要的版权声明。

本项目整体许可证为 Apache License 2.0，详见根目录 [LICENSE](LICENSE)。
