# 基础成本估算

估算调用方拥有的单个按小时计费资源，不创建资源、不查询云 API。提供真实小时报价、币种/地域、价格来源和资源地址。

模块 source 为 `terraform-volcenginecc-modules/pricing/volcenginecc`，尚未验证发布和 Registry 消费。本地使用时，将示例复制到临时目录，改 source 为仓库绝对路径。

在私有 `quote.tfvars` 中填写 `hourly_unit_price`、`price_source`、`resource_address`，可选填写 `currency`（CNY）、`region`（cn-beijing）。模块默认每月 730 小时、无折扣，月度为单价 × 730，年度为月度 × 12。报价必须与目标区域及币种一致。

```bash
terraform init -backend=false
terraform plan -input=false -var-file=quote.tfvars -out=estimate.tfplan
terraform show -json estimate.tfplan > estimate.json
```

从 estimate.json 的 `planned_values.outputs.report.value` 读取预测，无需 apply。使用后删除生成的 Plan/JSON 和临时工作目录，无云资源需要销毁。

验证基线为 Terraform 1.5.7 和 OpenTofu 1.11.8，使用相同配置。本示例为线性持续费用估算，不是官方账单；不包含税费、预付费用或实时单价查询。
