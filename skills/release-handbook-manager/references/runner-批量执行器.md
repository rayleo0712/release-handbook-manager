# run-release.ps1 批量执行器（每版本一个）

> 加载时机：初始化/切版本后生成执行器、要求批量执行 02/03 SQL、补跑区间脚本
> 配套规范：SQL 头尾与多片段写法见 `scripts-sql-规范.md`；调用命令唯一落点 `04 §8`

---

## 1. 定位与放置（固定名，固定位置）

- 唯一合法路径：`release/versions/{版本号}/run-release.ps1`，**每个版本目录一个**，随版本目录走，不跨版本共享
- 职责：按文件名顺序执行**本目录**全部 `02-db-*` / `03-config-*`，脚本间间隔等待，解析尾部校验区 PASS/FAIL，产出 `run-report.json` / `run-report.md` / `run-report.log`
- **单一通道（§4.5）**：runner **没有黑名单/skip 机制**，版本目录只放生产必执行脚本；结果只有 PASS/FAIL，解析不出校验反馈按 FAIL（fail-closed），结束时 FAIL 即 exit 1
- **执行前强制硬预检**（文件名即执行序 §4.4 + 单一通道 §4.5，违例 exit 2、一条 SQL 都不执行）：命名定宽、NNN 唯一、`@depends` 存在且排序位严格更小、每脚本必有校验区、无 `@test-only`、000 占位仅注释
- 它是版本目录下**唯一允许**的 PowerShell 文件；临时命令文件、零散 PS 片段仍一律禁止（见 SKILL.md §三）
- `run-report.*` 是执行器产物，不是临时文件；发布后随版本材料留存即可

## 2. 获取方式（三级，禁止在对话里逐行重写全文）

> 执行器全文约 600 行 / 30 KB+，读进上下文或现场重写都浪费 token。一律「拿文件」，不要「写文件」。

1. **本地资产复制（默认，0 token、离线可用，只复制不读取）**：

```powershell
Copy-Item "{skill安装目录}/assets/run-release.ps1" "release/versions/{版本号}/run-release.ps1"
```

2. **网络下载最新版**（需要新版或本地资产缺失时）：

```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/rayleo0712/release-handbook-manager/main/skills/release-handbook-manager/assets/run-release.ps1" -OutFile "release/versions/{版本号}/run-release.ps1"
```

3. **两者都不可用**：提示用户人工从上面的 URL 下载后放入版本目录，**严禁凭记忆重写全文**
   - 复制/下载后可用 SHA256 与资产文件比对，不一致则提示重新获取，不得在原文件上就地补丁式修改

版本无关设计：执行器自动取**所在目录名**作为版本号，复制后零修改、零占位替换。

编码要求：资产为 **UTF-8 带 BOM**（Windows PowerShell 5.1 在 GBK 代码页解析中文注释所必需，无 BOM 会触发语法误报）；`Copy-Item`/`Invoke-WebRequest` 天然保持原字节，禁止另存为无 BOM 或 GBK；其写出的 `run-report.*` 仍统一为 UTF-8 无 BOM。

## 3. 执行顺序契约与硬预检（规则全文 §4.4/§4.5，此处只列 runner 行为）

- 唯一排序口径：`Sort-Object Name`——先全部 `02-db-NNN-*` 后全部 `03-config-NNN-*`，同前缀按 NNN 升序；NNN 三位定宽、同前缀唯一，简述不参与顺序
- `02-db-000-*` / `03-config-000-*` 是保留占位文件，永不执行；预检要求其**只能含注释**，含任何可执行语句即违例
- 跨文件前置依赖：脚本中 `-- @depends <token>` 机器声明（语法见 §4.4.3），预检逐条验证目标存在且排序位严格更小
- 预检 8 类致命违例（exit 2，不执行任何 SQL）：① 命名不符文法；② NNN 重复；③ 依赖目标不存在；④ 依赖倒序；⑤ 依赖 000 占位；⑥ 可执行脚本缺校验区（无 `check_result`/`fail_count`）；⑦ 含 `-- @test-only`/`-- @env:test`（测试脚本归 `scripts/test-auto/`）；⑧ 000 占位含可执行语句
- 预检通过后打印带 `[下标]` 与依赖边的执行计划；§4.3 归并的多片段脚本共用一个 `tmp_rhm_check_result`，runner 自动累计成功/失败数
- **无 skip 语义**：不再有「EXEC OK, no check block」之类跳过；运行时校验输出解析不出 PASS/FAIL → 判 FAIL（fail-closed）；全部脚本跑完有 FAIL/EXEC_FAIL → exit 1

## 4. 常用参数与登记要求

- 连接参数：`-DbHost -Port -User -Password -Database -IntervalSec -ResetFirst`
- 顺序相关：
  - `-ListOnly`：只做硬预检 + 打印执行计划，**不连库不执行**；发布前巡检/CI 必跑，须 0 违例
  - `-StartIndex -EndIndex`：区间下标（从 0 开始，按执行计划下标）失败补跑；依赖落在区间外时只告警，执行人确认前置已生效
  - `-StopOnError`：任一脚本执行/校验失败立即中止，防止后续脚本踩在失败前置上级联出错；正式发布建议带此参数
- **调用命令本体唯一落点 = `04 §8 命令区`**：初始化/切版本生成执行器后，必须把本版本实际参数的调用命令（含 `-ListOnly`、`-StartIndex/-EndIndex` 补跑、`-StopOnError` 用法）写进 `04 §8`；01/05/05-1/06 只写指向
- 执行结果回填 `05`（技术验证记录），失败项进入发布问题清单

## 5. 生成与巡检时机

- **init**：版本目录建立后立即按 §2 复制一份（`init-初始化流程.md` §5.4）
- **switch §7.2.1 Step 1**：新版本目录创建后立即复制一份；执行器属于版本级文件，**禁止从上一版复制旧副本**，统一从资产/网络获取
- **inspect**：核验文件存在、版本号取自目录名（报告抬头与当前版本一致）；与资产 SHA256 不一致时要求重新获取；**必须实际跑一次 `-ListOnly` 并确认 0 违例**，执行计划与 `01 §4.1/§4.3` 行序逐行一致；版本目录内不得残留黑名单/测试专用/无校验区脚本（§4.5）
