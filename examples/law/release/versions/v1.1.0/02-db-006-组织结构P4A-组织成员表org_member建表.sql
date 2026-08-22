-- ==============================================================
-- 02-db-006：组织结构改造 P4-A 段 · 组织成员表 org_member 建表
-- 对应文档：组织结构改造-开发清单 §5.3 + O01-修01 isPrimary 原子化
-- 版本：v1.1.0 · P4-A 双写对账期
-- 核心替代：统一替代 user.departmentId 单归属 + 旧 case_team.leadId / case_team.userIds
-- ==============================================================

CREATE TABLE IF NOT EXISTS `org_member` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT '租户ID（单主体阶段强制=1）',
  `subjectId` BIGINT NOT NULL DEFAULT 1 COMMENT '所属主体ID（org_subject.id）',
  `orgId` BIGINT NOT NULL COMMENT '组织ID（org_unit.id）',
  `userId` BIGINT NOT NULL COMMENT '用户ID（base_sys_user.id）',
  `memberType` VARCHAR(50) NOT NULL DEFAULT 'member' COMMENT '成员类型 leader/vice_leader/member',
  `isPrimary` TINYINT NOT NULL DEFAULT 0 COMMENT '是否主归属 0否 1是（同主体同用户恒=1 条，O01-修01 原子SQL维护）',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态 0禁用 1启用',
  `remark` VARCHAR(500) DEFAULT NULL COMMENT '备注',
  `createTime` DATETIME DEFAULT NULL COMMENT '创建时间',
  `createUser` BIGINT DEFAULT NULL COMMENT '创建人',
  `updateTime` DATETIME DEFAULT NULL COMMENT '更新时间',
  `updateUser` BIGINT DEFAULT NULL COMMENT '更新人',
  PRIMARY KEY (`id`),
  KEY `idx_org_member_tenantId` (`tenantId`),
  KEY `idx_org_member_subjectId` (`subjectId`),
  KEY `idx_org_member_orgId` (`orgId`),
  KEY `idx_org_member_userId` (`userId`),
  KEY `idx_org_member_memberType` (`memberType`),
  KEY `idx_org_member_isPrimary` (`isPrimary`),
  -- O01-修01 组合唯一：同一组织下同一用户不得存在 2 条成员记录（成员类型变更走 UPDATE，禁止多插）
  UNIQUE KEY `uk_org_member_tenantId_orgId_userId` (`tenantId`, `orgId`, `userId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组织结构·组织成员表（P4-A 段核心真源3/4，统一替代旧用户单归属+办案组组长成员）';
