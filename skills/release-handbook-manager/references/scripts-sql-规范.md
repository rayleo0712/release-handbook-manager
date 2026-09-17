# SQL / 配置脚本规范与人工操作边界

> 来源：SKILL.md 原 §四（§4.1 必须脚本化 + §4.2 允许人工操作）
> 加载时机：写 02-db / 03-config 脚本、补执行后校验语句、判断某项是否必须脚本化

---

## 四、必须脚本化与允许人工操作的边界

### 4.1 必须脚本化

凡是本质上可以通过数据库执行完成的变更，必须提供可执行 SQL 脚本，不允许只写文字说明。

以下内容必须脚本化：

- 数据库表结构变更
- 字段新增、修改、删除
- 主键、外键、索引、约束调整
- 存储过程变更
- 触发器变更
- 历史数据修复、回填、迁移
- 菜单配置
- 菜单下权限配置
- 角色权限分配
- 其他可通过数据库增删改查直接完成的系统配置

补充原则：

- 菜单、权限、角色权限等虽然可在页面上人工配置，但其底层本质是数据库操作，因此必须归类为脚本化
- 不允许只写“请去页面手工配置菜单/权限”这类模糊说明
- 每个 `02-db-xxx.sql` / `03-config-xxx.sql` 文件在**文件头部**都必须预留统一固定说明区，至少包含以下 4 段，且顺序不得颠倒：
  - `【脚本用途】`
  - `【执行前置条件】`
  - `【预期结果】`
  - `【执行后快速核对】`
- `【预期结果】` 必须集中写在文件头部固定说明区，明确列出“执行完成后应该看到什么结果”；**禁止**把预期结果零散写在 SQL 中部、尾部或多段注释里，避免执行后人工翻找遗漏
- `【执行后快速核对】` 必须给出最少 1 条可直接复制执行的核对 SQL 或核对方法，方便执行完成后立即比对结果
- 每个 SQL 文件在**文件尾部**还必须追加独立固定区：`-- 【执行后校验SQL】`；该区域必须提供可直接执行的校验 SQL，校验结果应尽量返回明确数值、状态或差异计数，**禁止**只依赖执行日志中的 `Query OK`、影响行数提示或肉眼逐段翻看日志来判断是否成功
- 当脚本内容较多、步骤较多或包含多段 DDL/DML 时，`-- 【执行后校验SQL】` 必须按脚本内逻辑分段编号，例如 `-- 1. 校验字段是否存在`、`-- 2. 校验回填数量是否正确`、`-- 3. 校验脏数据是否清零`，确保执行后可逐项核对结果值
- 校验 SQL 的目标是“让执行人直接看结果值判断是否通过”，因此优先使用 `COUNT(*)`、`SUM(...)`、`CASE WHEN ... THEN 'PASS' ELSE 'FAIL' END`、差异集查询等可判定写法；禁止只写笼统注释而不提供可执行校验语句
- 对于**一个 SQL 文件包含多个执行片段**的场景，必须升级为“**分片段校验 + 汇总结果**”模式：每个片段执行完成后，立即执行该片段对应的校验 SQL，并把校验结果写入统一结果集；文件尾部再统一输出成功计数、失败计数、失败片段明细
- 多片段脚本**不得**只在文件尾部放一个笼统总查询，也不得只统计成功条数而不保留失败明细；至少必须同时输出：
  - 全量片段校验结果明细
  - `success_count`
  - `fail_count`
  - 失败片段清单
- 如数据库支持临时表，**优先**使用临时结果表（例如 `tmp_rhm_check_result`）收集每个片段的校验结果；如不支持临时表，也必须使用等价的可查询结果集方案，保证最终仍能输出“明细 + 汇总 + 失败项”

推荐头部模板：

```sql
/*
【脚本用途】
1. {本脚本解决什么问题}

【执行前置条件】
1. {执行前必须满足的条件}

【预期结果】
1. {执行成功后应看到的结果}
2. {需要重点核对的结果}

【执行后快速核对】
1. {核对SQL或核对步骤}
*/
```

推荐尾部模板：

