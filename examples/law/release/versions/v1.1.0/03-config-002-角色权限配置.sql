-- ==============================================================
-- 03-config-002：v1.1.0 角色权限默认分配
-- 作用：
--   1) 为独立中止终止管理页分配最小可用默认权限
--   2) 为 110 分算法 Top5 候选推荐分配默认权限
--   3) 为字典白名单 2 个按钮分配默认权限
--   4) 保持幂等：只补新增节点的角色关系，不覆盖角色其它菜单权限
--
-- 说明：
--   - 本脚本只处理 01-更新手册 §3.2 中 1~10 号接口的默认授权
--   - org 4 实体（11~12 号）仍按 P4-C 切读前统一开通，当前版本不在本脚本默认授权范围
--   - allData 节点只在 03-config-001 中保证存在与命名统一，不在此脚本里改写角色绑定，避免覆盖现场已配置权限
-- ==============================================================

SET @now = DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s');

-- ==============================================================
-- 1. 独立中止终止管理页：页面菜单 + 常规 5 权限
--    默认角色：超管 / 惩戒委副主任（组长）/ 惩戒委主任 / 副会长 / 司法局管理员
-- ==============================================================
INSERT INTO base_sys_role_menu (createTime, updateTime, tenantId, roleId, menuId)
SELECT @now, @now, 1, r.id, m.id
FROM base_sys_role r
JOIN base_sys_menu m ON m.router = '/case/stop-end-manage'
WHERE (
    r.label IN ('admin', 'ViceDirector', 'Director', 'VicePresident', 'JusticeBureau')
    OR r.name IN ('超管', '惩戒委副主任（组长）', '惩戒委主任', '副会长', '司法局管理员')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM base_sys_role_menu rm
    WHERE rm.roleId = r.id AND rm.menuId = m.id
  );

INSERT INTO base_sys_role_menu (createTime, updateTime, tenantId, roleId, menuId)
SELECT @now, @now, 1, r.id, m.id
FROM base_sys_role r
JOIN base_sys_menu m ON m.perms IN (
  'case:stopEndManage:page',
  'case:stopEndManage:detail',
  'case:stopEndManage:approveDetail',
  'case:stopEndManage:flowStep',
  'case:stopEndManage:caseGoto'
)
WHERE (
    r.label IN ('admin', 'ViceDirector', 'Director', 'VicePresident', 'JusticeBureau')
    OR r.name IN ('超管', '惩戒委副主任（组长）', '惩戒委主任', '副会长', '司法局管理员')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM base_sys_role_menu rm
    WHERE rm.roleId = r.id AND rm.menuId = m.id
  );

-- ==============================================================
-- 2. 兜底指定审批人：默认仅超管
-- ==============================================================
INSERT INTO base_sys_role_menu (createTime, updateTime, tenantId, roleId, menuId)
SELECT @now, @now, 1, r.id, m.id
FROM base_sys_role r
JOIN base_sys_menu m ON m.perms = 'case:stopEnd:emergencyAssignApprover'
WHERE (
    r.label = 'admin'
    OR r.name = '超管'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM base_sys_role_menu rm
    WHERE rm.roleId = r.id AND rm.menuId = m.id
  );

-- ==============================================================
-- 3. 审核信息豁免：默认超管 + 系统运维
-- ==============================================================
INSERT INTO base_sys_role_menu (createTime, updateTime, tenantId, roleId, menuId)
SELECT @now, @now, 1, r.id, m.id
FROM base_sys_role r
JOIN base_sys_menu m ON m.perms = 'case:stopEndManage:reviewInfo'
WHERE (
    r.label IN ('admin', 'SysOP')
    OR r.name IN ('超管', '系统运维')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM base_sys_role_menu rm
    WHERE rm.roleId = r.id AND rm.menuId = m.id
  );

-- ==============================================================
-- 4. 110 分算法 Top5 候选推荐
--    当前库无独立“案件管理员”角色时，默认映射：超管 / 惩戒委主任 / 惩戒委副秘书长
-- ==============================================================
INSERT INTO base_sys_role_menu (createTime, updateTime, tenantId, roleId, menuId)
SELECT @now, @now, 1, r.id, m.id
FROM base_sys_role r
JOIN base_sys_menu m ON m.perms = 'case:team:autoAssignCandidates'
WHERE (
    r.label IN ('admin', 'Director', 'JusticeAdmin')
    OR r.name IN ('超管', '惩戒委主任', '惩戒委副秘书长')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM base_sys_role_menu rm
    WHERE rm.roleId = r.id AND rm.menuId = m.id
  );

-- ==============================================================
-- 5. 字典白名单 2 权限
--    当前库无独立“字典维护员”角色时，默认映射：超管 / 系统运维
-- ==============================================================
INSERT INTO base_sys_role_menu (createTime, updateTime, tenantId, roleId, menuId)
SELECT @now, @now, 1, r.id, m.id
FROM base_sys_role r
JOIN base_sys_menu m ON m.perms IN ('dict:type:import', 'dict:type:whitelist')
WHERE (
    r.label IN ('admin', 'SysOP')
    OR r.name IN ('超管', '系统运维')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM base_sys_role_menu rm
    WHERE rm.roleId = r.id AND rm.menuId = m.id
  );
