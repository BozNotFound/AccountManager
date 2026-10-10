# 本地记账 App（Flutter / Android）

个人自用的安卓记账 App。**零权限、不联网**，数据仅存本机 SQLite。
需求与设计见上级目录 `../docs/开发文档.md`（v1.4 为实现依据）。

## 当前进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| M1 | 工程初始化 + 数据层（4 张表 + 种子数据 + v1→v2 迁移） | ✅ 完成 |
| M2 | F1 手动快速记账 + F2 分类管理 | ✅ 完成 |
| M3 | F3 流水列表（首页、按月/按日、编辑删除） | ✅ 完成 |
| M4 | F4 图片识别（PP-OCRv5 + 解析规则） | ⬜ 待开发 |
| M5 | 确认页 + 商户学习 | ⬜ 待开发 |
| M6 | F5 月度统计（总览 + 环比 + 环形图 + 排行下钻） | ✅ 完成 |
| M7 | F6 CSV 导出（type/source 英文） | 🟡 生成/预览已完成，落盘方式待定 |
| M8 | 深色模式、打包发布 | 🟡 签名已配置，首包待构建 |

## 一键自检 + 打包（推荐入口）

项目根目录下有两个文件，合起来是一个工具：

| 文件 | 作用 |
|---|---|
| `../check_and_build.cmd` | 启动壳（纯 ASCII，双击可用，自动找 Python） |
| `../check_and_build.py` | 真正的检查逻辑（中文输出，逐环节报状态） |

**在普通终端里**运行（Windows Terminal / cmd / PowerShell，**不要在智能体内**）：

```
check_and_build.cmd                 # 自检 + 依赖 + 分析 + 测试 + 打包
check_and_build.cmd --quick         # 只做秒级环境自检，不跑 flutter
check_and_build.cmd --no-build      # 自检 + 依赖 + 分析 + 测试，但不打包
check_and_build.cmd --force         # 某环节失败也继续往下走
```

它会把整条链路走一遍，最后打印「链路汇总」：

| # | 链路 | 查什么 |
|---|---|---|
| 0 | 定位项目 | `pubspec.yaml` 在不在 |
| 1 | 运行环境 | 是否误在智能体沙箱里跑（沙箱必失败，会提示换终端） |
| 2 | 工具链文件 | flutter / dart / java / keytool / adb / sqlite3.dll |
| 3 | 版本信息 | flutter、java、adb 三者能否执行 |
| 4 | Android SDK | platform-35、build-tools 35.0.0、licenses、NDK |
| 5 | Gradle 配置 | local.properties、wrapper 镜像、Gradle 发行包缓存 |
| 6 | 源码权限 | main 清单必须零权限（debug/profile 的 INTERNET 只影响调试包） |
| 7 | 签名 | key.properties 四项齐全 + keytool 校验密码/别名 + 打印指纹 |
| 8 | 依赖 | `flutter pub get` |
| 9 | 静态分析 | `flutter analyze`，只有 **error** 算失败；warning / info 级 lint 只提示不阻塞 |
| 10 | 单元测试 | `dart test/run_all.dart`，并解析出「通过 N 失败 M」 |
| 11 | 打包 | `flutter build apk --release` |
| 12 | 产物权限 | `aapt dump permissions`：**必须无 `android.permission.*`**（尤其 INTERNET）。签名级自定义权限 `*.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` 是 AndroidX 自动注入的，属正常，不判失败 |
| 13 | 产物签名 | `apksigner verify --print-certs`：必须签名有效并打印指纹 |

退出码 = 失败项数（0 表示全通），可直接接 CI。
预检（0~7）出现 FAIL 时会**直接停下不打包**，免得白等几分钟；加 `--force` 可越过这个限制。

## 金额一律用「分」（整数）存储

**全项目金额都是 `int` 分**，不做浮点运算——只在展示/导出时转成元字符串。

| 位置 | 单位与类型 |
|---|---|
| DB | `transactions.amount_cents INTEGER` |
| 模型 | `Transaction.amountCents`（int） |
| 统计 | `MonthSummary.expenseCents/incomeCents/balanceCents`、`DayGroup.*Cents`、`CategoryStat.totalCents` |
| 工具 | `Money.formatCents`（界面）/ `plainCents`（CSV、编辑回填）/ `signedCents` / `parseCents` |

原因：`REAL` 下 `0.1 + 0.2 != 0.3`，月度合计会攒出 0.01 级误差，直接毁掉统计占比与（将来的）OCR 校验和比对。
只有比例/百分比仍用 `double`（本身就是近似值）。

DB 版本 **2**；v1 → v2 迁移见 `LedgerSchema.upgrade`（建临时表 → `CAST(ROUND(amount*100) AS INTEGER)` 拷 → 删旧表 → 改名 → 重建索引），有单测覆盖。