```sql
-- 【执行后校验SQL】
-- 1. {校验项名称}
SELECT CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = '{表名}'
  AND COLUMN_NAME = '{字段名}';

-- 2. {校验项名称}
SELECT COUNT(*) AS abnormal_count
FROM {表名}
WHERE {应当不存在的数据条件};
```

多片段脚本推荐模板：

```sql
DROP TEMPORARY TABLE IF EXISTS tmp_rhm_check_result;
CREATE TEMPORARY TABLE tmp_rhm_check_result (
    id INT PRIMARY KEY AUTO_INCREMENT,
    check_name VARCHAR(200) NOT NULL,
    expected_desc VARCHAR(500) NOT NULL,
    actual_desc VARCHAR(500) NOT NULL,
    pass_flag TINYINT NOT NULL,
    check_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 片段1：执行 SQL
-- {片段1执行语句}

-- 片段1：执行后校验并写入结果
INSERT INTO tmp_rhm_check_result (check_name, expected_desc, actual_desc, pass_flag)
SELECT
    '片段1-{校验项名称}',
    '{预期结果说明}',
    CONCAT('{实际结果前缀}=', COUNT(*)),
    CASE WHEN {通过条件} THEN 1 ELSE 0 END;

-- 片段2：执行 SQL
-- {片段2执行语句}

-- 片段2：执行后校验并写入结果
INSERT INTO tmp_rhm_check_result (check_name, expected_desc, actual_desc, pass_flag)
SELECT
    '片段2-{校验项名称}',
    '{预期结果说明}',
    CONCAT('{实际结果前缀}=', COUNT(*)),
    CASE WHEN {通过条件} THEN 1 ELSE 0 END;

-- 【执行后校验SQL】
-- 1. 查看全部片段校验结果
SELECT
    id,
    check_name,
    expected_desc,
    actual_desc,
    CASE WHEN pass_flag = 1 THEN 'PASS' ELSE 'FAIL' END AS check_result,
    check_time
FROM tmp_rhm_check_result
ORDER BY id;

-- 2. 查看汇总结果
SELECT
    COUNT(*) AS total_count,
    SUM(CASE WHEN pass_flag = 1 THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN pass_flag = 0 THEN 1 ELSE 0 END) AS fail_count
FROM tmp_rhm_check_result;

-- 3. 仅查看失败片段
SELECT
    id,
    check_name,
    expected_desc,
    actual_desc
FROM tmp_rhm_check_result
WHERE pass_flag = 0
ORDER BY id;
```

### 4.2 允许人工操作（8 类，本节是全仓唯一真源）

仅以下 **8 类**场景允许保留为人工操作步骤，除此之外一律不得归类为人工操作：

1. 修改已有配置文件的内容调整（不含新增配置文件）
2. 生产环境配置类操作
3. 确实无法脚本化的事项
4. 无接口、无数据库入口的人工导入与维护（如后台流程管理、字典管理等只能页面导入的内容）
5. 真实时间观察窗口与核心业务流程人工跑通（必须走日历真实时间，不得用改机器时间等方式模拟）
6. 并发压测（需真实并发环境与真实数据量，无法用 SQL 脚本等价替代）
7. 安全门禁（安全审批、合规审查等由外部关卡或外部人员裁定的事项）
8. 灰度各阶段签字，以及签字前置的灰度开关/代码改动（签字必须人工，未签字不得改动）

与 `01-更新手册.md` §5「必须人工介入的操作点」简表的对应关系（两处口径必须一致）：

- 介入点 ①「数据库脚本执行」= 脚本本体已按 §4.1 脚本化，仅执行动作需人工触发，不属于本节 8 类之外的例外
- 介入点 ②③ → 第 5 类；介入点 ④ → 第 6、7 类；介入点 ⑤ → 第 8 类
- `01 §6.2` 第 4 步「人工流程配置」→ 第 4 类
- 第 1~3 类事项不进入 01 §5 介入点简表，改在 `04-发布检查清单.md` §3 人工操作检查中登记
- 如需增删类别，只能改本节，再由 01 §5 与 04 §3 同步引用，禁止另立清单

凡归类为人工操作的事项，必须明确登记：

- 操作入口
- 操作顺序
- 操作内容
- 目标结果
- 校验方式

禁止使用以下模糊表述：

- “现场处理”
- “按实际情况调整”
- “发布时再看”

