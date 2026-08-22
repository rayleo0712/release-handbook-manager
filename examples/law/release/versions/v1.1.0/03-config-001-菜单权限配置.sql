-- ==============================================================
-- 03-config-001：v1.1.0 菜单 / 权限节点配置
-- 作用：
--   1) 新增独立中止终止管理页菜单 `/case/stop-end-manage`
--   2) 新增 stopEndManage 7 个权限按钮
--   3) 新增 110 分算法 Top5 候选推荐权限按钮
--   4) 新增字典白名单 import / whitelist 2 个权限按钮
--   5) 对 `/case/complaint`、`/case/list`、`/case/disciplinary` 的 allData 权限节点做幂等兜底并统一名称
--
-- 执行前提：
--   - 先执行 02-db-001 ~ 02-db-013
--   - 当前库已存在基础菜单：/case/list、/case/complaint、/case/disciplinary、/dict/list
--
-- 幂等策略：
--   - 页面菜单按 router 唯一识别
--   - 按钮权限按 perms 唯一识别
--   - 已存在节点执行 UPDATE 统一父级、名称、排序与视图路径
-- ==============================================================

SET @now = DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s');

-- 业务管理根目录：优先取 /case/list 的父菜单；若缺失则兜底取“业务管理”目录。
SET @businessRootId = (
  SELECT COALESCE(
    (SELECT parentId FROM base_sys_menu WHERE router = '/case/list' LIMIT 1),
    (SELECT id FROM base_sys_menu WHERE name = '业务管理' AND type = 0 LIMIT 1)
  )
);

-- 现有页面菜单 ID。
SET @complaintMenuId = (SELECT id FROM base_sys_menu WHERE router = '/case/complaint' LIMIT 1);
SET @caseListMenuId = (SELECT id FROM base_sys_menu WHERE router = '/case/list' LIMIT 1);
SET @disciplinaryMenuId = (SELECT id FROM base_sys_menu WHERE router = '/case/disciplinary' LIMIT 1);
SET @dictMenuId = (SELECT id FROM base_sys_menu WHERE router = '/dict/list' LIMIT 1);

-- ==============================================================
-- 1. 独立中止终止管理页菜单
-- ==============================================================
INSERT INTO base_sys_menu (
  createTime, updateTime, tenantId, parentId, name, router, perms,
  type, icon, orderNum, viewPath, keepAlive, isShow
)
SELECT
  @now, @now, 1, @businessRootId, '中止终止管理', '/case/stop-end-manage', NULL,
  1, 'icon-list', 21, 'modules/case/views/stop-end-manage/index.vue', 1, 1
FROM DUAL
WHERE @businessRootId IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM base_sys_menu WHERE router = '/case/stop-end-manage'
  );

UPDATE base_sys_menu
SET
  parentId = @businessRootId,
  name = '中止终止管理',
  type = 1,
  icon = 'icon-list',
  orderNum = 21,
  viewPath = 'modules/case/views/stop-end-manage/index.vue',
  keepAlive = 1,
  isShow = 1,
  tenantId = IFNULL(tenantId, 1),
  updateTime = @now
WHERE router = '/case/stop-end-manage';

SET @stopEndManageMenuId = (SELECT id FROM base_sys_menu WHERE router = '/case/stop-end-manage' LIMIT 1);

-- ==============================================================
-- 2. stopEndManage 7 个权限按钮
-- ==============================================================
SET @menuPerm = 'case:stopEndManage:page';
SET @menuName = '列表查询';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:stopEndManage:detail';
SET @menuName = '申请详情';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:stopEndManage:approveDetail';
SET @menuName = '审批明细';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:stopEndManage:flowStep';
SET @menuName = '流程步骤';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:stopEndManage:caseGoto';
SET @menuName = '跳转案件';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:stopEnd:emergencyAssignApprover';
SET @menuName = '兜底指定审批人';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:stopEndManage:reviewInfo';
SET @menuName = '审核信息豁免';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @stopEndManageMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @stopEndManageMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @stopEndManageMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

-- ==============================================================
-- 3. 110 分算法 Top5 候选推荐权限
--    当前入口位于投诉管理生成案件流程内，因此挂到 /case/complaint 菜单下。
-- ==============================================================
SET @menuPerm = 'case:team:autoAssignCandidates';
SET @menuName = 'Top5候选推荐';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @complaintMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @complaintMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @complaintMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

-- ==============================================================
-- 4. 字典白名单 2 个权限
-- ==============================================================
SET @menuPerm = 'dict:type:import';
SET @menuName = '字典批量导入';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @dictMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @dictMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @dictMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'dict:type:whitelist';
SET @menuName = '字典导入白名单';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @dictMenuId, @menuName, NULL, @menuPerm, 2, NULL, 0, NULL, 0, 1
FROM DUAL
WHERE @dictMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @dictMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 0, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

-- ==============================================================
-- 5. allData 权限节点兜底 + 名称统一
-- ==============================================================
SET @menuPerm = 'case:complaint:allData';
SET @menuName = '投诉管理-查看全部数据';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @complaintMenuId, @menuName, NULL, @menuPerm, 2, NULL, 999, NULL, 0, 1
FROM DUAL
WHERE @complaintMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @complaintMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 999, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:info:allData';
SET @menuName = '案件管理-查看全部数据';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @caseListMenuId, @menuName, NULL, @menuPerm, 2, NULL, 999, NULL, 0, 1
FROM DUAL
WHERE @caseListMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @caseListMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 999, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;

SET @menuPerm = 'case:disciplinary:allData';
SET @menuName = '处分案件-查看全部数据';
INSERT INTO base_sys_menu (createTime, updateTime, tenantId, parentId, name, router, perms, type, icon, orderNum, viewPath, keepAlive, isShow)
SELECT @now, @now, 1, @disciplinaryMenuId, @menuName, NULL, @menuPerm, 2, NULL, 999, NULL, 0, 1
FROM DUAL
WHERE @disciplinaryMenuId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_sys_menu WHERE perms = @menuPerm);
UPDATE base_sys_menu
SET parentId = @disciplinaryMenuId, name = @menuName, router = NULL, type = 2, icon = NULL, orderNum = 999, viewPath = NULL, keepAlive = 0, isShow = 1, tenantId = IFNULL(tenantId, 1), updateTime = @now
WHERE perms = @menuPerm;
