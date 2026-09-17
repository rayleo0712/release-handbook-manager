# 编码与执行踩坑（rta 分片）

> 本分片由 `skills/release-test-auto/SKILL.md` §3.1「中文显示与编码规范（强制）」与 §3.2「中文编码关键约束（强制）」搬迁而来，代码块与禁止行为逐字保留。
> 加载时机：写浏览器自动化脚本、PowerShell / Bash 脚本、MySQL 导入脚本，或遇到中文乱码时。

## 一、中文显示与编码规范（强制）

自动化测试过程中若涉及浏览器页面渲染、终端日志输出、截图文字识别等场景，必须处理中文显示问题，避免乱码。

### 1.1 浏览器页面中文显示（Playwright / Puppeteer / Selenium 等）

1. **启动参数必须设置语言环境**：

   ```javascript
   // Playwright 示例
   const browser = await chromium.launch({
     args: ['--lang=zh-CN']
   });
   const context = await browser.newContext({
     locale: 'zh-CN'
   });
   ```

2. **页面字体必须包含中文字体**：

   ```javascript
   // 在页面加载后注入字体样式
   await page.addStyleTag({
     content: `
       * {
         font-family: "Microsoft YaHei", "PingFang SC", "Noto Sans SC", "Source Han Sans SC", sans-serif !important;
       }
     `
   });
   ```

3. **截图前必须等待字体渲染完成**：

   ```javascript
   // 确保页面稳定后再截图
   await page.waitForLoadState('networkidle');
   await page.screenshot({ path: 'screenshot.png' });
   ```

### 1.2 终端/日志中文输出（Windows PowerShell / CMD / WSL）

1. **Windows 终端必须设置 UTF-8 编码**：

   ```powershell
   # 在脚本开头强制设置 UTF-8
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   $OutputEncoding = [System.Text.Encoding]::UTF8
   chcp 65001 | Out-Null
   ```

2. **Linux/macOS 终端必须设置 locale**：

   ```bash
   export LANG=zh_CN.UTF-8
   export LC_ALL=zh_CN.UTF-8
   ```

3. **日志文件必须显式指定 UTF-8 编码**：

   ```powershell
   # PowerShell 写入日志
   "测试日志" | Out-File -FilePath "test.log" -Encoding UTF8
   ```

### 1.3 Docker 容器中文支持（如使用 Docker 运行测试）

```dockerfile
# Dockerfile 中必须安装中文字体
RUN apt-get update && apt-get install -y \
    fonts-noto-cjk \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    && rm -rf /var/lib/apt/lists/*

# 设置环境变量
ENV LANG=zh_CN.UTF-8
ENV LC_ALL=zh_CN.UTF-8
```

### 1.4 验证中文显示是否正常的方法

1. **浏览器截图验证**：截取包含中文的页面元素，人工检查或 OCR 识别确认无乱码
2. **日志输出验证**：在测试报告中输出固定中文字符串（如"中文测试通过"），验证显示正常
3. **断言文本匹配**：使用中文文本进行页面元素定位或断言，验证查找成功

### 1.5 禁止行为（中文显示）

- 禁止假设浏览器/终端默认支持中文而不做任何编码设置
- 禁止在截图对比时使用包含中文的图片作为基准（因字体渲染差异可能导致误判）
- 禁止将中文测试结果以非 UTF-8 编码保存到日志文件

## 二、数据恢复脚本中文编码关键约束（强制）

恢复脚本必须确保数据库中的中文数据不会出现乱码。严禁使用 PowerShell 文本管道导入 SQL 文件，因为这会导致字符编码转换问题。

### 2.1 禁止的做法（会导致中文乱码）

```powershell
# 禁止：Get-Content 配合管道，PowerShell 会重新编码文本
Get-Content xxx.sql | mysql.exe -u root -p dbname

# 禁止：ReadAllText 配合管道
$Content = [IO.File]::ReadAllText("xxx.sql")
$Content | mysql.exe -u root -p dbname

# 禁止：Set-Content 或其他文本流重定向
mysql.exe < (Get-Content xxx.sql)
```

### 2.2 推荐做法（确保中文不乱码）

```powershell
# 方法 1：让 mysql.exe 直接读取文件（最推荐）
mysql.exe -u root -p dbname < xxx.sql

# 方法 2：使用 Start-Process 直接传文件路径
Start-Process -FilePath "mysql.exe" -ArgumentList "-u root -p dbname -e source xxx.sql" -Wait

# 方法 3：使用字节流直传 stdin（避免 PowerShell 文本编码）
$Process = Start-Process -FilePath "mysql.exe" -ArgumentList "-u root -p dbname" -RedirectStandardInput -NoNewWindow -PassThru
$FileStream = [System.IO.File]::OpenRead("xxx.sql")
$FileStream.CopyTo($Process.StandardInput.BaseStream)
$Process.StandardInput.Close()
$Process.WaitForExit()
$FileStream.Close()
```

### 2.3 跨平台注意事项

```bash
# Linux/macOS 推荐做法（直接使用输入重定向）
mysql -u root -p dbname < xxx.sql

# 或使用 source 命令
mysql -u root -p -e "source /path/to/xxx.sql" dbname
```

### 2.4 验证方法

恢复脚本执行后，必须验证中文数据是否正常：

```sql
-- 检查关键表中文字段
SELECT * FROM user WHERE username LIKE '%中%' LIMIT 5;
-- 验证查询结果中文字符是否正常显示，无乱码
```

### 2.5 禁止行为（数据恢复）

- 禁止假设 SQL 文件是纯 ASCII 编码而不做编码声明
- 禁止在 PowerShell 中使用任何文本管道方式导入 SQL
- 禁止恢复后不验证中文数据是否正常
- 禁止将恢复脚本仅写在 `test-output/` 而不回写到 `rhm` 的 `04-发布检查清单.md §8 命令区`

## 三、读取现有文档时的编码陷阱（补充）

- 用 PowerShell 测量本仓库 Markdown 的行数/行长/体积时，**必须显式按 UTF-8 解码**：`[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)`
- `Get-Content` 默认按 ANSI 解码，会把 1 个中文字符误算为 2–3 个字符，导致「单行 ≤200 字符」判定虚高、误判为不合规
