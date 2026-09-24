---
name: "release-handbook-manager"
description: "Use when initializing release governance (release/version.json), registering changes during development, writing or ordering release SQL scripts (02-db/03-config), preparing checklists, UAT cases or release notes, or inspecting pre-release readiness. Alias: rhm."
---
# 版本发布手册管理

建立并维护项目内可复用的版本发布治理机制。**细则全在 `references/`，按文末索引表加载，严禁全读一遍。**

## 适用前提·别名·启用场景

- 适用前提：AI 深度参与开发；不用 AI 的项目不适用，且不得宣称能自动识别全部功能变化、SQL 与发布步骤
- 别名：`rhm` = `release-handbook-manager`，提到 `rhm` 即按本 Skill 处理
- 启用场景：初始化发布治理 / 补齐发布材料 / 开发中登记变更 / 整理脚本与人工操作 / 发布前巡检 / 生成清单·验证·日志

## 一、核心目标

机制落地六项：`version.json` 为版本号唯一真源；每版本唯一更新手册为发布内容真源；可数据库执行的变更必须脚本化；不可脚本化的登记为人工步骤；发布按手册执行、不靠口头记录；更新日志从当前版本手册提炼。
**边界**：不具备「版本差异自动分析引擎」，不会凭空知道未留痕的变化。

## 二、版本号规则

- 真源：只以 `release/version.json` 为准，禁止以 Git 提交/分支/Tag 名作依据；格式 `v主版本.次版本.修订号`；新迭代周期前先维护，材料归属该版本号
- 红线摘要见 §十，全文（§2.4/§8.4/§8.4.1/§8.5 含 releaseGate）→ `redlines-一票否决红线汇总.md`（简称 `redlines`），版本号/目录/门禁写操作前**强制前置加载**

## 三、标准目录结构

```
release/version.json
release/versions/{版本号}/
  01-更新手册.md  02-db-NNN-*.sql  03-config-NNN-*.sql  04-发布检查清单.md
  05-发布后验证记录.md  05-1-功能验收用例(非技术版).md  06-版本更新日志.md
  run-release.ps1（批量执行器，固定名，只复制不生成）；run-report.* 为其产物
  archive/05-验证记录-第N轮.md
```

- **发布执行文件（01–06）单层平铺；历史归档统一放 `archive/` 子目录，发布执行时不得读取 `archive/`**
- `release/versions/**` 全部材料**单行 ≤200 字符**、表格逐行展开，禁止多条记录压一行，超标即不合规必须重写
- 7 类发布材料（01/02/03/04/05/05-1/06）+ 1 个固定名执行器 `run-release.ps1`（每版本一个，只复制不生成，见 runner 分片）；**05 与 05-1 双轨配套缺一不可**；真源职责见 `templates-*`、`scripts-sql-规范.md`
- **命令唯一落点 = `04 §8 命令区`**：启动/恢复/四种场景/runner 调用与区间补跑/临时命令都写此处；01/05/05-1/06 只写指向；版本目录唯一允许的 PS1 是 `run-release.ps1`，其余临时文件/PS 片段一律禁止

## 四、脚本化 vs 人工边界

- 可数据库执行的变更（结构、数据修复、权限/菜单/角色/字典配置等）**必须脚本化**，不得降级为人工操作
- **归并优先（§4.3）**：新增 02/03 前先扫同版本已有脚本，同功能单元（同表组/同菜单子树/同字典域）且可同批回滚的必须追加片段，不得一条变更建一个文件；02 与 03 不互并，跨版本复制仍是红线
- **文件名即执行序（§4.4）**：NNN 三位定宽、同前缀唯一，排序即先后；跨文件依赖写 `-- @depends`，违例预检硬拦不执行
- **单一通道（§4.5）**：版本目录只放生产必执行脚本——测试/造数归 rta `scripts/test-auto/`，备份等运维登记人工操作，禁止 skip；每个 SQL 必须有头尾校验、结果只认 PASS/FAIL（无校验区/`@test-only` 预检硬拦，解析不出按 FAIL），不靠 `Query OK`/肉眼翻日志
- 允许人工操作以 `scripts-sql-规范.md` §4.2 的 8 类清单为**唯一真源**；命名/头尾/多片段校验/临时表模板均见同文件

## 七、执行工作流

