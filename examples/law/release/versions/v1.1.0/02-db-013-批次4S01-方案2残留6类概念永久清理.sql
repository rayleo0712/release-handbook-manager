-- ==============================================================
-- 02-db-013：案件中止/终止/恢复 S01 方案②残留清理脚本
-- 对应文档：案件中止终止恢复管理-开发清单 §6 C 类 6 列概念永久删除 / §9.4 方案②残留清理
-- 版本：v1.1.0 · 批次 4 S01 方案①
-- 说明：本脚本为"防御性清理"——若物理库中存在方案②遗留的以下 6 类列/表/索引，则执行 DROP；
--      若不存在，脚本幂等跳过，不抛错。
-- 删除项（S01-选01 方案①硬要求：全部永久删除，任何命中以上关键字的列/表/SQL/接口都必须先解再上线）：
--   1) newCaseId / sourceCaseId：恢复副本案件关联列（方案①不创建副本，概念永久删除）
--   2) case_relation 表：方案②的案件关联关系表（方案①不使用副本，无此表）
--   3) restoreRemark / relationType / resume_copy 等残留列
-- ==============================================================

SET @dbname = DATABASE();

-- ==============================================================
-- 1) case_stop_end_apply 表：若存在 newCaseId / sourceCaseId / restoreRemark 则 DROP COLUMN
-- ==============================================================
SET @tablename = 'case_stop_end_apply';
SET @dropcols = 'newCaseId,sourceCaseId,restoreRemark,relationType,resume_copy,restoredCaseId,parentCaseId';
DROP PROCEDURE IF EXISTS dropColIfExists;
DELIMITER //
CREATE PROCEDURE dropColIfExists(tbl VARCHAR(200), col VARCHAR(200))
BEGIN
  IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = tbl AND COLUMN_NAME = col) THEN
    SET @s = CONCAT('ALTER TABLE `', tbl, '` DROP COLUMN `', col, '`');
    PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END //
DELIMITER ;

CALL dropColIfExists(@tablename, 'newCaseId');
CALL dropColIfExists(@tablename, 'sourceCaseId');
CALL dropColIfExists(@tablename, 'restoreRemark');
CALL dropColIfExists(@tablename, 'relationType');
CALL dropColIfExists(@tablename, 'resume_copy');
CALL dropColIfExists(@tablename, 'restoredCaseId');
CALL dropColIfExists(@tablename, 'parentCaseId');

-- ==============================================================
-- 2) case_info 表：同理若有方案②残留列，全部 DROP
-- ==============================================================
SET @tablename = 'case_info';
CALL dropColIfExists(@tablename, 'newCaseId');
CALL dropColIfExists(@tablename, 'sourceCaseId');
CALL dropColIfExists(@tablename, 'restoreRemark');
CALL dropColIfExists(@tablename, 'relationType');
CALL dropColIfExists(@tablename, 'resume_copy');
CALL dropColIfExists(@tablename, 'restoredCaseId');
CALL dropColIfExists(@tablename, 'parentCaseId');
CALL dropColIfExists(@tablename, 'stopEndApplyId');

-- ==============================================================
-- 3) case_relation 表（方案②）：若存在则永久 DROP TABLE（方案①不使用副本，无此表）
-- ==============================================================
DROP TABLE IF EXISTS `case_relation`;
DROP TABLE IF EXISTS `case_stop_end_copy`;
DROP TABLE IF EXISTS `case_resume_copy`;
DROP TABLE IF EXISTS `case_stop_end_relation`;

DROP PROCEDURE IF EXISTS dropColIfExists;
-- 02-db-002 结束：物理层面方案② 6 类概念全量清理完成；若后续任何查询再次命中以上关键字，应判定为方案回潮
