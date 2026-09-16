# 圆景记录 · yuanjing-record

本地优先的 iPhone 日常记录应用：记账、排便与桌面快捷入口，睡眠预留。以轻便、无广告、适合长期个人记录为目标。

![金渐层主题图集](design/doodle-ui/ui-atlas-honey.jpg)

## 当前可用的开发功能

- 快速记账：固定多行大类、自动弹出小标签、金额加减、账户和时间选择。
- 总余额与逐账户校准，资产减负债；自有账户转账不计消费。
- 可调整的发薪周期，以及前三个月同期平均百分比对比。历史覆盖不足时不计算误导性的对比。
- 原支出关联退款、待收分摊和实际回款，保留原记录；账单编辑区分历史导入、校准前与校准后的余额影响。
- 按分类、小标签和备注搜索统计；可以查询某家店在指定日期范围的净支出和占比。
- 懒猫导出 CSV / TSV 的预览导入、账户对应、原始字段保留和重复识别，历史导入不重放余额变化。
- 排便计时起点持久化、月历、固定常态设置、补记和详情。
- 可开启的本地提醒：未结束记录默认 22 点提醒一次，3 天无排便记录提醒一次。
- 两个独立桌面小组件快捷入口；奶油、蜂蜜金配色和长毛金渐层插画。
- 本地 JSON 保存、导出至「文件」或 iCloud Drive、校验后恢复并保留恢复前副本。

## 开发

使用 Xcode 打开 `ios/Yuanjing.xcodeproj`，选择 `Yuanjing` Scheme。目标为 iPhone，最低系统 iOS 17。无外部 Swift 包依赖。

```sh
# 领域、迁移、提醒策略与账单修正测试
ios/Tests/run.sh

# 编译模拟器应用
xcodebuild -project ios/Yuanjing.xcodeproj -scheme Yuanjing \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/yuanjing-build CODE_SIGNING_ALLOWED=NO build
```

具体测试与真机安装说明见 [iOS 开发说明](ios/README.md)。产品约定见 [产品设计](docs/product-design.md)，迁移规则见 [数据迁移](docs/migration.md)。

## 使用状态

这是开发版，已经在模拟器启动并完成记账与排便计时的重启恢复测试，尚未在实体 iPhone 验收。源码构建成功不等于已完成全部产品能力。

仍需完成：小组件状态共享与距离上次排便显示、自动 iCloud 备份、排便截图迁移、图片附件，以及真机通知／小组件／恢复验收。正式替换旧软件前，应核对导入结果并保存旧导出文件。

仓库只包含源码、生成的设计资源和虚构测试数据。个人账单、健康记录、备份、签名证书和构建产物不纳入版本控制。
