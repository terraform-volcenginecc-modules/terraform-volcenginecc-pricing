# 组合预测与预算集成

估算多资源工作负载的计划配置，生成供调用方 CI 告警流程消费的事件。分别映射计算小时费用、存储月费和流量用量费用；同一资源可有多个计费项。不创建资源或通知渠道。

source 为 `terraform-volcenginecc-modules/pricing/volcenginecc`，尚未验证 Registry 发布/消费。本地使用时复制示例到临时目录，将 source 改为仓库绝对路径。Terraform 1.5.7 和 OpenTofu 1.11.8 共用配置。

使用 `terraform show -json` 准备已保存的工作负载 Plan。私有 `catalog.json` 包含 currency、region、price_source、rates 和 resources。rate 包含 unit、实际 unit_price 和可选 reserved_eligible。每个完整资源地址映射到计费项 map；每项包含 rate_key，以及固定 quantity 或 quantity_path 二选一（后者为 planned 资源 values 中的属性名/索引数组）。usage 项还需 monthly_usage。例如实例 quantity 为 1；若已核实磁盘 Schema 中存在 size 字段，可用 quantity_path ["size"] 读取容量；流量用 monthly_usage 预测。SKU 和计费单位必须匹配真实报价。显式排除使用 ignored_resources 地址到原因的 map。

在私有 `budget.tfvars` 中填写 monthly_hours、reserved_instance_discount_rate、output_format 和 budget_thresholds，后者包含已批准的 monthly 和 annual 数字预算。转换工具提供 cost_items、currency、region 和 price_source，不要使用不一致的元数据覆盖这些字段。

将工作负载 Plan JSON、价格目录放在工作目录，并准备本地示例副本后，从仓库运行：

```bash
python3 scripts/plan_to_tfvars.py --plan plan.json --catalog catalog.json > costs.tfvars.json
terraform -chdir=examples/complete init -backend=false
terraform -chdir=examples/complete plan -input=false -var-file=../../costs.tfvars.json -var-file=budget.tfvars -out=estimate.tfplan
terraform -chdir=examples/complete show -json estimate.tfplan > estimate.json
python3 scripts/budget_gate.py estimate.json
```

上述路径假设 examples/complete 是临时仓库副本内已准备的本地示例。工作负载的 Plan 与仅估算的配置分开执行。无需 apply：report、formatted_report 和 alert_payload 位于 planned_values.outputs。门禁输出事件，预算内退出码为 0，超预算为 2，格式错误/输出未知为 1。CI 可将事件交给已有通知集成；脚本本身不发送消息。

空 map 预测为零。所有 managed 工作负载地址必须定价或显式排除；未知/缺失数量、过期映射均失败。删除的地址需移除。json 输出完整序列化报告，csv 输出费用行，text 输出可读摘要。预算使用严格大于、未舍入总额；折扣 0.30 仅对符合条件的项节省 30%。年度为月度 × 12，不包含预付费用、税费、阶梯/免费额度计算。

使用后删除生成的 Plan、JSON、私有报价/预算文件和临时目录，无需销毁云资源。实时价格、真实账单核对和通知发送未验证。
