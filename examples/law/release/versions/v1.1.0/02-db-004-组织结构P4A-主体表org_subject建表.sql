-- ==============================================================
-- 02-db-004：组织结构改造 P4-A 段 · 主体表 org_subject 建表
-- 对应文档：组织结构改造-开发清单 §5.1 · 主体
-- 版本：v1.1.0 · P4-A 双写对账期
-- 约束：tenantId 当前统一=1；单主体阶段只允许存在 1 条启用状态主体
-- ==============================================================

CREATE TABLE IF NOT EXISTS `org_subject` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT '租户ID（单主体阶段强制=1）',
  `name` VARCHAR(100) NOT NULL COMMENT '主体名称',
  `code` VARCHAR(50) DEFAULT NULL COMMENT '主体编码（唯一）',
  `type` VARCHAR(50) NOT NULL DEFAULT 'association' COMMENT '主体类型 justice_city/justice_district/association/other',
  `parentSubjectId` BIGINT DEFAULT NULL COMMENT '上级主体ID（org_subject.id）',
  `orderNum` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态 0禁用 1启用',
  `createTime` DATETIME DEFAULT NULL COMMENT '创建时间',
  `createUser` BIGINT DEFAULT NULL COMMENT '创建人',
  `updateTime` DATETIME DEFAULT NULL COMMENT '更新时间',
  `updateUser` BIGINT DEFAULT NULL COMMENT '更新人',
  PRIMARY KEY (`id`),
  KEY `idx_org_subject_tenantId` (`tenantId`),
  UNIQUE KEY `uk_org_subject_tenantId_code` (`tenantId`, `code`),
  KEY `idx_org_subject_parentSubjectId` (`parentSubjectId`),
  KEY `idx_org_subject_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组织结构·主体表（P4-A 段核心真源1/4）';

-- P4-A 初始化主体数据：仅当表为空时插入（id=1，单主体默认值；P4-A 阶段所有 subjectId=1 来源此）
-- 兼容说明：若目标库已存在由实体自动建出的 org_subject 旧结构，则 createTime/updateTime 可能为 NOT NULL；
--           这里显式补写时间字段，兼容 DATETIME / VARCHAR 两种历史列类型，避免 1364 报错。
INSERT INTO `org_subject` (`id`, `tenantId`, `name`, `code`, `type`, `parentSubjectId`, `orderNum`, `status`, `createTime`, `updateTime`)
SELECT 1, 1, '律协', 'LAW_ASSOC_001', 'association', NULL, 0, 1, DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s'), DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s')
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `org_subject`);
