-- ============================================================
-- 02-db-001 批次1合规整改 · 数据库结构与索引变更脚本
-- 版本号：v1.0.0
-- 适用范围：MySQL / SQLite / PostgreSQL（MySQL方言为主，兼容层按需适配）
-- 执行时机：发布步骤 4.2（应用部署之前必须先执行）
-- 幂等说明：本版已补 existence 判断；字段 / 索引已存在时自动跳过，支持重复执行
-- 执行后校验：见本脚本末尾"-- 执行后校验段"
-- ============================================================

SET @dbname = DATABASE();
SET @preparedStatement = 'SELECT 1';

-- ------------------------------------------------------------
-- 一、client_token 表补两个合规强要求字段（对应最小合规I01-补03）
-- ------------------------------------------------------------
-- 注销精确时间（主动注销时写入，区分注销和被踢/过期场景）
SET @preparedStatement = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'client_token' AND COLUMN_NAME = 'logoutTime') = 0,
    CONCAT(
      'ALTER TABLE `client_token` ',
      'ADD COLUMN `logoutTime` DATETIME NULL COMMENT ''主动注销时间（精确到秒，主动注销时赋值，SF/T 0022 会话注销合规要求）'' ',
      'AFTER `invalidReason`'
    ),
    'SELECT 1'
  )
);
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 登录设备指纹（前端传入 UUID / canvas / UA 哈希，用于 40104 他处登录踢下线判定，对应 401细分5类）
SET @preparedStatement = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'client_token' AND COLUMN_NAME = 'deviceFingerprint') = 0,
    CONCAT(
      'ALTER TABLE `client_token` ',
      'ADD COLUMN `deviceFingerprint` VARCHAR(128) NULL COMMENT ''登录设备指纹（UUID/UA哈希/canvas指纹等，用于 40104 TOKEN_DEVICE_MISMATCH 判定）'' ',
      'AFTER `logoutTime`'
    ),
    'SELECT 1'
  )
);
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 设备指纹索引（同账号+同指纹会话查询优化，40104 踢下线时批量查）
SET @preparedStatement = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'client_token' AND INDEX_NAME = 'idx_client_token_user_device') = 0,
    'CREATE INDEX `idx_client_token_user_device` ON `client_token` (`userId`, `deviceFingerprint`, `status`)',
    'SELECT 1'
  )
);
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;


-- ------------------------------------------------------------
-- 二、case_discipline_result 表补批次1新字段（对应最小合规I05双写与兼容策略 + D04回填幂等 + 乐观锁）
-- ------------------------------------------------------------
-- 回填批次标识（D01-修02 / A01-补03：用于精确回滚，只删除脚本写入且未人工修改的行）
SET @preparedStatement = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'case_discipline_result' AND COLUMN_NAME = 'backfillBatch') = 0,
    CONCAT(
      'ALTER TABLE `case_discipline_result` ',
      'ADD COLUMN `backfillBatch` VARCHAR(64) NULL COMMENT ''历史数据回填批次标识，如 v1.0.0-D04；回填脚本写入，人工修改留空'' ',
      'AFTER `caseId`'
    ),
    'SELECT 1'
  )
);
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 回填批次索引（精确回滚 DELETE ... WHERE backfillBatch = ? 命中）
SET @preparedStatement = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'case_discipline_result' AND INDEX_NAME = 'idx_cdr_backfill_batch') = 0,
    'CREATE INDEX `idx_cdr_backfill_batch` ON `case_discipline_result` (`backfillBatch`)',
    'SELECT 1'
  )
);
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 注意：乐观锁 version 字段需由 TypeORM @VersionColumn 首次 INSERT 时 NULL→0 自动赋初值，SQL 不写默认值
SET @preparedStatement = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'case_discipline_result' AND COLUMN_NAME = 'version') = 0,
    CONCAT(
      'ALTER TABLE `case_discipline_result` ',
      'ADD COLUMN `version` INT NULL COMMENT ''乐观锁版本号（0/1/2…，40901 OPTIMISTIC_LOCK_CONFLICT 判定依据）'' ',
      'AFTER `partyDisciplineReviewOpinion`'
    ),
    'SELECT 1'
  )
);
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;


-- ------------------------------------------------------------
-- 三、执行后校验（发布步骤 4.2 跑完本脚本后必须执行，任一 >0 即 FAIL 禁止继续上线）
-- ------------------------------------------------------------
-- 3.1 client_token 新字段是否成功加列
SELECT COUNT(*) AS c1_add_column
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME = 'client_token'
   AND COLUMN_NAME IN ('logoutTime', 'deviceFingerprint');
-- 预期：c1_add_column = 2

-- 3.2 case_discipline_result 新字段是否成功加列
SELECT COUNT(*) AS c2_add_column
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME = 'case_discipline_result'
   AND COLUMN_NAME IN ('backfillBatch', 'version');
-- 预期：c2_add_column = 2

-- 3.3 索引是否存在（backfillBatch + client_token(userId,deviceFingerprint) 两个新索引）
SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, ':', INDEX_NAME)) AS c3_index_count
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = DATABASE()
   AND (
         (TABLE_NAME = 'case_discipline_result' AND INDEX_NAME = 'idx_cdr_backfill_batch')
         OR
         (TABLE_NAME = 'client_token'          AND INDEX_NAME = 'idx_client_token_user_device')
       );
-- 预期：c3_index_count = 2
