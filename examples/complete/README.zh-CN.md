# COMPLETE 成本估算 示例

## 1. 概述

本示例组合计算、存储、流量等计费项，输出成本报告和月度、年度预算事件。相比 basic，它允许调整小时数、折扣率、预算阈值和报告格式，也可接收工作负载 Plan 转换后的输入并运行 CI 门禁。调用方提供同一币种、地域的单价和预测用量，无需准备 Provider、凭据、前置云资源或通知渠道。

## 2. 用法

准备 Terraform 1.5.7、各收费维度的单价、数量、预测用量及预算。本示例直接调用 Registry 中的成本估算模块，执行 `terraform init` 时下载模块。

在 `examples/complete/terraform.tfvars` 填写参数。以下单价和预算用于演示，均为 CNY，不是实际云产品报价：

```hcl
currency                        = "CNY"
region                          = "cn-beijing"
price_source                    = "illustrative rates; not a vendor quote"
monthly_hours                   = 730
reserved_instance_discount_rate = 0.20
output_format                   = "json"

budget_thresholds = {
  monthly = 650
  annual  = 10000
}

cost_items = {
  compute = {
    resource_address  = "compute"
    unit              = "hourly"
    unit_price        = 1
    quantity          = 1
    reserved_eligible = true
  }
  storage = {
    resource_address = "storage"
    unit             = "monthly"
    unit_price       = 2
    quantity         = 20
  }
  traffic = {
    resource_address = "traffic"
    unit             = "usage"
    unit_price       = 0.5
    quantity         = 1
    monthly_usage    = 100
  }
}
```

在 `examples/complete` 目录依次执行：

```shell
terraform init -backend=false
terraform plan -input=false -out=估算.tfplan
terraform apply 估算.tfplan
terraform plan -input=false -detailed-exitcode
terraform destroy
```

首次 Plan 应输出 `report`、`formatted_report` 和 `alert_payload`，不创建云资源。演示中 compute 月费为 `1 × 730 × (1 - 0.20) = 584`，storage 月费为 `2 × 20 = 40`，traffic 月费为 `0.5 × 100 = 50`；总月费 674 CNY，年费 8088 CNY。月费超过 650，月度告警为 `true`；年费未超过 10000，年度告警为 `false`，顶层 `exceeded` 为 `true`。

Apply 将输出保存到 State。保持输入与源码不变，再次 Plan 应无变化；`-detailed-exitcode` 返回 0 表示无变化、1 表示执行错误、2 表示有变化。确认状态属于本示例后执行 Destroy，它只清除保存的输出。

如需检查 CI 门禁，在首次 Plan 后、Destroy 前，将保存的 Plan 导出为 JSON，再运行：

```shell
terraform show -json 估算.tfplan > 估算.json
python3 ../../scripts/budget_gate.py 估算.json
```

演示输入下，门禁输出 `cost_budget_forecast` 事件并退出 2。要检查等额预算，把月预算改为 674、年预算改为 8088，重新保存 Plan、导出 JSON 并运行门禁，预期两个周期均不超预算，退出 0。预算变化会改变输出；完成修改并 Apply 后，重新执行 Plan 检查幂等性。门禁输出事件，通知发送由调用方实现。

## 3. 依赖要求

| 名称 | 版本 |
|---|---|
| Terraform | 本示例约束为 `>= 1.5.7, < 1.12.0`；已验证版本为 `1.5.7` |

本示例未声明 Provider 约束。可选的 Plan 转换与预算门禁脚本另外需要 Python 3.9+，并保持 `decimal_json.py` 与两个脚本位于同一目录。

## 4. Providers

