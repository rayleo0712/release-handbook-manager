# release-handbook-manager

![release-handbook-manager 中文封面](./assets/cover-zh.svg)

[中文](./README.md) | [English](./README.en.md)

## 中文简介

`release-handbook-manager` 是一个面向 AI 编码协作场景的发布治理 Skill。

它的目标，是解决 AI 协同开发过程中，每次都要额外花精力整理版本发布资料、发布步骤和功能说明的问题。

> 重点说明：
> 本 Skill 以“AI 深度参与开发过程”为主要适用前提。
> 只有在 AI 持续参与需求分析、代码实现、改动整理和发布收口时，才能更稳定地沉淀变更记录，并辅助生成 SQL、脚本、发布步骤和版本更新日志。
> 如果项目基本不用 AI 开发，或只在临近发版时少量使用 AI，不适合使用本 Skill。

它会把这些最容易散落在聊天记录、临时文档、人工记忆里的事项，统一收口到一套可执行流程中，包括：

- 版本号真源
- 更新手册真源
- SQL / 配置脚本产物
- 人工操作步骤
- 发布检查清单
- 发布后验证记录
- 版本更新日志

聊天简称：

- `rhm`

## English Overview

`release-handbook-manager` is a reusable release-governance Skill for AI-assisted software delivery.

It is designed to reduce the repeated effort teams spend organizing release materials, release steps, and change summaries during AI-assisted development.

> Important:
> This Skill is primarily designed for projects where AI is deeply involved throughout development.
> It works best when AI continuously participates in requirement analysis, implementation, change tracking, and release preparation.
> If a team barely uses AI during development and only brings it in near release time, this Skill is not a good fit.

It helps teams turn release work from scattered notes and ad-hoc steps into a repeatable workflow built around:

- one version source of truth
- one executable release handbook
- required SQL artifacts for scriptable changes
- explicit manual-operation records for non-scriptable changes
- reusable release checks, verification records, and release notes

Chat alias:

- `rhm`

## 一眼看懂 / At a Glance

- **用途 / Purpose**：标准化发布准备、发布执行与发布留痕  
  Standardize release preparation, release execution, and release records.
- **版本真源 / Version source**：`release/version.json`
- **版本格式 / Version format**：`v主版本.次版本.修订号` / `vMajor.Minor.Patch`
- **默认模型 / Default model**：全项目单一总版本号  
  One top-level version per project, even in multi-module repositories.
- **文档现状 / Documentation status**：当前为中文主站 + 英文补充入口  
  The repository currently uses Chinese as the primary documentation language, with English support for the public entry page.

## 为什么需要它 / Why This Exists

很多项目在开发阶段能把代码改完，但一到准备发布时，团队常常还要额外投入精力去整理：

- 当前版本到底改了什么
- 哪些数据库和配置操作必须执行
- 发布时到底要按什么顺序操作
- 最终要怎么写版本更新说明

而这些内容如果不在开发过程中持续沉淀，通常就会在发布前集中暴露问题：

- 版本号没有统一真源
- 数据库脚本散落在聊天记录、临时文件或个人机器里
- 最大化避免人工操作页面更新数据，例如菜单、权限、角色授权等配置需要发版后再人工繁琐操作后台更新
- 更新手册写得像说明文，而不是可执行清单
- 最终发布说明要靠人工回忆拼凑

Many teams can finish coding, but before release they still spend extra effort trying to reconstruct:

- what changed in the current version
- which database and config operations must be executed
- what the release sequence should be
- how the final release notes should be written

If those materials are not accumulated during development, the release phase usually breaks down in familiar ways:

- no single source of truth for the version number
- database scripts are scattered across chats, temp files, or personal machines
- teams still rely on manual and repetitive admin-page operations for menu, permission, and role-authorization data updates after release
- release handbooks read like notes instead of execution guides
- final release notes are reconstructed from memory

## 应用场景 / What It Helps You Do

这个 Skill 最适合解决下面这些实际问题：

1. **减少整理发布资料的重复劳动**  
   在 AI 协同开发中，不需要每次临近发布时再临时整理更新资料、执行步骤和功能说明。

2. **自动记录开发过程中的变更记录**
   在 AI 持续参与开发过程的前提下，与当前版本相关的变更会持续沉淀到更新手册和版本材料中，而不是等到发版前再回忆。

3. **自动生成发布所需的 SQL 和其他脚本**
   在 AI 已掌握较完整上下文时，对数据库结构、历史数据、菜单权限、角色权限等可脚本化内容，优先生成可执行 SQL 或脚本产物。

