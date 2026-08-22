-- ============================================================
-- 02-db-003 批次1合规整改 · client_token 历史数据兼容补写（两子步骤）
-- 版本号：v1.0.0
-- 执行时机：发布步骤 4.4（02-db-002 执行通过后；可重跑幂等）
-- 幂等说明：仅补写 status / invalidReason / logoutTime 缺失值；重复执行时仅命中仍缺失的历史记录
-- 兼容规则说明：对应数据迁移任务单 D01-补02 第 1、2 条；
--   上线首月（兼容窗口 1 个月）历史有效 token 即使未绑定 deviceFingerprint
--   也允许正常访问，仅在响应头追加 X-Auth-Warn: migrate-fingerprint-required
--   前端下次登录时强制刷新 token 并补传指纹。
-- ============================================================

-- 子步骤 1：status 列尚未赋值的历史记录，按 expireTime 分流
--           - 未过期 → 写 active（当前仍可正常鉴权）
--           - 已过期 → 写 expired + invalidTime + invalidReason='compatible_expire'
UPDATE client_token
   SET status = 'active',
       invalidReason = COALESCE(invalidReason, NULL)
 WHERE (status IS NULL OR status = '')
   AND (invalidReason IS NULL OR invalidReason = '')
   AND expireTime >= NOW();

UPDATE client_token
   SET status        = 'expired',
       invalidTime   = COALESCE(invalidTime, expireTime),
       invalidReason = COALESCE(invalidReason, 'compatible_expire')
 WHERE (status IS NULL OR status = '')
   AND expireTime < NOW();

-- 子步骤 2：status='revoked' 且已写 invalidReason='logout'，但 logoutTime 未写的历史注销记录
--           按 invalidTime 回填（如果 invalidTime 也没有就按更新时间），保证审计口径完整。
UPDATE client_token
   SET logoutTime = COALESCE(invalidTime, updateTime, NOW())
 WHERE status = 'revoked'
   AND invalidReason = 'logout'
   AND logoutTime IS NULL;

-- --------------------
-- 执行后校验（必须执行）
-- --------------------
-- 2.1 仍有 status 为空的行：预期 0
SELECT COUNT(*) AS null_status_cnt  FROM client_token WHERE status IS NULL OR status = '';

-- 2.2 被注销但 logoutTime 仍为空的行：预期 0（允许少量其它 invalidReason 非 logout 的行为空，这里只查注销）
SELECT COUNT(*) AS null_logout_cnt  FROM client_token WHERE status = 'revoked' AND invalidReason = 'logout' AND logoutTime IS NULL;

-- 2.3 过期但 invalidReason 为空的行：预期 0
SELECT COUNT(*) AS null_expired_reason_cnt  FROM client_token WHERE status = 'expired' AND (invalidReason IS NULL OR invalidReason = '');