| 名称 | 来源 |
|---|---|
| None | 无 Provider 配置或传递 |

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.pricing` | 通过 `source = "terraform-volcenginecc-modules/pricing/volcenginecc"` 调用 Registry 模块，用于多项成本、折扣与预算计算。 |

本示例 root 没有直接声明 Resource 或 Data Source，也不建立通知渠道。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `currency` | `string`，默认 `"CNY"`。所有单价和预算的币种，要求三个大写字母；不执行换汇。 |
| `region` | `string`，默认 `"cn-beijing"`。所有单价所属地域，不能为空或纯空白；不自动查询地域价格。 |
| `price_source` | `string`，必填且非空。填写报价或价格目录来源，建议记录版本和日期。 |
| `monthly_hours` | `number`，默认 730，范围为 0–744。仅用于按小时计费的项。 |
| `reserved_instance_discount_rate` | `number`，默认 0，范围为 0–1。`0.20` 表示减价 20%，仅作用于 `reserved_eligible = true` 的项。 |
| `output_format` | `string`，默认 `"json"`，可选 `json`、`csv`、`text`。只改变 `formatted_report`。 |
| `budget_thresholds` | 含可选 `monthly`、`annual` 数值的对象，默认 `{}`。阈值均应非负，省略或 `null` 关闭对应周期，0 为有效预算。 |
| `cost_items` | 必填的计费项 map，允许 `{}` 表示零费用。每项需填写对象标识、计费单位及单价；子字段和计算规则见下文。 |

每个 `cost_items` 项的完整类型如下：

```hcl
object({
  resource_address  = string
  unit              = string
  unit_price        = number
  quantity          = optional(number, 1)
  monthly_usage     = optional(number)
  reserved_eligible = optional(bool, false)
})
```

key 和 `resource_address` 均不能为空或纯空白。对象标识可为资源 ID、Terraform 地址或业务标识，同一对象的不同收费维度分别建项。`unit` 为 `hourly`、`monthly` 或 `usage`；单价、数量均为非负数。`quantity` 与单价单位匹配，默认 1；`reserved_eligible` 默认 `false`。

小时项月费 = 单价 × 数量 × 小时数，月度项月费 = 单价 × 数量，用量项月费 = 单价 × 数量 × `monthly_usage`。用量项必须提供非负 `monthly_usage`，其他项省略或设为 `null`。符合条件的项再乘以 `1 - reserved_instance_discount_rate`；年费为月费 × 12。已包含优惠的报价避免重复打折。

根模块对有默认值的变量传入 `null` 时采用默认值；本示例的 `cost_items` 无默认值，应传入明确的 map，`price_source` 也必须提供非空字符串。

## 7. 输出

| 名称 | 说明 |
|---|---|
| `report` | 完整成本对象，包含币种、地域、报价来源、小时数、折扣参数、逐项费用、总费用和预算信息，适合核对预测依据。 |
| `formatted_report` | 按 `output_format` 输出的字符串。JSON 包含完整报告，适合保留高精度金额；CSV 为明细与 TOTAL 行，text 展示费用、来源和预算状态。 |
| `alert_payload` | 预算事件对象，包含 `event = "cost_budget_forecast"`、币种、地域、汇总 `exceeded` 和 `budgets.monthly`、`budgets.annual`，供 CI 或通知程序读取。 |

每个周期包含 `threshold`、`forecast`、`exceeded`；关闭周期的阈值为 `null`、状态为 `false`。预测严格大于阈值才告警，等额不告警。CSV 和 text 金额展示两位小数，不影响预算比较。

三个输出在 Plan 阶段可见；Apply 后可使用 `terraform output` 读取。需要高精度金额时读取 JSON 格式的 `formatted_report`，并使用支持十进制数的解析器，避免普通双精度浮点解析产生舍入。

## 8. 示例

本目录即为 complete 示例，适合组合计算、存储和流量等收费维度，检查折扣和两个预算周期，或接入 Plan 转换与 CI 门禁。basic 示例只估算一个小时计费项。

## 9. 说明

本示例无需 Provider 认证或 AK/SK 凭据。若先生成其他工作负载的 Plan 或查询报价，凭据通过对应 Provider 或查询工具支持的运行环境传入。

Apply 后再次执行 `terraform plan`，无变化才满足幂等要求。修改费用参数或预算只更新输出；Destroy 清除本示例的状态输出，已有云资源和调用方的通知渠道继续保留，也无需 Import。

币种和地域只标识调用方提供的报价，不校验价格归属或换汇。`monthly_usage` 应是适合预测月份的用量；将月内已用流量直接当作整月用量会影响预测。年度结果假设十二个相同月份，模块不核对实际账单或自动查询价格。

`scripts/plan_to_tfvars.py` 可选，用显式价格目录将工作负载 Plan 转换为 `currency`、`region`、`price_source` 和 `cost_items`。该转换覆盖变更后的全部计划 managed 资源，不限于发生变更的对象。调用方还需单独配置小时数、折扣、预算和格式；使用生成的 JSON 输入时，避免与 `terraform.tfvars` 中同名值重复。价格目录、地址映射和用量要求见根 README 第 9 节。

门禁预算内退出 0、超预算退出 2，读取错误、缺失或未知输出、敏感输出及错误或不完整 Plan 等可检测错误退出 1。它仅检查所需输出和 `exceeded` 布尔值，不完整校验事件结构；通知发送及送达检查由调用方负责。

费用计算、多币种标识、折扣与月度、年度预算边界已使用 Terraform 1.5.7 验证。报价、资源标识、Plan JSON、State 和事件文件应保存在工程外并控制访问。
