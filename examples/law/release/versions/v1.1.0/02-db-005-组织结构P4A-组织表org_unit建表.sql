-- ==============================================================
-- 02-db-005：组织结构改造 P4-A 段 · 组织表 org_unit 建表
-- 对应文档：组织结构改造-开发清单 §5.2 + O01-修03
-- 版本：v1.1.0 · P4-A 双写对账期
-- 核心替代：统一替代旧 base_sys_department + 旧 case_team
-- 8 层封顶 & case_team 必须挂 department 下：Service 层拦截，不建 CHECK 约束（MySQL 低版本兼容）
-- ==============================================================

CREATE TABLE IF NOT EXISTS `org_unit` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID（策略A：旧部门/办案组ID 直接复用，002 SQL 脚本迁移时关闭自增直接插 ID）',
  `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT '租户ID（单主体阶段强制=1）',
  `subjectId` BIGINT NOT NULL DEFAULT 1 COMMENT '所属主体ID（org_subject.id）',
  `name` VARCHAR(100) NOT NULL COMMENT '组织名称',
  `type` VARCHAR(50) NOT NULL DEFAULT 'department' COMMENT '组织类型 department/office/case_team/project_team',
  `parentId` BIGINT DEFAULT NULL COMMENT '上级组织ID（org_unit.id，根节点=NULL）',
  `orderNum` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态 0禁用 1启用',
  `remark` VARCHAR(500) DEFAULT NULL COMMENT '备注',
  `createTime` DATETIME DEFAULT NULL COMMENT '创建时间',
  `createUser` BIGINT DEFAULT NULL COMMENT '创建人',
  `updateTime` DATETIME DEFAULT NULL COMMENT '更新时间',
  `updateUser` BIGINT DEFAULT NULL COMMENT '更新人',
  PRIMARY KEY (`id`),
  KEY `idx_org_unit_tenantId` (`tenantId`),
  KEY `idx_org_unit_subjectId` (`subjectId`),
  KEY `idx_org_unit_parentId` (`parentId`),
  KEY `idx_org_unit_type` (`type`),
  KEY `idx_org_unit_status` (`status`),
  KEY `idx_org_unit_subjectId_parentId_type` (`subjectId`, `parentId`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组织结构·组织表（P4-A 段核心真源2/4，统一替代旧部门+办案组）';