## 目录结构

```
lib/
  main.dart / app.dart            入口与主题
  core/
    db/database.dart              schema + LedgerDatabase（纯 Dart，可测）
    db/database_flutter.dart      Flutter 胶水：路径与 DatabaseFactory（唯一依赖 sqflite 插件的文件）
    db/seed_data.dart             预置分类与商户关键词规则
    services.dart                 依赖装配
    utils/                        money / datetime_utils / amount_input / amount_color
  models/                         TxType / Category / Transaction / DayGroup / MonthSummary
  repositories/                   CategoryRepository / TransactionRepository
  features/
    ledger/                       首页流水
    manual_entry/                 手动记账页 + 大键盘
    category/                     分类管理
    stats/                        F5 统计页 + 手绘环形图 + 分类下钻
    export/                       F6 CSV 生成 + 导出页
    common/                       月份切换等共用组件
    settings/                     设置
test/
  run_all.dart                    纯 Dart 测试入口
  support/check.dart              极简断言
tool/
  analyze_project.dart            进程内静态分析（等价 flutter analyze）
  flutter_env.cmd                 普通终端里注入环境并执行 flutter 命令
```

再往上一层（项目根）还有 `check_and_build.cmd` + `check_and_build.py`：一键自检 + 打包，见上文「一键自检 + 打包」。

## 版本管理（Git）

仓库根就是本目录 `code\`（**不含**上级的 `docs/`、`keystore/`、`check_and_build.*`）。

| 文件 | 作用 |
|---|---|
| `.gitignore` | Flutter 工程忽略规则（含签名文件保护） |
| `.gitattributes` | 行尾规则：仓库内统一 LF，`.cmd` / `.bat` 强制 CRLF |
| `git_init.cmd` | 一键初始化（纯 ASCII）：init → 校验身份 → add → **敏感文件守卫** → 首次提交 |

完整操作手册（含接 GitHub 私有仓库、PAT 认证、误提交补救流程）：见 **`../docs/Git使用说明.md`**。

日常提交：

```
git status && git add -A && git commit -m "feat: ..." && git push
```

提交前建议先跑 `..\check_and_build.cmd --no-build`（自检 + 分析 + 66 个单测全绿）。

**绝不能提交**：`android/key.properties`（**明文签名密码**）、`android/local.properties`（本机绝对路径）。
两者已被 `.gitignore` 覆盖，`git_init.cmd` 每次还会再核对一遍。

## 命令

常规环境（IDE / 开发者机器）：

```bash
flutter pub get
flutter analyze                  # 静态分析
dart test/run_all.dart           # 单元测试（纯 Dart，66 个用例）
flutter build apk --release      # 构建 APK
flutter run                      # 连手机运行
```

Windows 上跑单元测试需要 sqlite3.dll 可被加载（数据库层测试用）：

```bash
# 方式一：PATH 中提供 sqlite3.dll（如已有 D:/CS/downloads/sqlite3dll）
export PATH="/d/CS/downloads/sqlite3dll:$PATH"
# 方式二：让 sqflite_common_ffi 自行准备
dart run sqflite_common_ffi:setup
```

## 如何验证这个项目（三层，从快到慢）

### 第 1 层：自动化验证（10 秒，任意环境）

```bash
DART=/d/CS/flutter/bin/cache/dart-sdk/bin/dart.exe
export PATH="/d/CS/downloads/sqlite3dll:$PATH"

