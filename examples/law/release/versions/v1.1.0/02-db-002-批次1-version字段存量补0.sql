-- ============================================================
-- 02-db-002 批次1合规整改 · 结构化结果乐观锁 version 存量行补 0
-- 版本号：v1.0.0
-- 执行时机：发布步骤 4.3（02-db-001 执行通过后立刻执行，可重跑幂等）
-- 幂等说明：仅更新 version IS NULL 的存量行；重复执行时命中 0 行，无副作用
-- 说明：TypeORM 的 @VersionColumn 首次 INSERT 时 NULL 会自动写 0；
--       但 D04 回填脚本执行 INSERT 前未开启 @VersionColumn 自动管理时，
--       存量行 version 可能保持 NULL；乐观锁冲突检测会略过 NULL 行。
--       这里一次性补 0，保证存量行也能参与 40901 并发校验。
-- ============================================================

UPDATE case_discipline_result
   SET version = 0
 WHERE version IS NULL;

-- --------------------
-- 执行后校验（必须执行，否则禁止进入 4.4 回填步骤）
-- --------------------
SELECT COUNT(*) AS null_version_cnt  -- 预期 = 0
  FROM case_discipline_result
 WHERE version IS NULL;
