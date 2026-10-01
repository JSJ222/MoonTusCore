# MoonTusCore

MoonTusCore 是使用 MoonBit 原创实现的 tus 1.0 可恢复上传协议决策层。它接收
与 HTTP 同形的普通值，完成严格校验和原子状态转换，但不绑定 Web 框架、网络
服务、认证系统或持久化方案。

v0.1 已实现 Core、Creation 和 Creation-Defer-Length，提供：

- OPTIONS、POST、HEAD、PATCH 协议流程；
- X-HTTP-Method-Override 方法覆盖及 HEAD 创建元数据回显；
- Upload-Offset 冲突检测与 revision + offset 比较交换提交；
- 已知长度及延迟声明长度；
- 有序 Upload-Metadata 和严格 RFC 4648 Base64；
- 请求头、路径、元数据、单次分片及总上传大小限制；
- 稳定错误码、决策追踪、内存参考存储；
- 文本/JSON 场景报告、10 个一致性向量、Native CLI 和库示例。

## 本地验证

安装已发布的库：`moon add JSJ222/tus-core@0.1.1`。

~~~bash
moon check --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon test --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon build --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon run cmd/moontus --target native -- demo success
moon run cmd/moontus --target native -- demo conflict
moon run cmd/moontus --target native -- demo deferred --json
moon run examples/library-demo --target native
~~~

内存 TusEngine 用于演示和单进程测试。生产持久化适配器应先调用
plan_creation 或 plan_append，再使用 AppendPlan 中的 expected_revision 与
old_offset 执行条件写入。校验失败或竞争失败均不得修改任何字节。

## 明确边界

v0.1 不实现 Creation-With-Upload、Checksum、Expiration、Termination、
Concatenation、HTTP 服务端/客户端、认证、租户配额和病毒扫描，也不会在
OPTIONS 中宣称支持这些扩展。完整边界见 docs/protocol-scope.md。

GitHub 公开仓库位于 https://github.com/JSJ222/MoonTusCore；Mooncakes 包位于
https://mooncakes.io/docs/JSJ222/tus-core。Gitlink 镜像不在本次发布范围内。
