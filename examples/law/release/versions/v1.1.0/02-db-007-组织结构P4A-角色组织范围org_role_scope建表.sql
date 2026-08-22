-- ==============================================================
-- 02-db-007：组织结构改造 P4-A 段 · 角色组织范围表 org_role_scope 建表
-- 对应文档：组织结构改造-开发清单 §5.4 + O01-修04
-- 版本：v1.1.0 · P4-A 双写对账期
-- 数据权限唯一真源：统一替代旧 base_sys_role_department 表 + 旧 role.departmentIdList JSON 数组
-- 新缓存键：admin:orgScope:{roleId}（P4-B 段接入 authority 中间件），禁止复用旧键 admin:department:*
-- ==============================================================

CREATE TABLE IF NOT EXISTS `org_role_scope` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenantId` BIGINT NOT NULL DEFAULT 1 COMMENT '租户ID（单主体阶段强制=1）',
  `subjectId` BIGINT NOT NULL DEFAULT 1 COMMENT '所属主体ID（org_subject.id）',
  `roleId` BIGINT NOT NULL COMMENT '角色ID（base_sys_role.id）',
  `orgId` BIGINT NOT NULL COMMENT '组织ID（org_unit.id；功能权限和数据权限边界——这里仅存数据=哪些组织下的数据可见）',
  `createTime` DATETIME DEFAULT NULL COMMENT '创建时间',
  `createUser` BIGINT DEFAULT NULL COMMENT '创建人',
  `updateTime` DATETIME DEFAULT NULL COMMENT '更新时间',
  `updateUser` BIGINT DEFAULT NULL COMMENT '更新人',
  PRIMARY KEY (`id`),
  KEY `idx_org_role_scope_tenantId` (`tenantId`),
  KEY `idx_org_role_scope_subjectId` (`subjectId`),
  KEY `idx_org_role_scope_roleId` (`roleId`),
  KEY `idx_org_role_scope_orgId` (`orgId`),
  -- 组合唯一：同一角色下同一组织不得重复授权
  UNIQUE KEY `uk_org_role_scope_tenantId_roleId_orgId` (`tenantId`, `subjectId`, `roleId`, `orgId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组织结构·角色组织范围（数据权限唯一真源，P4-A 段核心真源4/4）';
