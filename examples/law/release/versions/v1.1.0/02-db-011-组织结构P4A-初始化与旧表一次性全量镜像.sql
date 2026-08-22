-- ==============================================================
-- 02-db-011：组织结构改造 P4-A 段 · 初始化单主体数据 + 旧6表到新8表一次性全量镜像
-- 对应文档：组织结构改造-开发清单 §7.1 P4-A 迁移（双写对账期前的存量镜像）+ O01-补02（ID 交集空校验）
-- 版本：v1.1.0 · P4-A 双写对账期
-- 核心：
--   - O01-补02：迁移前强校验「org_unit.id ∪ case_team.id」「org_unit.id ∪ base_sys_department.id」交集为空，冲突>0 先解再迁移
--   - 策略 A（O01-修02 推荐）：主键 ID 直映射，8 张下游表零级联更新
--   - 只在新表 0 行数据时执行（幂等），若已存在则跳过避免覆盖日常双写
-- ==============================================================

SET @dbname = DATABASE();

-- ==============================================================
-- STEP 0：O01-补02 策略 A ID 冲突校验 + 自动清洗（必须先过）
-- ==============================================================
SELECT
  -- 冲突计数 0 = OK；> 0 = 先解再迁移（策略 A 禁止任何 ID 重复）
  (SELECT COUNT(DISTINCT d.id) FROM `base_sys_department` d INNER JOIN `case_team` ct ON d.id = ct.id) AS idConflictDeptTeamCount,
  (SELECT COUNT(1) FROM `org_unit`)                            AS currentOrgUnitRowCount
INTO @idConflictDeptTeamCount, @currentOrgUnitRowCount;

