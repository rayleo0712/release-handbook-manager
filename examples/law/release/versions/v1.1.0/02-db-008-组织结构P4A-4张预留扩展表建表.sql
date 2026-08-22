-- ==============================================================
-- 02-db-008：组织结构改造 P4-A 段 · 4 张预留扩展表建表
-- 对应文档：组织结构改造-开发清单 §5.5/5.6/5.7/5.8
-- 版本：v1.1.0 · P4-A 双写对账期
-- P4-A 约定：4 张表当前 0 写入，仅建表供后续独立版本（跨主体协同/查重/转接）逐行开启
--   5.5 org_subject_collaboration：主体间协同互通能力矩阵
--   5.6 org_observe_scope：上级主体对下级主体只读督导/统计观察范围
--   5.7 case_shared_index：跨主体案件指纹主索引（同案合并查重核心）
--   5.8 case_shared_relation：跨主体案件关系（来源/转接/协同）
-- ==============================================================

-- 5.5 主体协同
CREATE TABLE IF NOT EXISTS `org_subject_collaboration` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT '租户ID',
  `fromSubjectId` BIGINT NOT NULL COMMENT '发起主体ID（org_subject.id）',
  `toSubjectId` BIGINT NOT NULL COMMENT '目标主体ID（org_subject.id）',
  `allowDuplicateCheck` TINYINT NOT NULL DEFAULT 0 COMMENT '是否允许查重 0否 1是',
  `allowCaseTransfer` TINYINT NOT NULL DEFAULT 0 COMMENT '是否允许案件转接 0否 1是',
  `allowCaseReadSummary` TINYINT NOT NULL DEFAULT 0 COMMENT '是否允许查看案件摘要 0否 1是',
  `allowCaseReadDetail` TINYINT NOT NULL DEFAULT 0 COMMENT '是否允许查看案件详情 0否 1是',
  `allowCoHandling` TINYINT NOT NULL DEFAULT 0 COMMENT '是否允许协同办理 0否 1是',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态 0禁用 1启用',
  `remark` VARCHAR(500) DEFAULT NULL,
  `createTime` DATETIME DEFAULT NULL,
  `createUser` BIGINT DEFAULT NULL,
  `updateTime` DATETIME DEFAULT NULL,
  `updateUser` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_osc_tenantId` (`tenantId`),
  KEY `idx_osc_fromSubjectId` (`fromSubjectId`),
  KEY `idx_osc_toSubjectId` (`toSubjectId`),
  UNIQUE KEY `uk_osc_fromTo` (`tenantId`, `fromSubjectId`, `toSubjectId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组织结构·主体协同互通配置（P4-A 预留表）';

-- 5.6 观察授权范围
CREATE TABLE IF NOT EXISTS `org_observe_scope` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `tenantId` BIGINT NOT NULL DEFAULT 1,
  `observerSubjectId` BIGINT NOT NULL COMMENT '观察主体ID（上级单位，如市局）',
  `targetSubjectId` BIGINT NOT NULL COMMENT '被观察主体ID（下级单位，如律协）',
  `scopeType` VARCHAR(50) NOT NULL DEFAULT 'stats_only' COMMENT '观察范围类型 all/stats_only/summary_only/custom',
  `canViewStats` TINYINT NOT NULL DEFAULT 1,
  `canViewCaseSummary` TINYINT NOT NULL DEFAULT 0,
  `canViewCaseDetail` TINYINT NOT NULL DEFAULT 0,
  `status` TINYINT NOT NULL DEFAULT 1,
  `remark` VARCHAR(500) DEFAULT NULL,
  `createTime` DATETIME DEFAULT NULL,
  `createUser` BIGINT DEFAULT NULL,
  `updateTime` DATETIME DEFAULT NULL,
  `updateUser` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_oos_tenantId` (`tenantId`),
  KEY `idx_oos_observerSubjectId` (`observerSubjectId`),
  KEY `idx_oos_targetSubjectId` (`targetSubjectId`),
  UNIQUE KEY `uk_oos_observerTarget` (`tenantId`, `observerSubjectId`, `targetSubjectId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组织结构·观察授权范围（P4-A 预留表，上级只读督导/统计）';

-- 5.7 跨主体案件主索引（指纹查重）
CREATE TABLE IF NOT EXISTS `case_shared_index` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `tenantId` BIGINT NOT NULL DEFAULT 1,
  `fingerprint` VARCHAR(200) NOT NULL COMMENT '同案合并查重指纹（指纹规则独立文档）',
  `sourceSubjectId` BIGINT NOT NULL,
  `currentOwnerSubjectId` BIGINT NOT NULL,
  `businessType` TINYINT NOT NULL COMMENT '业务类型 1投诉 2案件',
  `bizKey` VARCHAR(100) NOT NULL COMMENT '业务唯一键（如 case_info.caseNo）',
  `status` TINYINT NOT NULL DEFAULT 1,
  `remark` VARCHAR(500) DEFAULT NULL,
  `createTime` DATETIME DEFAULT NULL,
  `createUser` BIGINT DEFAULT NULL,
  `updateTime` DATETIME DEFAULT NULL,
  `updateUser` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_csi_tenantId` (`tenantId`),
  KEY `idx_csi_fingerprint` (`fingerprint`),
  KEY `idx_csi_currentOwnerSubjectId` (`currentOwnerSubjectId`),
  UNIQUE KEY `uk_csi_bizKey` (`tenantId`, `bizKey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='跨主体案件主索引（P4-A 预留表，同案查重/转接联动核心键）';

-- 5.8 跨主体案件关系
CREATE TABLE IF NOT EXISTS `case_shared_relation` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `tenantId` BIGINT NOT NULL DEFAULT 1,
  `sharedCaseId` BIGINT NOT NULL COMMENT '跨主体主索引ID（case_shared_index.id）',
  `subjectId` BIGINT NOT NULL COMMENT '本主体ID（org_subject.id）',
  `businessType` TINYINT NOT NULL COMMENT '业务类型 1投诉 2案件',
  `businessId` BIGINT NOT NULL COMMENT '本地业务ID（case_info.id 或 case_complaint.id）',
  `relationType` VARCHAR(50) DEFAULT NULL COMMENT '关系类型 source/transfer/collaboration',
  `status` TINYINT NOT NULL DEFAULT 1,
  `remark` VARCHAR(500) DEFAULT NULL,
  `createTime` DATETIME DEFAULT NULL,
  `createUser` BIGINT DEFAULT NULL,
  `updateTime` DATETIME DEFAULT NULL,
  `updateUser` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_csr_tenantId` (`tenantId`),
  KEY `idx_csr_sharedCaseId` (`sharedCaseId`),
  KEY `idx_csr_subjectId` (`subjectId`),
  KEY `idx_csr_businessType_businessId` (`businessType`, `businessId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='跨主体案件关系（P4-A 预留表，来源/转接/协同关系展开）';
