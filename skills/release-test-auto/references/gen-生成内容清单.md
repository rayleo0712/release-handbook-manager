# 生成内容清单（rta 分片）

> 本分片由 `skills/release-test-auto/SKILL.md` §三 生成内容搬迁而来（§3.1 启动脚本职责段、§3.3 恢复后校验脚本、§3.4 自动化测试执行脚本、§3.5 测试结果文件），原文口径不变。
> §3.1 的「中文显示与编码规范」与 §3.2 数据恢复脚本的编码约束，已单独搬至 `shell-编码与执行踩坑.md`。

## 三、生成内容

本 Skill 在执行时，应尽量自动生成以下内容，而不是让执行人手工拼装：

### 3.1 启动脚本

用于在 IDE 内置终端或等价命令行环境中启动当前项目，例如：

- `scripts/test-auto/start-env.ps1`
- `scripts/test-auto/start-env.sh`

职责：

- 启动依赖服务
- 启动后端
- 启动前端
- 输出 PID / 端口 / 健康检查信息

> 启动脚本涉及浏览器渲染、终端日志、Docker 中文显示时，**必须同时加载** `shell-编码与执行踩坑.md` 的「中文显示与编码规范（强制）」。

### 3.2 数据恢复脚本

例如：

- `scripts/test-auto/restore-db.ps1`
- `scripts/test-auto/restore-db.sh`
- `scripts/test-auto/restore-db.sql`

职责：

- 读取备份文件
- 恢复到测试库
- 输出恢复日志

> 命名之外的全部编码约束（禁止 PowerShell 文本管道导入 SQL、3 种推荐做法、恢复后中文校验、4 条禁止行为）见 `shell-编码与执行踩坑.md`，**写恢复脚本前必须加载该分片**。

### 3.3 恢复后校验脚本

例如：

- `scripts/test-auto/check-db-after-restore.sql`

职责：

- 校验测试账号是否存在
- 校验关键角色是否存在
- 校验关键业务基线数据是否存在
- 输出 PASS / FAIL、成功数 / 失败数

### 3.4 自动化测试执行脚本

例如：

- `scripts/test-auto/run-uat-auto.ps1`
- `scripts/test-auto/run-uat-auto.sh`

职责：

- 读取 `05-1`
- 读取账号
- 登录系统
- 按用例顺序执行页面自动化 / 接口自动化
- 为 AI 自动补充的逆向场景生成稳定 `case_id`
- 每条结果立即落盘

### 3.5 测试结果文件

例如：

- `test-output/run-status.json`
- `test-output/checkpoints.json`
- `test-output/case-results/*.json`
- `test-output/screenshots/*`
- `test-output/final-report.md`

要求：

- 每条用例至少生成 1 份结构化结果
- AI 自动补充的逆向场景也必须按普通用例生成结构化结果，并进入统一计数
- 每次截图文件名应包含用例编号与时间戳
- `final-report.md` 必须引用 `run-status.json` 的最终统计值，不得人工目测拼写
