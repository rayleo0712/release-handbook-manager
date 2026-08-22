-- ==============================================================
-- 02-db-010：组织结构改造 P4-A 段 · 组合唯一索引与约束 SQL
-- 对应文档：组织结构改造-开发清单 §5.9 索引与唯一性（004~007 建表 SQL 已包含最核心 uk；本节为存量场景补充 + 建议索引）
-- 版本：v1.1.0 · P4-A 双写对账期
-- 说明：若 004~007 已通过 TypeORM synchronize 或手动建表创建成功，此处采用 IF 不存在才创建，幂等不报错
-- ==============================================================

SET @dbname = DATABASE();

-- 1) org_subject：主体编码 tenantId+code 组合唯一（001 SQL 已建 UK，此为兜底补建）
SET @tablename = 'org_subject';
SET @indexname = 'uk_org_subject_tenantId_code';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE UNIQUE INDEX ', @indexname, ' ON `org_subject` (`tenantId`, `code`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) org_member：同组织下同用户唯一（O01-修01 强约束）
SET @tablename = 'org_member';
SET @indexname = 'uk_org_member_tenantId_orgId_userId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE UNIQUE INDEX ', @indexname, ' ON `org_member` (`tenantId`, `orgId`, `userId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3) org_member：确保 O01-修01 计数——同一主体同用户 isPrimary=1 的数量，若>1 则先保留 id 最小的那条=1，其余置 0
--    （此条用于从脏数据或空表导入后做一次存量修复；日常变更由 Service 层原子 SQL 维护）
UPDATE `org_member` om0
INNER JOIN (
  SELECT `subjectId`, `userId`, MIN(`id`) AS keepId
  FROM `org_member`
  WHERE `isPrimary` = 1
  GROUP BY `subjectId`, `userId`
  HAVING COUNT(1) > 1
) dup ON om0.`subjectId`=dup.`subjectId` AND om0.`userId`=dup.`userId`
SET om0.`isPrimary` = CASE WHEN om0.`id`=dup.`keepId` THEN 1 ELSE 0 END;

-- 4) org_role_scope：同主体同角色同组织唯一（O01-修04 数据权限组合唯一）
SET @tablename = 'org_role_scope';
SET @indexname = 'uk_org_role_scope_tenantId_roleId_orgId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE UNIQUE INDEX ', @indexname, ' ON `org_role_scope` (`tenantId`, `subjectId`, `roleId`, `orgId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 5) org_unit：建议索引（subjectId+parentId+type 三合一，懒加载拉取一级子节点时性能最佳）
SET @tablename = 'org_unit';
SET @indexname = 'idx_org_unit_subjectId_parentId_type';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `org_unit` (`subjectId`, `parentId`, `type`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 6) org_subject_collaboration：（fromSubjectId, toSubjectId）组合唯一，防镜像重复开通
SET @tablename = 'org_subject_collaboration';
SET @indexname = 'uk_osc_fromTo';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE UNIQUE INDEX ', @indexname, ' ON `org_subject_collaboration` (`tenantId`, `fromSubjectId`, `toSubjectId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 7) org_observe_scope：（observerSubjectId, targetSubjectId）组合唯一
SET @tablename = 'org_observe_scope';
SET @indexname = 'uk_oos_observerTarget';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE UNIQUE INDEX ', @indexname, ' ON `org_observe_scope` (`tenantId`, `observerSubjectId`, `targetSubjectId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 8) case_shared_index：bizKey 业务唯一键组合唯一
SET @tablename = 'case_shared_index';
SET @indexname = 'uk_csi_bizKey';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE UNIQUE INDEX ', @indexname, ' ON `case_shared_index` (`tenantId`, `bizKey`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 9) case_shared_relation：（sharedCaseId, subjectId, businessType, businessId）建议普通索引，供跨主体回溯展开
SET @tablename = 'case_shared_relation';
SET @indexname = 'idx_csr_shared_biz';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_shared_relation` (`sharedCaseId`, `subjectId`, `businessType`, `businessId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;
