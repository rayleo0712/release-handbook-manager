# AGENTS

本仓库是一个独立维护的 Skill 仓库，核心对象为：

- `release-handbook-manager`

聊天简称统一为：

- `rhm`

## 仓库定位

- 本仓库用于沉淀和维护 `release-handbook-manager` 的 Skill 定义、模板、说明文档与 GitHub 对外资料。
- 本仓库不是具体业务项目仓库，不承载业务代码。
- 本仓库的目标是为 AI 编码协同场景提供一套可复用的版本发布治理 Skill。

## 适用前提

- 本 Skill 以“AI 深度参与开发过程”为主要适用前提。
- 最适合 AI 持续参与需求分析、代码实现、改动整理和发布收口的协同开发场景。
- 如果项目基本不用 AI 开发，或只在临近发版时少量使用 AI，不适合使用本 Skill。

## 首读顺序

新接手本仓库时，优先按以下顺序理解仓库内容：

1. `README.md`
2. `skills/release-handbook-manager/SKILL.md`
3. `docs/20260715-设计说明.md`
4. `docs/20260715-快速开始.md`
5. `templates/`

## 真源文件

以下内容属于本仓库的核心真源：

- `skills/release-handbook-manager/SKILL.md`
- `README.md`
- `README.en.md`
- `templates/`
- `docs/`

其中：

- `SKILL.md` 是 Skill 行为约束真源。
- `README.md` 是默认对外展示首页真源。
- `README.en.md` 是英文入口页真源。
- `templates/` 是可复用模板真源。
- `docs/` 是设计说明、快速开始、使用示例等文档真源。

## 核心边界

- 不得把本 Skill 描述为“自动完整识别全部功能变化、所需 SQL、脚本与发布步骤”的全自动工具。
- 必须明确说明：本 Skill 当前不具备独立的版本差异自动分析引擎。
- 必须明确说明：本 Skill 不会凭空知道未留痕的功能变化、数据库变更、配置变化或人工操作项。
- 对外介绍时，应始终强调本 Skill 更适合 AI 深度参与开发的团队。

## 目录说明

- `assets/`：仓库封面图等静态资源
- `.github/`：Issue、PR 等 GitHub 协作配置
- `docs/`：设计说明、快速开始、使用示例、导航文档
- `templates/`：规则模板与发布模板
- `examples/`：最小示例目录
- `skills/`：可分发的 Skill 文件

## 维护约定

- 修改 `skills/release-handbook-manager/SKILL.md` 时，应同步检查 `README.md`、`README.en.md`、`docs/` 中的能力描述是否仍然一致。
- 修改 Skill 的适用边界、能力边界、目录结构、模板命名规则时，应同步更新 `templates/` 和相关文档。
- 修改中文首页的重要定位表述时，应同步检查 `README.en.md` 中的英文口径是否一致。
- 对外文案优先准确，不得夸大自动化能力。

## 发布前自检建议

在将本仓库发布到 GitHub 或创建新版本前，建议至少检查：

1. `README.md` 与 `README.en.md` 是否一致反映当前定位
2. `SKILL.md` 是否仍是最终真源版本
3. `templates/` 与 `examples/` 是否完整
4. `rhm` 别名说明是否仍保留
5. “仅适合 AI 深度参与开发”这一前提是否仍在显著位置保留