$DART test/run_all.dart            # 期望：通过 66  失败 0
$DART tool/analyze_project.dart    # 期望：分析文件 38 个，错误 0，警告 0，提示 0
```

这两条**不依赖 Flutter 运行时、不拉子进程**，因此在智能体内、普通终端里都能跑。
它们覆盖：金额解析/格式化/往返、输入缓冲、日期工具、CSV 文本（含转义/BOM/字段）、
建库与种子、**v1→v2 迁移**、流水读写与统计聚合、分类管理保护、统计聚合与环比。

> `run_all.dart` 的断言是自写的极简框架（`test/support/check.dart`），
> 失败会打印「用例名 → 原因」并以退出码 1 结束，可直接接到 CI。

### 第 2 层：Flutter 工具链验证（普通终端，1~3 分钟）

```bash
code\tool\flutter_env.cmd pub get
code\tool\flutter_env.cmd analyze      # 官方 linter 全量检查（含 UI 层）
```

注意：`flutter test` 目前**不可用**——`test/` 下是自写的纯 Dart 断言框架（不是 `flutter_test` 工程结构），
所以测试统一用第 1 层的 `dart test/run_all.dart`。这是为绕开智能体的管道限制而做的选择，
代价是失去了 `flutter_test` 的 Widget 测试能力（UI 行为目前只能靠真机验收，见第 3 层）。

### 第 3 层：真机验收（必须你来做，智能体内做不了）

```bash
code\tool\flutter_env.cmd run                    # 连手机热调试
code\tool\flutter_env.cmd build apk --release    # 产出 build\app\outputs\flutter-apk\app-release.apk
```

装到手机后按下面清单逐条走一遍（这是 P0 的人工验收）：

| # | 步骤 | 期望 |
|---|---|---|
| 1 | 首次启动 | 不弹任何权限申请；能直接进入首页 |
| 2 | 点「记一笔」→ 支出 12.50 → 选「餐饮」→ 完成 | ≤3 步保存成功，首页出现该笔，显示 `-12.50` 红色 |
| 3 | 再记一笔收入 1000 → 选「工资」 | 显示 `+1,000.00` 绿色 |
| 4 | 首页汇总卡 | 支出 12.50 / 收入 1,000.00 / 结余 987.50 |
| 5 | 点某笔 → 编辑改金额为 20 | 保存后列表与汇总同步更新 |
| 6 | 点某笔 → 删除 | 有二次确认，确认后消失 |
| 7 | 切到上一个月 | 列表为空（或只有上月数据），汇总为 0 |
| 8 | 点首页汇总卡 → 统计页 | 环形图/排行与支出构成一致；点扇区能进明细 |
| 9 | 设置 → 导出 CSV | 选月份 → 预览前 6 行 → 表头为 `id,type,amount,...`；`type` 列是 `expense`，`source` 列是 `manual` |
| 10 | 杀进程后重开 | 数据仍在（SQLite 已落盘） |
| 11 | 装完后查权限 | `aapt dump permissions app-release.apk` 输出中**不含任何 `android.permission.*`**（尤其无 INTERNET）。可能有一条 `com.personal.ledger.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`，那是 AndroidX 自动注入的签名级自定义权限，属正常 |
| 12 | （可选）用旧版 v1 数据升级 | 原金额正确显示（迁移生效），无崩溃 |

第 11 条如果本机没有 `aapt`，也可以用手机的「应用信息 → 权限」页确认：应显示「无权限」
（签名级自定义权限不会展示在系统权限页里）。

> **为什么产物里会有一条权限？** Android 13 起动态注册广播必须显式声明 `RECEIVER_EXPORTED` / `RECEIVER_NOT_EXPORTED`，
> AndroidX Core 为了在 API < 33 上模拟后者，用了一条「同签名才能持有」的自定义权限当哨兵
> （`androidx.core:core` 的清单里自带 `<permission>` + `<uses-permission>`，由 manifest merger 并进产物）。
> 它由 Flutter 引擎的安卓 embedding 引入，与业务代码无关，无法也不必去除——
> 强用 `tools:node="remove"` 删掉会破坏 API < 33 上的接收器注册保护（本项目 minSdk 26，会真实走到这段逻辑）。


## 本机工具链位置

| 组件 | 路径 |
|---|---|
| Flutter 3.29.3 | `D:/CS/flutter` |
| JDK 17 | `D:/CS/JDK/jdk-17.0.10` |
| Android SDK（platform-35 / build-tools 35.0.0） | `D:/CS/android-sdk` |
| Gradle 缓存（wrapper 已指向腾讯云镜像） | `D:/CS/gradle` |

## 在智能体之外的普通终端里构建（推荐）

环境注入脚本：**在 Windows Terminal / cmd / PowerShell 中**（不要在智能体里）执行：

```
code\tool\flutter_env.cmd pub get
code\tool\flutter_env.cmd analyze
code\tool\flutter_env.cmd build apk --release
code\tool\flutter_env.cmd run
```

## 导出（M7）现状

已完成：范围选择（指定月份 / 全部）、笔数统计、前 6 行预览、CSV 生成并复制到剪贴板。
CSV 规格：UTF-8 with BOM + CRLF（Excel 直接打开不乱码），字段
`id, type, amount, category, merchant, note, date, source, created_at`；
字段含逗号/引号/换行时按 RFC 4180 转义。

**type / source 输出英文**：`expense` / `income` / `transfer`、`manual` / `ocr`
（便于程序化处理与将来做导入；`category` 仍是中文分类名）。金额不带千分位，Excel 识别为数值。

**待定（确认后才动）——落盘/分享方式三选一：**

| 方案 | 做法 | 代价 |
|---|---|---|
| ① 分享面板 | `share_plus` + `path_provider` | 新增 2 个依赖，体验最好，符合开发文档 §1 第 3 条 |
| ② SAF 保存对话框 | 原生 `MethodChannel` + `ACTION_CREATE_DOCUMENT` | 零依赖，需手写 Kotlin，当前环境无法编译验证 |
| ③ 维持剪贴板 | 现状 | 零依赖零风险，但记录多时不方便 |

## Release 签名（已配置，2026-10-08）

release 构建使用自有签名，配置链路：

| 文件 | 作用 | 是否可提交 |
|---|---|---|
| `../keystore/ledger-release.jks` | 密钥库本体（别名 `ledger`，PKCS12，有效期至 2056） | ❌ 绝对不要 |
| `android/key.properties` | 签名参数（含明文密码），Gradle 读取 | ❌ 已被 .gitignore 忽略 |
| `../keystore/SIGNING-README.txt` | 密码、指纹与备份指引 | ❌ 含明文密码 |
| `android/app/build.gradle.kts` | 读取 key.properties 并配置 `signingConfigs.release` | ✅ |

要点：
- **覆盖升级靠同一密钥库**——只要一直用这个 .jks 打包，新 APK 可直接覆盖安装并保留账本数据；
  换了密钥库就只能卸载重装（数据全丢）。
- 若 `android/key.properties` 缺失，构建会回落到 debug 签名（仍可出包，但无法长期升级）。
- 请把 .jks 与密码**备份到至少两个安全位置**，并且两者分开存放。

## 为什么这些命令在智能体内跑不了（已知限制）

WorkBuddy 的智能体执行环境限制了**命名管道的打开**。该沙箱自身就用命名管道做 IPC
（环境变量 `SANDBOX_CENTER_IPC_ADDRESS=\\.\pipe\WorkBuddy_SandboxCenter_...`、
`LSBOX_AUDIT_SHMEM=Local\LiteSandbox_Audit_...`），因此对沙箱内进程访问命名管道做了拦截。
实测结果（`D:/CS/pipe_check.py`）：

| 操作 | 结果 |
|---|---|
| `CreateNamedPipeW` 创建命名管道 | 成功 |
| `CreateFileW` 打开该命名管道 | **失败：231 ERROR_PIPE_BUSY / 5 ACCESS_DENIED** |
| `CreatePipe` 匿名管道 | 成功 |
| Python `subprocess`（匿名管道）拉起子进程 | 成功 |
| Dart `Process.start`（命名管道）拉起子进程 | **失败** |
| Node.js `execSync`（libuv，命名管道） | **失败** |
| Dart `ProcessStartMode.inheritStdio`（不用管道） | 成功 |

Dart 与 Node 都用命名管道做子进程 stdio，所以**凡"由 Dart 拉起子进程"的命令必然失败**：
`flutter analyze` / `flutter test` / `flutter doctor` / `flutter create` / `flutter build apk`，
典型报错 `ProcessException: 所有的管道范例都在使用中。` + `CreateFile failed 231`。
该限制不随单条命令的沙箱开关变化，**智能体内无法绕过**（Dart 没有"改用匿名管道"的开关）。

智能体内可用的进程内替代（不拉子进程，已跑通）：

```bash
DART=/d/CS/flutter/bin/cache/dart-sdk/bin/dart.exe
$DART tool/analyze_project.dart      # 等价 flutter analyze（38 文件，0 错误）
$DART test/run_all.dart              # 66 个用例
```

## 已做的环境调整

`D:/CS/flutter/.pub-preload-cache` → 改名为 `.pub-preload-cache.disabled`。

原因：`flutter_tools` 的 `_preloadPubCache()`（`packages/flutter_tools/lib/src/dart/pub.dart`）
会用 `_processManager.runSync` 执行 `dart pub cache preload <160 个 .tar.gz>`，命中上述管道限制后直接抛异常。
该目录只是 SDK 自带的包快照（191MB，仅用于加速首次 `pub get`），flutter 本意是"跑一次后删除"，改名无功能影响。
在能正常使用管道的终端里可还原，或手动执行一次 `dart pub cache preload <文件...>` 后删除该目录（等价于 flutter 自己的做法）。

## 架构约定

1. **领域层不依赖 Flutter**：`models/`、`repositories/`、`core/db/database.dart`、`core/utils/` 仅用纯 Dart；
   数据库类型统一来自 `package:sqflite_common/sqlite_api.dart`。
   只有 `core/db/database_flutter.dart` 使用 Flutter 插件 `sqflite`。
2. 金额配色：支出 `-` 红、收入 `+` 绿、转账中性灰（`core/utils/amount_color.dart`）。
3. **金额一律 `int` 分**，禁止用 `double` 存/算金额（见上文「金额一律用「分」」）。
4. 依赖保持最少：sqflite / sqflite_common / path；状态管理用原生 `setState`。
5. 转账类型不计入支出/收入统计。