4. **自动生成发布时的更新步骤**
   在已有上下文和材料较完整时，将发布前检查、脚本执行、人工操作、发布后验证、回滚说明整理成明确的执行顺序。

5. **自动生成版本更新日志**
   基于开发过程中的沉淀材料，辅助提炼最终发布说明和版本更新日志。

This Skill is primarily designed to help with five practical release problems:

1. **Reduce the repeated work of organizing release materials**  
   Teams do not need to manually reconstruct release notes, release steps, and functional summaries every time a version is about to ship.

2. **Automatically record change history during development**  
   Version-related changes are accumulated during development instead of being reconstructed right before release.

3. **Automatically generate SQL and other release scripts**  
   Scriptable release work such as schema changes, data repair, menu setup, and permission setup is turned into executable artifacts.

4. **Automatically generate release execution steps**  
   The release sequence is organized into a clear order that covers checks, scripts, manual steps, verification, and rollback notes.

5. **Automatically generate version update logs**  
   Final release notes can be extracted directly from the materials accumulated during development.

## 核心能力 / Core Capabilities

### 1. 初始化项目发布治理 / Initialize release governance

- 创建 `release/version.json`
- 创建项目级版本发布规则文件
- 创建 `release/versions/{版本号}/`
- 初始化更新手册、发布检查清单、发布后验证记录、版本更新日志

- create `release/version.json`
- create a project-level release governance rule file
- create `release/versions/{version}/`
- initialize the handbook, release checklist, post-release verification record, and release notes

### 2. 维护当前版本发布材料 / Maintain current release materials

- 读取当前版本号
- 识别本次改动是否涉及数据库结构、数据迁移、菜单权限、角色权限、字典参数、流程模板、配置文件、生产环境配置等
- 对必须脚本化的内容生成或补齐 `02-db-xxx.sql`、`03-config-xxx.sql`
- 把变更登记回 `01-更新手册.md`

- read the current version number
- identify whether the change affects schema, data migration, menus, permissions, role grants, dictionaries, params, process templates, config files, or production settings
- generate or complete required `02-db-xxx.sql` and `03-config-xxx.sql` files
- write the changes back into `01-更新手册.md`

### 3. 发布前巡检 / Pre-release inspection

- 检查版本号和目录是否一致
- 检查是否缺少 SQL 脚本
- 检查人工操作是否具备明确入口、步骤、目标结果、校验方式
- 检查发布后验证与回滚材料是否完整

- verify the version number and directory match
- check whether SQL artifacts are missing
- verify manual steps include clear entry points, order, target results, and validation methods
- verify rollback and post-release validation materials are complete

## 工作流 / Workflow

### 1. 初始化 / Initialize

适用于项目还没有发布治理结构时。  
Use it when a project does not yet have release governance in place.

会创建：

- `release/version.json`
- 项目级规则文件
- 当前版本目录
- 发布模板文件组

It creates:

- `release/version.json`
- a project-level rule file
- the current version directory
- the base release template set

### 2. 维护 / Maintain

适用于开发过程中持续补录发布影响。  
Use it while development is in progress.

会补录：

- 当前版本变更摘要
- 必须脚本化事项
- 允许人工操作事项
- 发布检查与验证材料
- 更新日志来源材料

It helps record:

- what changed in the current version
- which items must be delivered as SQL
- which items must remain manual and how to execute them
- what should appear in release checks and post-release verification
- what should appear in the final release notes

### 3. 巡检 / Inspect

适用于发版前核对完整性。  
Use it before shipping.

会检查：

- 版本号与目录是否一致
- 必要脚本是否齐全
- 人工操作是否具体可执行
- 验证材料与回滚方案是否完整

It checks whether:

- the version source and version directory match
- required SQL artifacts are present
- manual steps are specific enough to execute safely
- verification and rollback materials are complete

## 设计原则 / Design Principles

### 版本号不依赖 Git / Version numbers do not depend on Git

- 当前版本号以 `release/version.json` 为唯一真源
- 格式统一为：`v主版本.次版本.修订号`

- `release/version.json` is the only source of truth for the current version
- the version format is fixed to `vMajor.Minor.Patch`

### 能脚本化的必须脚本化 / Everything scriptable must be scripted

以下内容必须产出 SQL，而不是只写文字说明：

- 表结构变更
- 字段、主键、外键、索引、约束调整
- 存储过程、触发器变更
- 历史数据修复、回填、迁移
- 菜单、权限、角色权限等数据库驱动配置

