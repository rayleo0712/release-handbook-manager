# 长时运行与中断恢复（rta 分片）

> 本分片由 `skills/release-test-auto/SKILL.md` §1.4 结果文件推荐字段、§五 长时间运行与中断恢复搬迁而来，原文口径不变。
> 加载时机：会话中断续跑、修完 bug 重启、判定测试是否真正完成、设置超时、初始化结果文件时。

## 1.4 自动化测试结果文件真源 · 推荐字段

自动化测试必须把状态持续写入磁盘，至少包含以下文件：

- `test-output/run-status.json`
- `test-output/checkpoints.json`
- `test-output/case-results/{case-id}.json`
- `test-output/final-report.md`

推荐字段：

**`run-status.json`**

```json
{
  "version": "v1.2.3",
  "status": "running",
  "total_count": 0,
  "completed_count": 0,
  "passed_count": 0,
  "failed_count": 0,
  "skipped_count": 0,
  "current_case_id": "",
  "started_at": "",
  "updated_at": "",
  "completed_at": ""
}
```

**`checkpoints.json`**

```json
{
  "last_completed_case_id": "",
  "completed_case_ids": [],
  "failed_case_ids": [],
  "resume_from_case_id": ""
}
```

## 五、长时间运行与中断恢复

这是本 Skill 的强制能力，不能省略。

### 5.1 不依赖会话持续存活

自动化测试必须通过 **IDE 内置终端或等价命令行环境中的独立脚本或进程** 运行，不得依赖聊天会话持续不断线。

### 5.2 每条用例执行后立即落盘

每执行完 1 条测试用例，必须立刻写入结果文件，包括：

- 用例编号
- 角色
- 执行时间
- 通过/失败/跳过
- 截图路径
- 错误信息

### 5.3 断点恢复

必须支持续跑：

- 读取 `checkpoints.json`
- 跳过已完成用例
- 从未完成用例继续

若测试过程因以下原因中断：

- 聊天会话中断
- 终端命令被停止
- 服务重启
- AI 修复 bug 后需要重新启动项目

则应按以下顺序恢复：

1. 检查 `run-status.json` 是否仍为 `running`
2. 读取 `checkpoints.json`
3. 重新启动环境
4. 跳过已完成用例
5. 从 `resume_from_case_id` 或下一个未完成用例继续

### 5.4 完成判定

只有以下条件同时满足，才可判定“全部测试完成”：

1. `completed_count == total_count`
2. `passed_count + failed_count + skipped_count == completed_count`
3. `run-status.json.status == "completed"`
4. `completed_at` 已写入且非空
5. `final-report.md` 已生成

若缺任一项，均视为“测试未完成”，不得误报完成。

### 5.5 防卡死规则

- 单用例必须设置超时
- 页面等待必须设置超时
- 超时后要记录失败并继续后续用例
- 不得因 1 条用例挂死导致整批测试永远不结束

建议默认值：

- 页面加载等待超时：30 秒
- 单用例超时：180 秒
- 单角色登录超时：60 秒
- 恢复数据库超时：按项目大小单独设置，但必须写入脚本注释

### 5.6 修复后重启续跑

当 AI 在自动化测试中定位到 bug 并完成修复后：

1. 应优先停止旧测试进程与旧服务进程
2. 重新执行 IDE 内置终端或等价命令行环境中的启动命令
3. 重新执行健康检查
4. 判断是否需要恢复数据库基线
   - 若修复内容会影响测试数据一致性，则应重新恢复数据库
   - 若仅为页面展示或前端交互修复，可按需直接续跑
5. 使用续跑模式继续执行，而不是从头盲目全量重跑
