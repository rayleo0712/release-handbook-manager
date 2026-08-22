-- ==============================================================
-- 02-db-009：组织结构改造 P4-A 段 · 4 张核心旧表加列与索引
-- 对应文档：组织结构改造-开发清单 §6.2 旧 6 张表过渡期补列方案（本节仅实现 4 张：user / role / case_info / case_complaint）
-- 版本：v1.1.0 · P4-A 双写对账期
-- 执行原则：IF NOT EXISTS 防重复执行；每列 COMMENT 明确用途，便于 P4-C 断写清理时识别
-- ==============================================================

-- 1) base_sys_user：加 tenantId / subjectId / primaryOrgId（§6.2.2）
SET @dbname = DATABASE();
SET @tablename = 'base_sys_user';
SET @colname = 'tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @colname) = 0,
  'ALTER TABLE `base_sys_user` ADD COLUMN `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT ''租户ID（预留多租户）'' AFTER `socketId`',
  'SELECT 1'
));
PREPARE alterIfNotExists FROM @preparedStatement; EXECUTE alterIfNotExists; DEALLOCATE PREPARE alterIfNotExists;

SET @colname = 'subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @colname) = 0,
  'ALTER TABLE `base_sys_user` ADD COLUMN `subjectId` BIGINT DEFAULT NULL COMMENT ''所属主体ID（org_subject.id）'' AFTER `tenantId`',
  'SELECT 1'
));
PREPARE alterIfNotExists FROM @preparedStatement; EXECUTE alterIfNotExists; DEALLOCATE PREPARE alterIfNotExists;

SET @colname = 'primaryOrgId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @colname) = 0,
  'ALTER TABLE `base_sys_user` ADD COLUMN `primaryOrgId` BIGINT DEFAULT NULL COMMENT ''默认主组织ID（org_unit.id，替代旧departmentId）'' AFTER `subjectId`',
  'SELECT 1'
));
PREPARE alterIfNotExists FROM @preparedStatement; EXECUTE alterIfNotExists; DEALLOCATE PREPARE alterIfNotExists;

-- 加索引（索引名若存在不报错，SQL 层 CREATE INDEX 会报错，所以先查 INFORMATION_SCHEMA.STATISTICS）
SET @indexname = 'idx_base_sys_user_tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `base_sys_user` (`tenantId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_base_sys_user_subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `base_sys_user` (`subjectId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_base_sys_user_primaryOrgId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `base_sys_user` (`primaryOrgId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- P4-A 存量 user.subjectId 回填（单主体阶段=1）
UPDATE `base_sys_user` SET `subjectId` = 1 WHERE `subjectId` IS NULL OR `subjectId` = 0;
-- P4-A 存量 user.primaryOrgId 回填（镜像旧 departmentId 列，保持过渡期兼容）
UPDATE `base_sys_user` SET `primaryOrgId` = `departmentId` WHERE `primaryOrgId` IS NULL AND `departmentId` IS NOT NULL;

-- ==============================================================
-- 2) base_sys_role：加 tenantId / subjectId（§6.2.4）
SET @tablename = 'base_sys_role';

SET @colname = 'tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `base_sys_role` ADD COLUMN `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT ''租户ID（预留多租户）'' AFTER `departmentIdList`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @colname = 'subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `base_sys_role` ADD COLUMN `subjectId` BIGINT DEFAULT NULL COMMENT ''所属主体ID（org_subject.id）'' AFTER `tenantId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_base_sys_role_tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `base_sys_role` (`tenantId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_base_sys_role_subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `base_sys_role` (`subjectId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE `base_sys_role` SET `subjectId` = 1 WHERE `subjectId` IS NULL OR `subjectId` = 0;

-- ==============================================================
-- 3) case_info：加 tenantId / subjectId / denormHandlerDepartmentId / denormGroupDepartmentId / groupOrgId（§6.2.6 + O01-补06）
SET @tablename = 'case_info';

SET @colname = 'tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_info` ADD COLUMN `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT ''租户ID（预留多租户）'' AFTER `stopEnd`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @colname = 'subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_info` ADD COLUMN `subjectId` BIGINT DEFAULT NULL COMMENT ''所属主体ID（org_subject.id）'' AFTER `tenantId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @colname = 'denormHandlerDepartmentId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_info` ADD COLUMN `denormHandlerDepartmentId` BIGINT DEFAULT NULL COMMENT ''O01-补06 承办人部门快照ID（denorm防统计口径漂移，org_unit.type=department）'' AFTER `subjectId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @colname = 'denormGroupDepartmentId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_info` ADD COLUMN `denormGroupDepartmentId` BIGINT DEFAULT NULL COMMENT ''O01-补06 办案组部门快照ID（denorm防统计口径漂移）'' AFTER `denormHandlerDepartmentId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @colname = 'groupOrgId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_info` ADD COLUMN `groupOrgId` BIGINT DEFAULT NULL COMMENT ''办案组组织ID（org_unit.type=case_team，原groupId升级过渡期双写groupId）'' AFTER `denormGroupDepartmentId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- case_info 索引
SET @indexname = 'idx_case_info_tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_info` (`tenantId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_case_info_subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_info` (`subjectId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_case_info_denormHandlerDepartmentId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_info` (`denormHandlerDepartmentId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_case_info_denormGroupDepartmentId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_info` (`denormGroupDepartmentId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_case_info_groupOrgId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_info` (`groupOrgId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 存量 case_info 回填
UPDATE `case_info` SET `subjectId` = 1 WHERE `subjectId` IS NULL OR `subjectId` = 0;
-- groupOrgId ← groupId 过渡期双写（P4-A 期保持=groupId，P4-B 期读新表再逐步切到 org_unit.id）
UPDATE `case_info` SET `groupOrgId` = `groupId` WHERE `groupOrgId` IS NULL AND `groupId` IS NOT NULL;

-- ==============================================================
-- 4) case_complaint：加 tenantId / subjectId（§6.2.5）
SET @tablename = 'case_complaint';

SET @colname = 'tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_complaint` ADD COLUMN `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT ''租户ID（预留多租户）'' AFTER `respondentDetails`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @colname = 'subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_complaint` ADD COLUMN `subjectId` BIGINT DEFAULT NULL COMMENT ''所属主体ID（org_subject.id）'' AFTER `tenantId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_case_complaint_tenantId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_complaint` (`tenantId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_case_complaint_subjectId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_complaint` (`subjectId`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE `case_complaint` SET `subjectId` = 1 WHERE `subjectId` IS NULL OR `subjectId` = 0;