- **1 初始化** → `init-初始化流程.md`：建 version.json（含 releaseGate）→ 项目规则 → 版本目录（含 `run-release.ps1`，按 runner 分片只复制不生成）→ 7 类文件骨架
- **2 维护登记** → `workflow-维护与登记.md`：变更登记到 01 §3.7 台账 → 补 02/03 脚本与校验区 → 同步 04/05-1/06；切版本走 `switch-版本切换子流程.md`
- **3 发布前巡检** → `inspect-发布前巡检.md`：按 11 项核验完整性·门禁·签字·校验区·双轨，缺项打回

## 上下文读取纪律（硬红线）

1. **禁止整文件读写**：`versions/**` 下 >30 KB 文件必须 Grep 定位 + `Read(offset, limit)` 精读，禁止全量 `Read`
2. **大文件禁整体覆盖**：>50 KB 文档禁止 `Write` 重写，必须定点 SearchReplace
3. **搜索必须限定目录**：`SearchCodebase` / `Grep` 必须带 `target_directories` 或 `glob`，禁止全仓裸搜
4. **references 按需加载**：只允许按下方索引表加载对应分片，禁止「保险起见全读一遍」
5. **发布执行阶段不得读取 `archive/`**
6. **资产只复制不读取**：`assets/`（如 `run-release.ps1`）只复制/下载落盘，禁止读入上下文或逐行重写

## references 索引表（按需加载）

| 用户场景 / 触发条件 | 必须加载的 reference | 禁止加载 |
|---|---|---|
| 「初始化发布治理」「创建 release 目录」 | `init-初始化流程.md` + 全部 `templates-*` 分片 + `scripts-sql-规范.md` + `runner-批量执行器.md` + `redlines` | — |
| 日常开发登记一条变更 | **只读** `templates-01-更新手册.md` §附A 变更台账规范 | 其余全部 |
| 补写/校对 05-1 验收用例 | `templates-05-1-功能验收用例.md` | 01/04/06 |
| 写 02/03 SQL、补校验、判断归并/命名依赖/单一通道 | `scripts-sql-规范.md`（§4.3 归并 / §4.4 顺序 / §4.5 单一通道） | 模板类 |
| 生成/复制 `run-release.ps1`、批量执行、`-ListOnly` 顺序预检或区间补跑 | `runner-批量执行器.md` | — |
| 「切换版本」「改 version.json」「新建版本目录」 | `switch-版本切换子流程.md` + `runner-批量执行器.md` + `redlines` | 模板类 |
| 「准备发版」「rhm 巡检」「材料齐不齐」 | `inspect-发布前巡检.md` + `templates-04-检查清单.md` + `templates-05-1-功能验收用例.md` + `templates-06-更新日志.md` | init |
| 写/校对 06 更新日志 | `templates-06-更新日志.md` | 01/04/05 |
| 发布后验证记录归档、05 瘦身 | `templates-05-验证记录.md` | — |
| 触发自动化测试、与 rta 联动 | `templates-自动化测试前置条件.md`（+ 启用 `release-test-auto` skill） | — |
| 判断该初始化/维护/巡检 | `workflow-维护与登记.md` | — |
| 任何涉及版本号、版本目录、发布门禁的写操作 | `redlines`（**强制前置**） | — |

## 九、输出要求

使用本 Skill 时，输出应满足以下要求：

- 说明当前处理的版本号
- 说明本次属于初始化、维护还是巡检
- 区分必须脚本化事项与允许人工操作事项
- 列出新增或补齐的文件
- 列出仍需人工确认或补充的信息

## 十、重要限制

- 不得用 Git 信息替代版本配置文件中的版本号
- 不得把可通过数据库完成的事项降级为人工操作
- 不得只生成脚本而不维护更新手册
- 不得只维护文档而不补齐必要脚本
- 除 `archive/` 外，不得在版本目录下继续扩展子目录
- 不得保留模糊、无法执行/验证的表述
- **（红线·版本号 4 条，原文 `redlines` §8.4）**：无人工指令不得改/升 `version`；初始化无号用占位并提示；需变号只提示等指令
- **（红线·目录 5 条，原文 `redlines` §8.4.1）**：四段判断（分支 A/B/C/D）完成前禁止写文件；命中 B 强制走 switch 子流程；严禁跨版本混写；02/03 独立编号、严禁跨版本复制（同版本归并 §4.3、顺序 §4.4 不受此限）；switch 后必须反馈目录名/文件清单/台账候选