The following items must be delivered as SQL, not vague notes:

- schema changes
- column, primary key, foreign key, index, and constraint changes
- stored procedure and trigger changes
- historical data fixes, backfills, and migrations
- menu, permission, and role-permission changes backed by the database

### 人工操作也必须明确 / Manual operations must still be explicit

以下场景允许保留为人工操作：

- 修改已有配置文件
- 生产环境配置
- 确实无法脚本化的事项

但即使是人工操作，也必须记录：

- 操作入口
- 操作顺序
- 操作内容
- 目标结果
- 校验方式

These scenarios may remain manual:

- modifying existing config files
- production-environment configuration
- cases that truly cannot be scripted

Even then, the handbook must still record:

- entry point
- execution order
- operation content
- expected result
- validation method

## 默认发布模型 / Default Release Model

默认采用**全项目单一总版本号**。

即使仓库包含多个目录，例如：

- `backend`
- `frontend`
- `client`
- `uniapp`

也仍然建议：

- 只维护一个 `release/version.json`
- 每个版本只有一份发布手册
- 各模块参与情况记录在手册中，而不是每个模块单独维护主版本文件

This Skill assumes a **single project-level release version** by default.

For repositories that contain multiple directories such as:

- `backend`
- `frontend`
- `client`
- `uniapp`

the recommended approach is still:

- one top-level version source in `release/version.json`
- one release handbook per release version
- module involvement recorded inside the handbook, rather than introducing separate primary version files for each module

## 推荐目录结构 / Recommended Structure

```text
release/
  version.json
  versions/
    v1.0.0/
      01-更新手册.md
      02-db-001-数据库结构变更.sql
      02-db-002-历史数据修复.sql
      03-config-001-菜单权限配置.sql
      03-config-002-角色权限配置.sql
      04-发布检查清单.md
      05-发布后验证记录.md
      06-版本更新日志.md
```

说明 / Notes:

- `02`、`03` 不再拆子目录  
  `02` and `03` are not nested into extra folders.
- 所有文件统一单层平铺  
  All files stay in one flat level.
- 文件名前缀直接体现类型和执行顺序  
  File prefixes directly encode category and execution order.

## 适用场景 / Typical Use Cases

- 在 AI 协同开发中，希望减少每次整理发布资料、步骤和功能说明的重复劳动  
  Reduce repeated release-preparation work in AI-assisted development.
- 希望在开发过程中自动沉淀当前版本的变更记录  
  Automatically accumulate version change records during development.
- 希望自动生成数据库 SQL、配置脚本和其他发布脚本  
  Automatically generate database SQL, config scripts, and other release artifacts.
- 希望在发版时直接得到明确的更新步骤  
  Produce clear release execution steps for shipping.
- 希望最终版本更新日志可以直接从开发材料中生成  
  Generate final release notes directly from development-time materials.

## 快速开始 / Quick Start

### 1. 将 Skill 放入项目 / Put the Skill into your project

把 `skills/release-handbook-manager/SKILL.md` 放到你的 Skill 目录中，例如：

```text
.trae/skills/release-handbook-manager/SKILL.md
```

### 2. 在聊天中触发初始化 / Initialize release governance in chat

```text
请用 rhm 初始化当前项目的版本发布治理，版本号先设为 v1.0.0
```

```text
Please use rhm to initialize release governance for the current project, and set the version to v1.0.0
```

### 3. 在开发过程中持续维护 / Maintain release materials during development

```text
用 rhm 维护当前版本变更
```

```text
用 rhm 为这次需求补发布材料
```

```text
Use rhm to maintain the current version changes
```

```text
Use rhm to generate release materials for this task
```

### 4. 在发版前做巡检 / Inspect before release

```text
用 rhm 检查 v1.0.0 是否可以发版
```

```text
Use rhm to check whether v1.0.0 is ready for release
```

## 示例提示词 / Example Prompts

```text
用 rhm 维护 v1.1.0，这次涉及 backend 和 frontend，包含 1 个表结构变更、2 条菜单权限 SQL，以及 1 项生产环境人工配置
```

```text
Use rhm to maintain the current version changes. This task includes one schema change, two permission SQL scripts, and one production-only manual config step.
```

## 仓库目录说明 / Repository Layout

