# terraform-volcenginecc-pricing

根据调用方提供的单价和用量，在 Terraform Plan 阶段输出月度、年度成本报告及预算评估结果。

## 1. 概述（Overview）

本模块适合在部署前估算成本，或在 CI 中检查预算。调用方提供计算、存储、流量等计费项的单价、数量和用量，模块汇总月度与年度费用，对符合条件的项应用折扣，并生成预算事件。可直接配置计费项，也可用配套脚本从工作负载 Plan JSON 转换输入。模块只计算和输出数据，无 Provider 依赖，不创建云资源、不自动询价或发送通知。

## 2. 用法（Usage）

准备 Terraform 1.5.7，以及同一币种、同一地域的单价和报价来源。本模块无需 Provider 配置、认证凭据或前置云资源；`resource_address` 用于标识报告中的对象，可填写资源 ID、Terraform 地址或清楚的业务标识。

在 `examples/basic` 中，通过以下配置调用 Registry 中的成本估算模块。`terraform init` 会下载模块：

```hcl
module "pricing" {
  source = "terraform-volcenginecc-modules/pricing/volcenginecc"

  currency     = var.currency
  region       = var.region
  price_source = var.price_source
  cost_items = {
    compute = {
      resource_address = var.resource_address
      unit             = "hourly"
      unit_price       = var.hourly_unit_price
    }
  }
}
```

在 `examples/basic/terraform.tfvars` 中填写输入。以下单价仅用于演示计算，请按自己的报价替换：

```hcl
currency          = "CNY"
region            = "cn-beijing"
price_source      = "illustrative rates; not a vendor quote"
resource_address  = "compute"
hourly_unit_price = 1
```

在 `examples/basic` 目录依次执行：

```shell
terraform init -backend=false
terraform plan -input=false
terraform apply
terraform plan -input=false -detailed-exitcode
terraform destroy
```

首次 Plan 的 `report` 输出展示成本报告。上述输入按默认每月 730 小时计算，月费为 730 CNY，年费为 8760 CNY。Apply 将输出保存到 State；输入和源码不变时，第二次 Plan 应无变化。`-detailed-exitcode` 的退出码为：0 无变化、1 执行错误、2 有变化。Destroy 移除 State 中的输出，已有云资源继续保留。

## 3. 示例（Examples）

- basic：估算一个按小时计费的对象，只需单价、对象标识和报价来源；固定使用默认的 730 小时、数量 1，不应用折扣或预算阈值，输出 `report`。
- complete：组合多个计费项，可配置币种、地域、小时数、折扣、输出格式及月度和年度预算，输出 `report`、`formatted_report`、`alert_payload`；可接收配套转换脚本生成的输入并接入 CI 门禁。

两个示例均无需前置云资源或 Provider。估算已有资源时，由调用方查询报价并准备适合预测月份的用量。

## 4. 版本要求（Requirements）

| 名称 | 版本 |
|---|---|
| Terraform | 源码约束为 `>= 1.5.7, < 1.12.0`；已验证版本为 `1.5.7` |
| Python | 可选脚本要求 `3.9+` |

未逐一验证 Terraform 允许范围内的全部版本。Python 仅用于 `scripts/plan_to_tfvars.py` 和 `scripts/budget_gate.py`，模块计算不依赖 Python。

## 5. Providers（Providers）

| 名称 | 来源 |
|---|---|
| None | 无 Provider 依赖 |

模块未声明或传递 Provider，也没有 Provider alias。若用脚本处理其他工作负载的 Plan，其 Provider 认证和 Plan 生成由工作负载的调用方负责。

## 6. 资源（Resources）

| 模式 | 类型 | 名称 |
|---|---|---|
| 无资源操作 | 无 Resource 或 Data Source | None |

模块通过表达式计算结果，不管理 `cost_items` 中标识的对象。

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 创建模式下是否必填 | 说明 |
|---|---|---|---|---|
| `currency` | `string` | `"CNY"` | 否 | 三个大写字母的币种代码；单价和预算都应使用该币种。修改它只改变报告标识，不换汇。 |
| `region` | `string` | `"cn-beijing"` | 否 | 单价所属地域，不能为空或纯空白；修改它不触发自动询价。不同地域分别调用模块。 |
| `price_source` | `string` | 无 | 是 | 非空报价来源，建议记录报价或价格目录的版本与日期，便于核对估算依据。 |
| `monthly_hours` | `number` | `730` | 否 | 代表月份的运行小时，范围为 0–744，仅影响 `hourly` 计费项。 |
| `reserved_instance_discount_rate` | `number` | `0` | 否 | 节省比例，范围为 0–1；`0.30` 表示减价 30%，仅作用于 `reserved_eligible = true` 的项。 |
| `output_format` | `string` | `"json"` | 否 | 可选 `json`、`csv`、`text`，仅改变 `formatted_report` 的格式。 |
| `budget_thresholds` | `object({ monthly = optional(number), annual = optional(number) })` | `{}` | 否 | 月度、年度阈值均为非负数；省略或 `null` 关闭对应周期，0 是有效预算。 |
| `cost_items` | `map(object({ resource_address = string, unit = string, unit_price = number, quantity = optional(number, 1), monthly_usage = optional(number), reserved_eligible = optional(bool, false) }))` | `{}` | 否 | 稳定 key 标识计费项；空 map 的费用为 0。各子字段约束及计算规则见下文。 |

表头沿用统一文档格式；本模块只有估算用途，没有创建模式。所有根变量均声明 `nullable = false`：有默认值的变量传入 `null` 时使用默认值，`price_source` 必须提供非空字符串。