-- 仅当 org_unit 为空表（=第一次迁移）且真实库存在冲突时，自动执行清洗：
-- 保留部门 ID 不变，只重编号冲突办案组 ID，并同步修正 case_info.groupId / groupOrgId 显式引用。
CREATE TABLE IF NOT EXISTS `zz_v110_p4a_case_team_id_conflict_map` (
  `oldId` BIGINT NOT NULL COMMENT '冲突办案组旧 ID（与部门 ID 重号）',
  `newId` BIGINT NOT NULL COMMENT '清洗后的新办案组 ID（保证当前库内唯一）',
  `departmentName` VARCHAR(100) DEFAULT NULL COMMENT '重号部门名称',
  `caseTeamName` VARCHAR(100) DEFAULT NULL COMMENT '重号办案组名称',
  `conflictReason` VARCHAR(255) DEFAULT NULL COMMENT '冲突原因说明',
  `createTime` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '映射创建时间',
  PRIMARY KEY (`oldId`),
  UNIQUE KEY `uk_v110_case_team_conflict_newId` (`newId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='v1.1.0 P4-A 策略 A 冲突办案组 ID 清洗映射表';

CREATE TABLE IF NOT EXISTS `bak_v110_p4a_conflict_case_team` LIKE `case_team`;
INSERT INTO `bak_v110_p4a_conflict_case_team`
SELECT ct.*
FROM `case_team` ct
INNER JOIN `base_sys_department` d ON d.`id` = ct.`id`
LEFT JOIN `bak_v110_p4a_conflict_case_team` bak ON bak.`id` = ct.`id`
WHERE @currentOrgUnitRowCount = 0
  AND bak.`id` IS NULL;

CREATE TABLE IF NOT EXISTS `bak_v110_p4a_conflict_case_info` LIKE `case_info`;
INSERT INTO `bak_v110_p4a_conflict_case_info`
SELECT ci.*
FROM `case_info` ci
INNER JOIN `case_team` ct ON ct.`id` = ci.`groupId`
INNER JOIN `base_sys_department` d ON d.`id` = ct.`id`
LEFT JOIN `bak_v110_p4a_conflict_case_info` bak ON bak.`id` = ci.`id`
WHERE @currentOrgUnitRowCount = 0
  AND bak.`id` IS NULL;

SET @maxUsedId = GREATEST(
  IFNULL((SELECT MAX(`id`) FROM `base_sys_department`), 0),
  IFNULL((SELECT MAX(`id`) FROM `case_team`), 0),
  IFNULL((SELECT MAX(`id`) FROM `org_unit`), 0)
);
SET @seq = 0;

INSERT INTO `zz_v110_p4a_case_team_id_conflict_map` (
  `oldId`,
  `newId`,
  `departmentName`,
  `caseTeamName`,
  `conflictReason`
)
SELECT
  c.`oldId`,
  @maxUsedId + (@seq := @seq + 1) AS `newId`,
  c.`departmentName`,
  c.`caseTeamName`,
  '策略A 前置清洗：保留部门 ID，不变更部门及角色授权，只重编号冲突办案组 ID'
FROM (
  SELECT
    d.`id` AS `oldId`,
    d.`name` AS `departmentName`,
    ct.`name` AS `caseTeamName`
  FROM `base_sys_department` d
  INNER JOIN `case_team` ct ON d.`id` = ct.`id`
  LEFT JOIN `zz_v110_p4a_case_team_id_conflict_map` m ON m.`oldId` = d.`id`
  WHERE @currentOrgUnitRowCount = 0
    AND m.`oldId` IS NULL
  ORDER BY d.`id`
) c;

UPDATE `case_info` ci
INNER JOIN `zz_v110_p4a_case_team_id_conflict_map` m ON ci.`groupId` = m.`oldId`
SET ci.`groupId` = m.`newId`
WHERE @currentOrgUnitRowCount = 0;

SET @preparedStatement = (
  SELECT IF(
    @currentOrgUnitRowCount = 0
    AND (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'case_info' AND COLUMN_NAME = 'groupOrgId') > 0,
    'UPDATE `case_info` ci INNER JOIN `zz_v110_p4a_case_team_id_conflict_map` m ON ci.`groupOrgId` = m.`oldId` SET ci.`groupOrgId` = m.`newId`',
    'SELECT ''[skip] case_info.groupOrgId 列不存在或当前非首次迁移，跳过兼容更新'' AS info'
  )
);
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE `case_team` ct
INNER JOIN `zz_v110_p4a_case_team_id_conflict_map` m ON ct.`id` = m.`oldId`
SET ct.`id` = m.`newId`
WHERE @currentOrgUnitRowCount = 0;

SELECT COUNT(DISTINCT d.id)
FROM `base_sys_department` d
INNER JOIN `case_team` ct ON d.`id` = ct.`id`
INTO @remainingConflictDeptTeamCount;

SET @haltStatement = (SELECT IF(
  @currentOrgUnitRowCount = 0 AND @remainingConflictDeptTeamCount > 0,
  CONCAT('SELECT ''[O01-补02 冲突拦截] 自动清洗后 base_sys_department.id ∩ case_team.id 仍非空，共 ', @remainingConflictDeptTeamCount, ' 条，请人工核查映射表 zz_v110_p4a_case_team_id_conflict_map'' AS error FROM `org_subject` LIMIT 1'),
  CONCAT('SELECT ''[O01-补02] 策略A ID 冲突校验通过（首次迁移已清洗或原本冲突=0）；remainingConflictCount=', @remainingConflictDeptTeamCount, ''' AS info')
));
PREPARE haltOrPass FROM @haltStatement; EXECUTE haltOrPass; DEALLOCATE PREPARE haltOrPass;

-- ==============================================================
-- STEP 1：org_subject 初始化单主体（004 SQL 已做，此处兜底；幂等）
-- 兼容说明：若目标库由实体自动建表提前生成，createTime/updateTime 可能为 NOT NULL；
--           这里显式补写时间字段，兼容 DATETIME / VARCHAR 两种历史列类型。
-- ==============================================================
INSERT INTO `org_subject` (`id`, `tenantId`, `name`, `code`, `type`, `parentSubjectId`, `orderNum`, `status`, `createTime`, `updateTime`)
SELECT 1, 1, '律协', 'LAW_ASSOC_001', 'association', NULL, 0, 1, DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s'), DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s')
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `org_subject` WHERE `id`=1);

SET @defaultSubjectId = 1;

-- ==============================================================
-- STEP 1.5：兼容旧结构新表列差异
-- 说明：
--   当前部分环境可能已被实体自动建出 org_unit/org_member/org_role_scope，
--   其结构仅包含 createTime/updateTime，不含 createUser/updateUser。
--   此处统一探测列是否存在，后续按实际列清单执行 INSERT，避免 Unknown column 中断。
-- ==============================================================
SELECT COUNT(*) INTO @orgUnitHasCreateUser
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = @dbname AND `TABLE_NAME` = 'org_unit' AND `COLUMN_NAME` = 'createUser';

SELECT COUNT(*) INTO @orgUnitHasUpdateUser
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = @dbname AND `TABLE_NAME` = 'org_unit' AND `COLUMN_NAME` = 'updateUser';

SELECT COUNT(*) INTO @orgMemberHasCreateUser
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = @dbname AND `TABLE_NAME` = 'org_member' AND `COLUMN_NAME` = 'createUser';

SELECT COUNT(*) INTO @orgMemberHasUpdateUser
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = @dbname AND `TABLE_NAME` = 'org_member' AND `COLUMN_NAME` = 'updateUser';

SELECT COUNT(*) INTO @orgRoleScopeHasCreateUser
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = @dbname AND `TABLE_NAME` = 'org_role_scope' AND `COLUMN_NAME` = 'createUser';

SELECT COUNT(*) INTO @orgRoleScopeHasUpdateUser
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = @dbname AND `TABLE_NAME` = 'org_role_scope' AND `COLUMN_NAME` = 'updateUser';

-- ==============================================================
-- STEP 2.1：org_unit ← base_sys_department（策略 A，id 直接映射；type=department）
-- 仅当 org_unit.type=department 行为空才执行（幂等）
-- ==============================================================
SET @deptMigratedCount = (SELECT COUNT(1) FROM `org_unit` WHERE `type` = 'department');
SET @deptStatement = (SELECT IF(
  @deptMigratedCount = 0,
  IF(
    @orgUnitHasCreateUser > 0 AND @orgUnitHasUpdateUser > 0,
    -- 新结构：包含 createUser/updateUser
    'INSERT INTO `org_unit` (`id`, `tenantId`, `subjectId`, `name`, `type`, `parentId`, `orderNum`, `status`, `remark`, `createTime`, `createUser`, `updateTime`, `updateUser`)
     SELECT d.`id`, 1, @defaultSubjectId, d.`name`, ''department'', d.`parentId`, IFNULL(d.`orderNum`,0), 1, NULL, COALESCE(d.`createTime`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')), d.`userId`, COALESCE(d.`updateTime`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')), NULL
     FROM `base_sys_department` d
     ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)',
    -- 旧结构：仅包含 createTime/updateTime
    'INSERT INTO `org_unit` (`id`, `tenantId`, `subjectId`, `name`, `type`, `parentId`, `orderNum`, `status`, `remark`, `createTime`, `updateTime`)
     SELECT d.`id`, 1, @defaultSubjectId, d.`name`, ''department'', d.`parentId`, IFNULL(d.`orderNum`,0), 1, NULL, COALESCE(d.`createTime`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')), COALESCE(d.`updateTime`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''))
     FROM `base_sys_department` d
     ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)'
  ),
  'SELECT ''[skip] org_unit(type=department) 已存在数据，跳过存量迁移，等待日常双写保持同步'' AS info'
));
PREPARE stmt FROM @deptStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==============================================================
-- STEP 2.2：org_unit ← case_team（策略 A，id 直接映射；type=case_team）
-- 仅当 org_unit.type=case_team 行为空才执行（幂等）
-- ==============================================================
SET @teamMigratedCount = (SELECT COUNT(1) FROM `org_unit` WHERE `type` = 'case_team');
SET @teamStatement = (SELECT IF(
  @teamMigratedCount = 0,
  IF(
    @orgUnitHasCreateUser > 0 AND @orgUnitHasUpdateUser > 0,
    'INSERT INTO `org_unit` (`id`, `tenantId`, `subjectId`, `name`, `type`, `parentId`, `orderNum`, `status`, `remark`, `createTime`, `createUser`, `updateTime`, `updateUser`)
     SELECT ct.`id`, 1, @defaultSubjectId, ct.`name`, ''case_team'', NULL, 0, ct.`status`, ct.`remark`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL
     FROM `case_team` ct
     ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)',
    'INSERT INTO `org_unit` (`id`, `tenantId`, `subjectId`, `name`, `type`, `parentId`, `orderNum`, `status`, `remark`, `createTime`, `updateTime`)
     SELECT ct.`id`, 1, @defaultSubjectId, ct.`name`, ''case_team'', NULL, 0, ct.`status`, ct.`remark`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')
     FROM `case_team` ct
     ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)'
  ),
  'SELECT ''[skip] org_unit(type=case_team) 已存在数据，跳过存量迁移'' AS info'
));
PREPARE stmt FROM @teamStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==============================================================
-- STEP 3：org_member ← case_team（leadId → leader + userIds → member；P4-A 仅从办案组导出部门成员；部门成员留到 P4-B 从 user.departmentId 回填）
-- 仅当 org_member 行为空才执行（幂等）
-- ==============================================================
SET @memberMigratedCount = (SELECT COUNT(1) FROM `org_member`);
SET @memberStatement = (SELECT IF(
  @memberMigratedCount = 0,
  IF(
    @orgMemberHasCreateUser > 0 AND @orgMemberHasUpdateUser > 0,
    'INSERT INTO `org_member` (`tenantId`, `subjectId`, `orgId`, `userId`, `memberType`, `isPrimary`, `status`, `remark`, `createTime`, `createUser`, `updateTime`, `updateUser`)
     SELECT
       1,
       @defaultSubjectId,
       ct.`id`                                                          AS orgId,
       ct.`leadId`                                                      AS userId,
       ''leader''                                                       AS memberType,
       0                                                                AS isPrimary,
       1,
       NULL,
       DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL
     FROM `case_team` ct
     WHERE ct.`leadId` IS NOT NULL AND ct.`leadId` <> 0
     UNION ALL
     SELECT
       1,
       @defaultSubjectId,
       ct.`id`                        AS orgId,
       CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) AS userId,
       ''member''                     AS memberType,
       0                              AS isPrimary,
       1,
       NULL,
       DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL
     FROM `case_team` ct
     CROSS JOIN JSON_TABLE(IFNULL(ct.`userIds`, JSON_ARRAY()), ''$[*]'' COLUMNS (uid JSON PATH ''$'')) jt
     WHERE JSON_VALID(IFNULL(ct.`userIds`, JSON_ARRAY()))
       AND CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) IS NOT NULL
       AND CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) <> 0
       AND NOT (CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) = ct.`leadId`)  -- leader 不重复写 member
     ON DUPLICATE KEY UPDATE `memberType`=VALUES(`memberType`)',
    'INSERT INTO `org_member` (`tenantId`, `subjectId`, `orgId`, `userId`, `memberType`, `isPrimary`, `status`, `remark`, `createTime`, `updateTime`)
     SELECT
       1,
       @defaultSubjectId,
       ct.`id`                                                          AS orgId,
       ct.`leadId`                                                      AS userId,
       ''leader''                                                       AS memberType,
       0                                                                AS isPrimary,
       1,
       NULL,
       DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')
     FROM `case_team` ct
     WHERE ct.`leadId` IS NOT NULL AND ct.`leadId` <> 0
     UNION ALL
     SELECT
       1,
       @defaultSubjectId,
       ct.`id`                        AS orgId,
       CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) AS userId,
       ''member''                     AS memberType,
       0                              AS isPrimary,
       1,
       NULL,
       DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')
     FROM `case_team` ct
     CROSS JOIN JSON_TABLE(IFNULL(ct.`userIds`, JSON_ARRAY()), ''$[*]'' COLUMNS (uid JSON PATH ''$'')) jt
     WHERE JSON_VALID(IFNULL(ct.`userIds`, JSON_ARRAY()))
       AND CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) IS NOT NULL
       AND CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) <> 0
       AND NOT (CAST(JSON_UNQUOTE(jt.uid) AS SIGNED) = ct.`leadId`)  -- leader 不重复写 member
     ON DUPLICATE KEY UPDATE `memberType`=VALUES(`memberType`)'
  ),
  'SELECT ''[skip] org_member 已存在数据，跳过存量迁移，等待日常双写保持同步'' AS info'
));
PREPARE stmt FROM @memberStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==============================================================
-- STEP 4：O01-修01 主归属一次性补齐（同一用户同一主体随机取 org_id 最小的记 isPrimary=1，其他=0）
--         独立独立运行（不论迁移或日常，幂等）
-- ==============================================================
UPDATE `org_member` om
LEFT JOIN (
  SELECT `subjectId`, `userId`, MIN(`orgId`) AS minOrgId
  FROM `org_member`
  GROUP BY `subjectId`, `userId`
) firstOrg ON om.`subjectId`=firstOrg.`subjectId` AND om.`userId`=firstOrg.`userId`
SET om.`isPrimary` = CASE WHEN om.`orgId` = firstOrg.`minOrgId` THEN 1 ELSE 0 END;

-- ==============================================================
-- STEP 5：org_role_scope ← base_sys_role_department（行式） ∪ role.departmentIdList（JSON）取并集
-- 仅当 org_role_scope 为空才执行（幂等）
-- ==============================================================
SET @scopeMigratedCount = (SELECT COUNT(1) FROM `org_role_scope`);
SET @scopeStatement = (SELECT IF(
  @scopeMigratedCount = 0,
  IF(
    @orgRoleScopeHasCreateUser > 0 AND @orgRoleScopeHasUpdateUser > 0,
    'INSERT INTO `org_role_scope` (`tenantId`, `subjectId`, `roleId`, `orgId`, `createTime`, `createUser`, `updateTime`, `updateUser`)
     SELECT DISTINCT 1, @defaultSubjectId, rd.`roleId`, rd.`departmentId`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL
     FROM `base_sys_role_department` rd
     UNION
     SELECT DISTINCT
       1,
       @defaultSubjectId,
       r.`id`                       AS roleId,
       CAST(JSON_UNQUOTE(jdept.id) AS SIGNED) AS orgId,
       DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), NULL
     FROM `base_sys_role` r
     CROSS JOIN JSON_TABLE(IFNULL(r.`departmentIdList`, JSON_ARRAY()), ''$[*]'' COLUMNS (id JSON PATH ''$'')) jdept
     WHERE JSON_VALID(IFNULL(r.`departmentIdList`, JSON_ARRAY()))
       AND CAST(JSON_UNQUOTE(jdept.id) AS SIGNED) IS NOT NULL
       AND CAST(JSON_UNQUOTE(jdept.id) AS SIGNED) <> 0
     ON DUPLICATE KEY UPDATE `roleId`=VALUES(`roleId`)',
    'INSERT INTO `org_role_scope` (`tenantId`, `subjectId`, `roleId`, `orgId`, `createTime`, `updateTime`)
     SELECT DISTINCT 1, @defaultSubjectId, rd.`roleId`, rd.`departmentId`, DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')
     FROM `base_sys_role_department` rd
     UNION
     SELECT DISTINCT
       1,
       @defaultSubjectId,
       r.`id`                       AS roleId,
       CAST(JSON_UNQUOTE(jdept.id) AS SIGNED) AS orgId,
       DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s''), DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')
     FROM `base_sys_role` r
     CROSS JOIN JSON_TABLE(IFNULL(r.`departmentIdList`, JSON_ARRAY()), ''$[*]'' COLUMNS (id JSON PATH ''$'')) jdept
     WHERE JSON_VALID(IFNULL(r.`departmentIdList`, JSON_ARRAY()))
       AND CAST(JSON_UNQUOTE(jdept.id) AS SIGNED) IS NOT NULL
       AND CAST(JSON_UNQUOTE(jdept.id) AS SIGNED) <> 0
     ON DUPLICATE KEY UPDATE `roleId`=VALUES(`roleId`)'
  ),
  'SELECT ''[skip] org_role_scope 已存在数据，跳过存量迁移'' AS info'
));
PREPARE stmt FROM @scopeStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==============================================================
-- STEP 6：O01-补06 denorm 快照列（case_info）存量首次回填
--   回填规则：
--     denormGroupDepartmentId   = 若 groupId 对应旧 case_team.parentId（null）→ 则沿 case_team 无法推断，保持 null（由 P4-B 人工挂接办案组后再补）
--     denormHandlerDepartmentId = currentHandler 的主归属组织向上第一个 department 节点；P4-A 直接取 user.departmentId（保持兼容）
-- ==============================================================
UPDATE `case_info` ci
SET ci.`denormHandlerDepartmentId` = (
  SELECT u.`departmentId` FROM `base_sys_user` u WHERE u.`id` = ci.`currentHandler` LIMIT 1
)
WHERE ci.`denormHandlerDepartmentId` IS NULL AND ci.`currentHandler` IS NOT NULL;

-- 011 SQL 结束：P4-A 全量迁移已完成；后续走日常双写 + 每日 5 维度对账脚本保持一致