```text
release-handbook-manager/
  README.md
  README.en.md
  LICENSE
  assets/
    cover.svg
  docs/
    20260715-快速开始.md
    20260715-使用示例.md
    20260715-设计说明.md
  templates/
    project-rules/
      20260715-08-协作-版本发布与更新手册规则.md
    basic-release/
      release/
        version.json
        versions/
          v1.0.0/
            01-更新手册.md
            04-发布检查清单.md
            05-发布后验证记录.md
            06-版本更新日志.md
  skills/
    release-handbook-manager/
      SKILL.md
  examples/
    basic-release/
      release/
        version.json
        versions/
          v1.0.0/
            01-更新手册.md
            04-发布检查清单.md
            05-发布后验证记录.md
            06-版本更新日志.md
```

## 文档与模板导航 / Docs and Templates

### 文档 / Docs

- [文档导航 / Documentation Index](./docs/20260715-%E6%96%87%E6%A1%A3%E5%AF%BC%E8%88%AA.md)
- [快速开始](./docs/20260715-%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B.md)
- [GitHub 发布准备](./docs/20260715-GitHub%E5%8F%91%E5%B8%83%E5%87%86%E5%A4%87.md)
- [使用示例](./docs/20260715-%E4%BD%BF%E7%94%A8%E7%A4%BA%E4%BE%8B.md)
- [设计说明](./docs/20260715-%E8%AE%BE%E8%AE%A1%E8%AF%B4%E6%98%8E.md)

### 模板 / Templates

- [规则模板](./templates/project-rules/20260715-08-%E5%8D%8F%E4%BD%9C-%E7%89%88%E6%9C%AC%E5%8F%91%E5%B8%83%E4%B8%8E%E6%9B%B4%E6%96%B0%E6%89%8B%E5%86%8C%E8%A7%84%E5%88%99.md)
- [基础发布模板目录](./templates/basic-release/release/)
- [可分发 Skill](./skills/release-handbook-manager/SKILL.md)

## 社区协作 / Community

- [贡献指南 / Contributing](./CONTRIBUTING.md)
- [安全策略 / Security Policy](./SECURITY.md)
- [协作准则 / Code of Conduct](./CODE_OF_CONDUCT.md)
- [PR 模板 / PR Template](./.github/PULL_REQUEST_TEMPLATE.md)

## 适合谁使用 / Who This Is For

如果你符合下面这些情况，这个仓库就比较适合你：

- 正在真实项目里使用 AI 编码助手
- AI 在需求、编码、改动整理、发布准备中有持续参与
- 希望发布准备可以复用，而不是每次临时补
- 希望把数据库与权限配置也纳入正式发布交付物
- 希望最终版本日志能直接从开发期材料中提炼

This repository is a good fit if you:

- use AI coding assistants in real projects
- have AI continuously involved across requirements, coding, change tracking, and release preparation
- want release preparation to be reproducible instead of informal
- need database and permission changes to be treated as first-class release artifacts
- want release notes to come from development-time materials rather than end-of-cycle reconstruction

## 能力边界 / Capability Boundary

- 本 Skill 不会凭空知道未留痕的变更信息。
  The Skill cannot infer undocumented release changes out of thin air.
- 如果项目基本不用 AI 开发，或只在临近发版时少量使用 AI，则不适合使用本 Skill。
  If a project barely uses AI during development or only brings AI in shortly before release, this Skill is not a good fit.
- 如果 AI 未深度参与开发过程，它无法稳定自动判断全部功能变化、所需 SQL、脚本和更新步骤。
  If AI was not deeply involved during development, it cannot reliably determine all feature changes, required SQL, scripts, or release steps automatically.

## 当前状态 / Current Status

- 已完成基础能力设计 / Core workflow is defined
- 已支持初始化、维护、巡检三段式工作流 / Initialization, maintenance, and inspection modes are supported
- 已支持 `rhm` 聊天别名 / The `rhm` chat alias is supported
- 已沉淀单层平铺的发布材料结构 / The flat release-material structure is documented

## 作者与维护信息 / Author and Maintainer

- 作者 / Author：Ray
- 公司 / Company：东创华珞（武汉）国际科创有限公司
- 官网 / Website：<https://www.dcipo.com>

## 后续可扩展方向 / Future Extensions

- 多模块版本附属信息记录 / Module-level auxiliary version records
- 版本模板可配置化 / Configurable templates
- 多数据库方言脚本模板 / Multi-database SQL templates
- 自动生成分层发布说明 / Layered release-note generation
- 与 CI/CD 或发布审批流程联动 / CI/CD or approval-flow integration

## 许可证 / License

本仓库当前使用 [MIT License](./LICENSE)。  
This repository is released under the [MIT License](./LICENSE).
