# 首次初始化流程（release 治理落地）

> 来源：SKILL.md 原 §五（首次初始化时必须创建的内容）+ §七/§7.1（初始化阶段动作）
> 加载时机：「初始化发布治理」「创建 release 目录」「新项目接入 rhm」

---

## 五、首次初始化时必须创建的内容

当项目尚未具备这套机制时，本 Skill 应优先初始化以下内容。

### 5.1 版本配置文件

路径：

```text
release/version.json
```

推荐模板：

```json
{
  "version": "v1.0.0",
  "previousVersion": "",
  "releaseDate": "",
  "status": "developing",
  "owner": "",
  "description": "",
  "releaseGate": {
    "checklist04AllPassed": false,
    "uat051Conclusion": "pending",
    "phase3SignOff": {
      "dev": false,
      "test": false,
      "ops": false
    },
    "materialsSha256": ""
  }
}
```

字段说明：

- `version`：当前版本号
- `previousVersion`：上一版本号
- `releaseDate`：正式发布日期，未发布可为空
- `status`：固定为 `developing` / `released`；**AI 不得自动修改此字段，必须严格遵守 §8.5 门禁门槛**
- `owner`：当前版本负责人（仅 owner 本人有权限发人工指令触发 status → released）
- `description`：当前版本一句话说明
- `releaseGate`：**版本门禁字段（顶层对象，AI 不得自动置为通过）**，四个子字段含义见 §8.5：
  - `releaseGate.checklist04AllPassed`：`04-发布检查清单.md` 全部 Checklist 项是否已人工核验通过（布尔值 true/false）
  - `releaseGate.uat051Conclusion`：`05-1` UAT 验收结论，枚举值：`pending`（待验收）/ `passed`（全部通过）/ `partial`（部分通过）/ `failed`（不通过）
  - `releaseGate.phase3SignOff`：签字门禁对象；其下各布尔子字段由项目按实际签字步骤定义（如 `dev/test/ops` 或 `p4aToP4bSigned/p4bToP4cSigned/finalPhysicalDropSigned`），**仅当所有子字段均为 `true` 时才视为通过**
  - `releaseGate.materialsSha256`：核心发布材料校验值；用于校验 `01/04/05/05-1/06` 等关键材料是否与待发布版本一致，默认空字符串，未人工回填前不得视为通过

### 5.2 项目内规则文件

应在项目规则目录中创建一份“版本发布与更新手册规则”文件，用于长期约束项目协作。

推荐位置：

```text
.trae/rules/YYYYMMDD-08-协作-版本发布与更新手册规则.md
```

规则文件应至少覆盖以下内容：

- 版本号唯一真源规则
- 版本材料目录规则
- 更新手册唯一真源规则
- 强制登记范围规则
- 必须脚本化规则
- 允许人工操作规则
- 发布执行规则
- 更新日志沉淀规则
- 发布材料完整性规则
- 维护责任规则

### 5.3 当前版本目录

应根据 `release/version.json` 中的版本号创建当前版本目录：

```text
release/versions/{版本号}/
```

### 5.4 当前版本模板文件清单（必须同时生成 05/05-1 双轨模板）

应在当前版本目录下**强制同时补齐以下 5 个模板文件**（其中 05/05-1 必须成对生成，缺一不可）：

- `01-更新手册.md`
- `04-发布检查清单.md`
- `05-发布后验证记录.md`
- `05-1-功能验收用例(非技术版).md`
- `06-版本更新日志.md`

版本目录建立后**必须同步就位**的执行器（固定名，每版本一个）：

- `run-release.ps1`：批量执行器，**只复制/下载不逐行生成**，获取三级方式见 `runner-批量执行器.md` §2；就位后把带实际参数的调用命令写入 `04 §8 命令区`

必要时根据当前版本需求创建（归并优先 §4.3、命名与顺序 §4.4、单一通道 §4.5）：

- `02-db-001-xxx.sql`
- `03-config-001-xxx.sql`
- 版本目录只放生产发布必执行脚本：测试/造数/基线恢复脚本归 rta 的 `scripts/test-auto/`，备份等运维动作登记人工操作；每个脚本必须带尾部校验区

**初始化阶段强制约束（关于 05-1）：**

- `05-1` 模板中 §八「验收汇总表」的 P0/P1/P2 计数行（含合计数字）**必须全部留空，不得预填任何数字**；数字回填操作必须在验收启动前，按 §6.3.1(f) 约定的两条 PowerShell 命令人工执行回填


---

## 七、执行工作流

启用本 Skill 后，应按以下顺序工作。

### 7.1 初始化阶段

1. 检查项目是否已存在 `release/version.json`
2. 检查项目是否已存在版本发布相关规则文件
3. 检查当前版本目录是否存在
4. 若缺失，则按以下约束初始化：
   - 规则文件、版本目录结构、模板文件可直接初始化创建
   - 版本目录创建后立即按 `runner-批量执行器.md` §2 复制 `run-release.ps1`（只复制不读取，禁止逐行生成）
   - `release/version.json` 的 `version` 字段：如有人工明确给出版本号则直接写入；否则**必须**写入占位值（如 `vX.Y.Z` 或留空字符串），并明确提示人工维护版本号后才能继续后续操作
   - 初始化时版本目录名称：如版本号为占位值，则先不创建具体版本号子目录，待人工确认版本号后再创建；或创建临时占位目录名（如 `vX.Y.Z/`）并明确提示人工重命名