`cost_items` 的 key 和 `resource_address` 均不能为空或纯空白。`unit` 必须为 `hourly`、`monthly` 或 `usage`，`unit_price` 和 `quantity` 均为非负数。`usage` 必须设置非负的 `monthly_usage`；其他单位省略该字段或设为 `null`。`quantity` 默认 1，`reserved_eligible` 默认 `false`。同一对象的不同收费维度应分别建项，例如实例费用、磁盘费用和流量费用。

每项费用按以下规则计算：

- `hourly`：月费 = 单价 × 数量 × `monthly_hours`。
- `monthly`：月费 = 单价 × 数量。
- `usage`：月费 = 单价 × 数量 × `monthly_usage`。

符合折扣条件的项，再将月费乘以 `1 - reserved_instance_discount_rate`；年费为月费 × 12。数量的单位应与单价匹配，例如按 GiB 收费时填写容量。零单价由调用方明确提供；已包含优惠的报价应避免重复打折。

## 8. 输出（Outputs）

| 名称 | 类型 | 说明 |
|---|---|---|
| `monthly_cost` | `number` | 未舍入的月度总费用；空计费项输入时为 0。 |
| `annual_cost` | `number` | 未舍入的年度总费用，等于月费 × 12。 |
| `item_costs` | `object`，按计费项 key 索引 | 每项的对象标识、单价、数量、用量、实际折扣率及月度、年度费用；空输入时为空对象。 |
| `budget_exceeded` | `bool` | 任一已启用周期的预测费用严格大于阈值时为 `true`，等额时为 `false`。 |
| `alert_payload` | `object` | 包含 `event`、`currency`、`region`、`exceeded`、`budgets`，供调用方的 CI 或通知程序读取。 |
| `report` | `object` | 完整报告，包含币种、地域、报价来源、小时数、折扣参数、总费用、`items`、`budgets` 和 `budget_exceeded`。 |
| `formatted_report` | `string` | 按 `output_format` 输出：JSON 为完整报告；CSV 为明细与 TOTAL 行；text 为费用、来源及预算状态。 |

`item_costs` 的每项包含 `resource_address`、`unit`、`unit_price`、`quantity`、`monthly_usage`、`discount_rate`、`monthly_cost`、`annual_cost`。非 `usage` 项的 `monthly_usage` 为 `null`，不符合折扣条件的项，其 `discount_rate` 为 0。

`budgets` 始终包含 `monthly` 和 `annual`，每个周期都有 `threshold`、`forecast`、`exceeded`；未启用时 `threshold` 为 `null`、`exceeded` 为 `false`。`alert_payload.event` 固定为 `cost_budget_forecast`，顶层 `exceeded` 汇总两个周期的结果。

CSV 和 text 将金额展示为两位小数，预算比较使用未舍入的费用。JSON 格式的 `formatted_report` 保留计算结果的十进制表示；读取高精度金额时，应使用支持十进制数的 JSON 解析器，普通双精度浮点解析可能产生舍入。

费用先按十进制整数系数计算，再转换为 Terraform 数值，避免连续小数运算造成等额预算误告警；精度仍受 Terraform 数值能力约束。

## 9. 其他说明（Notes）

模块不拥有云资源，没有创建、更新、替换或 Import 操作。修改单价、数量、用量和预算会重新计算输出；修改计费项 key 或对象标识只改变报告明细。Apply 后再次执行正常的 `terraform plan`，无变化才满足幂等要求。Destroy 清除该调用的状态输出，不删除报告中标识的资源。

币种与地域是输入约定，模块不会检查报价是否属于该币种、地域或 SKU。年度预测假设十二个相同的代表月份，730 小时是预测参数。税费、阶梯价格、免费额度、汇率、一次性费用和真实预留资格需要调用方核实；变化的用量应由调用方换算成适合预测的输入。

可选的 `scripts/plan_to_tfvars.py` 接受含 `planned_values`、`format_version` 为 1.x 的工作负载 Plan JSON，支持缺省 `resource_changes` 的空 Plan。它遍历嵌套模块，使用完整 managed 实例地址匹配价格目录，估算变更后的全部计划资源，包含未变更资源。删除对象需同步移除目录映射；数据源不作为收费对象。

价格目录需包含 `currency`、`region`、`price_source`、`resources` 和 `rates`。`resources` 按完整地址映射收费维度，每个维度用 `rate_key` 引用单价，并且只选择 `quantity` 或 `quantity_path` 之一；后者用属性名、数组索引组成的非空路径读取已知数量。`rates` 提供 `unit`、`unit_price` 和可选的 `reserved_eligible`；`usage` 维度另需 `monthly_usage`。不估算的资源在 `ignored_resources` 中填写排除原因。脚本拒绝遗漏或过期的地址映射、未知数量及错误或不完整的 Plan；地址覆盖不能证明收费维度和单价正确。

两个脚本都需要同目录的 `decimal_json.py`。以下命令在仓库根目录执行；先在工程外准备工作负载 Plan JSON、价格目录，并将生成的输入用于 complete 调用。路径中的文件由调用方准备：

```shell
python3 scripts/plan_to_tfvars.py --plan /tmp/成本估算/工作负载.json --catalog /tmp/成本估算/价格目录.json > /tmp/成本估算/成本输入.tfvars.json
```

`scripts/budget_gate.py` 读取估算 Plan JSON 中的 `alert_payload` 并输出事件，预算内退出 0，超预算退出 2。文件或 JSON 读取失败、Plan 标记为错误或不完整、输出缺失、标记为敏感或 `exceeded` 不是布尔值时退出 1；它不完整校验事件结构，也不发送通知。complete 示例说明了保存估算 Plan 和运行门禁的方法。

费用计算、多币种标识、折扣与预算边界已使用 Terraform 1.5.7 验证。报告、Plan JSON 和 State 可能包含资源标识与协议单价，应保存在工程外并控制访问。
