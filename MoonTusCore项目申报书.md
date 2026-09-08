# MoonTusCore 项目申报书
- 项目名称：MoonTusCore：框架与存储无关的 tus 1.0 可恢复上传协议状态机
- 参赛者：蒋尚君
- 联系方式：
- GitHub 仓库：https://github.com/JSJ222/MoonTusCore
- Gitlink 仓库：https://gitlink.org.cn/JSJ222/MoonTusCore
- 项目方向：MoonBit 原生网络协议基础库、可恢复上传状态机与开发工具
- 项目性质：原创项目，非移植；许可证：Apache License 2.0
## 项目简介与使用场景
MoonTusCore 将 tus 1.0 可恢复上传的协议判断与 Web 框架、网络 I/O、认证及具体存储解耦，把普通请求值转换为有界、可追踪、可原子提交的状态转换。
项目面向 MoonBit Web 框架作者、对象存储/数据库适配器作者和大文件上传应用，解决重复请求头、陈旧偏移覆盖、延迟长度冲突、整数溢出及拒绝后误写等问题。
## 核心功能
- 实现 tus 1.0 Core、Creation、Creation-Defer-Length，以及 OPTIONS、POST、HEAD、PATCH 完整参考流程。
- 严格处理 Tus-Resumable、方法覆盖、Upload-Offset、Upload-Length、Content-Length、媒体类型及 HEAD 元数据回显。
- 通过 revision + offset 比较交换实现先验证后提交；偏移冲突、重放、超限或格式错误均不改变已存字节。
- 提供稳定错误码、规范章节追踪、资源预算、内存参考存储、文本/JSON 场景报告及 10 个可执行一致性向量。
- 提供 Native moontus CLI、4 个内置演示、库集成示例、中英文 README、架构/安全/适配/边界/发布文档及多平台 CI。
## 实现方案、边界与交付
采用“线性有界解析器→纯协议规划器→条件写入存储契约→参考引擎”架构；生产适配器复用 plan_creation/plan_append，并以 expected_revision 和 old_offset 执行原子条件写入。
本地 v0.1 含 35 个 .mbt 文件、4995 行 MoonBit 源码，其中排除空行和纯行注释后的有效代码 4363 行；92 项测试在 wasm、wasm-gc、js、native 四目标共 368 次全部通过。
v0.1 不实现 Creation-With-Upload、Checksum、Expiration、Termination、Concatenation、HTTP 服务端/客户端、认证、租户配额或病毒扫描；内存存储仅用于参考与测试。
项目检索记录未发现 Mooncakes 或公开 MoonBit 仓库中已有 tus 1.0 服务端状态机；通用 Web 框架仅提供传输抽象，不覆盖本项目的偏移、延迟长度和存储原子语义，发布前将再次检索。
交付 Apache-2.0 源码、完整文档、可执行示例、测试、CI 和可追踪提交历史；GitHub 仓库已公开，Gitlink 镜像及 mooncakes.io 发布尚待完成。
协议语义依据 MIT 许可的 tus 1.0.0 公开规范；项目未复制其他 tus 实现代码、无运行时第三方包依赖，不包含私有、闭源、商业或来源不明内容。
