-- ==============================================================
-- 02-db-012：案件中止/终止/恢复 S01 方案① · case_stop_end_apply 表 A 类 6 字段补列
-- 对应文档：案件中止终止恢复管理-开发清单 §4.1 A 类字段结构化
-- 版本：v1.1.0 · 批次 4 S01 方案①
-- 执行原则：IF NOT EXISTS 幂等，防重复执行报错
-- ==============================================================

SET @dbname = DATABASE();
SET @tablename = 'case_stop_end_apply';

-- 1) applyResult：申请最终结果 1通过 2驳回 3撤销
SET @colname = 'applyResult';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_stop_end_apply` ADD COLUMN `applyResult` TINYINT DEFAULT NULL COMMENT ''申请最终结果 1通过 2驳回 3撤销（空=审批进行中）'' AFTER `approveRemark`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) rejectNodeLevel：驳回节点层级（status=驳回时必填，如 1=组长关驳回 2=主任关驳回）
SET @colname = 'rejectNodeLevel';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_stop_end_apply` ADD COLUMN `rejectNodeLevel` TINYINT DEFAULT NULL COMMENT ''驳回节点层级（status=2驳回时必填，1=组长关 2=主任关 3=副会长关 4=司法局关）'' AFTER `applyResult`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3) flowRecordId：流程记录表ID，便于事后回溯
SET @colname = 'flowRecordId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_stop_end_apply` ADD COLUMN `flowRecordId` BIGINT DEFAULT NULL COMMENT ''流程记录ID（flow_record.id）'' AFTER `rejectNodeLevel`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 4) currentNodeId：当前流程节点模板ID（flow_node.id）
SET @colname = 'currentNodeId';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_stop_end_apply` ADD COLUMN `currentNodeId` BIGINT DEFAULT NULL COMMENT ''当前审批关 flow_node 模板ID'' AFTER `flowRecordId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 5) currentNodeName：当前审批节点名称冗余，便于列表搜索/展示
SET @colname = 'currentNodeName';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_stop_end_apply` ADD COLUMN `currentNodeName` VARCHAR(100) DEFAULT NULL COMMENT ''当前审批关节点名称（冗余，便于列表展示/搜索）'' AFTER `currentNodeId`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 6) fromStopEndService：提交申请时快照 case_info.stopEnd，审批通过前比对，不相等抛 409 乐观锁
SET @colname = 'fromStopEndService';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND COLUMN_NAME=@colname)=0,
  'ALTER TABLE `case_stop_end_apply` ADD COLUMN `fromStopEndService` TINYINT DEFAULT NULL COMMENT ''校验锁：发起时快照原 stopEnd；审批通过前若与当前 stopEnd 不恒等则抛 409'' AFTER `currentNodeName`',
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==============================================================
-- 组合索引：审批状态+案件+类型复合索引（列表页/工作台待办高频查询场景）
-- ==============================================================

SET @indexname = 'idx_stopend_status_caseid_actiontype';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_stop_end_apply` (`status`, `caseId`, `actionType`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_stopend_applyResult';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_stop_end_apply` (`applyResult`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @indexname = 'idx_stopend_fromStopEndService';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=@dbname AND TABLE_NAME=@tablename AND INDEX_NAME=@indexname)=0,
  CONCAT('CREATE INDEX ', @indexname, ' ON `case_stop_end_apply` (`fromStopEndService`)'),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 存量审批完成的申请行：若老数据 applyResult 为空，按 status 回填（1审批中=null/2通过=1/3驳回=2）
UPDATE `case_stop_end_apply`
SET `applyResult` = CASE WHEN `status`=2 THEN 1 WHEN `status`=3 THEN 2 ELSE NULL END
WHERE `applyResult` IS NULL;
