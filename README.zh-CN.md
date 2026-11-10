# terraform-volcenginecc-pricing

使用调用方提供的单价，对 Terraform 计划进行月度、年度成本估算和预算告警评估，无 Provider 依赖。

## 1. 概述（Overview）

本工具不拥有资源、数据源或通知渠道。可直接传入计费项，或使用 `scripts/plan_to_tfvars.py` 和显式价格目录转换已保存的工作负载 Plan JSON。预测覆盖变更后的全部计划资源，包括未变更资源，不是仅针对本次变更的成本差额。删除的资源不在 planned values 中，需同步移除价格目录中的地址映射。

| 分类 | 能力 | 实现 | 边界 |
|---|---|---|---|
| core | 月度、年度预测 | cost_items、monthly_cost、annual_cost | 调用方提供的线性单价 |
| core | 币种与区域 | currency、region | 元数据；不换汇、不自动查询价格 |
| core | 预留折扣 | reserved_instance_discount_rate | 仅作用于符合条件的计费项 |
| core | 格式与预算 | output_format、budget_thresholds | 结构化事件，不发送消息 |
| complete/recommended | Plan 映射与 CI 门禁 | Python 脚本、complete 示例 | 显式覆盖、用量已知 |
| deferred | 实时查询价格、账单核对 | 无 | 尚未集成权威价格 API |

AWS 参考：[AWS pricing product 数据源](https://registry.terraform.io/providers/hashicorp/aws/6.0.0/docs/data-sources/pricing_product) 按配置过滤唯一产品。本模块参考显式选择产品单价的方式，并补充计算和预算评估。用户未指定具体 AWS pricing 模块仓库，不宣称与未确定的模块兼容。

## 2. 用法（Usage）

通过调用方变量提供实际价格和来源：

```hcl
module "pricing" {
  source = "terraform-volcenginecc-modules/pricing/volcenginecc"

  currency     = "CNY"
  region       = "cn-beijing"
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

本工具无需 Provider 认证。工作负载的 Provider 认证、地域、Plan 生成和 backend 由调用方负责。Registry 发布与消费尚未验证；示例保留预期 source，不编造发布版本。本地验证仅在临时副本中改写 source。

## 3. 示例（Examples）

- basic：单个按小时计费的资源，由调用方提供真实报价，输出月度、年度预测。
- complete：计算、存储和流量计费项；覆盖币种、区域、折扣、运行小时、输出格式、月度/年度预算及 CI 告警集成，可接收 Plan 转换后的计费项。

## 4. 版本要求（Requirements）

| 工具 | 约束 / 验证基线 |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0`；基线 1.5.7 |
| OpenTofu | 共用配置；基线 1.11.8 |
| Python | 可选转换和 CI 脚本要求 3.9+ |
| Provider | 无，不适用 Provider Schema/版本校验 |

未逐一验证允许范围内的全部版本。已在隔离模块副本中使用 Terraform 1.5.7 执行 basic、complete 的 plan、apply、二次 plan 和 destroy；二次 plan 均无变更，未创建云资源。OpenTofu 1.11.8 已通过静态配置检查。

## 5. Providers（Providers）

| 名称 | 来源 | 版本 |
|---|---|---|
| 无 | 无 | 不适用 |

## 6. 资源（Resources）

| 模式 | 类型 | 职责 |
|---|---|---|
| 无 | 无 | 仅表达式和输出，无资源生命周期 |

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 必填条件 / 含义 |
|---|---|---|---|
| `currency` | `string` | `"CNY"` | 三个大写字母；所有单价与预算必须使用该币种 |
| `region` | `string` | `"cn-beijing"` | 非空价格目录地域；不同地域/币种分别调用模块 |
| `price_source` | `string` | 无 | 必填，非空报价/目录来源、版本及日期 |
| `monthly_hours` | `number` | `730` | 0–744，代表月份的运行小时 |
| `reserved_instance_discount_rate` | `number` | `0` | 0–1 节省比例；0.30 表示减价 30% |
| `output_format` | `string` | `"json"` | json、csv 或 text |
| `budget_thresholds` | `object({monthly=optional(number),annual=optional(number)})` | `{}` | 非负阈值；null 关闭该周期，零是有效预算 |
| `cost_items` | `map(object({resource_address=string,unit=string,unit_price=number,quantity=optional(number,1),monthly_usage=optional(number),reserved_eligible=optional(bool,false)}))` | `{}` | 稳定 key 标识计费项，不表示 Terraform 资源所有权 |

根模块输入不可为 null；有默认值的字段显式传入 null 时采用默认值，price_source 必须提供。计费项 key 和地址非空，价格与数量非负。`unit` 为 hourly、monthly 或 usage。usage 必须设置非负 `monthly_usage`，其他单位必须省略此字段。quantity 为乘数：hourly = 单价 × 数量 × monthly_hours；monthly = 单价 × 数量；usage = 单价 × 数量 × monthly_usage。同一资源的不同计费维度分别建项。零单价必须由调用方显式确定。

## 8. 输出（Outputs）

| 名称 | 类型 | 含义 |
|---|---|---|
| `monthly_cost` | `number` | 未舍入的月度持续费用；空输入为零 |
| `annual_cost` | `number` | 月度总额 × 12 |
| `item_costs` | `map(object)` | 地址、unit、unit_price、quantity、可为 null 的 monthly_usage、实际 discount_rate、monthly_cost、annual_cost |
| `budget_exceeded` | `bool` | 任一已启用预算周期严格超出阈值 |
| `alert_payload` | `object` | event、currency、region、exceeded、budgets；每项预算包含 threshold、forecast、exceeded |
| `report` | `object` | currency、region、price_source、monthly_hours、reserved_instance_discount_rate、总额、items、budgets、budget_exceeded |
| `formatted_report` | `string` | JSON：完整报告；CSV：计费项/地址/币种/区域/月度/年度与 TOTAL 行；文本：明细、总额、来源及预算状态 |

输出不含凭据，但地址、key 和协议价格可能具有商业敏感性，需控制导出 Plan 和报告的访问。CSV/文本金额仅展示两位小数，预算比较使用未舍入值。无论 output_format 如何选择，均可通过 `report` 或 `alert_payload` 获取完整预算信息。

费用先按十进制整数系数计算，再转换为 Terraform 数值，避免连续小数运算导致等额预算误告警。转换工具及 CI 事件输出保留 JSON 十进制数，不转换为二进制浮点数；精度仍受 Terraform 数值能力限制。

## 9. 其他说明（Notes）

费用等于预算时不告警。null 预算不告警；零预算对任意正费用告警。折扣仅作用于 `reserved_eligible=true` 的项，已折扣的报价应避免再次打折。年度预测假设十二个相同的代表月份。不推断税费、一次性/预付预留费用、汇率、阶梯价格、免费额度、时变用量或真实预留资格；必要时由调用方提供单独计算的有效单价/用量。

转换工具接受包含 `planned_values`、格式为 1.x 的 Plan JSON，支持省略 `resource_changes` 的空 Plan，递归处理嵌套计划模块，匹配完整 managed 实例地址（含 count/for_each 索引）。每个 managed 资源必须至少映射一个计费项，或在 `ignored_resources` 中注明排除原因。过期映射、缺少单价/数量、未完成 Plan 和未知数量均报错。数据源不作为收费对象。映射完整仅证明地址覆盖，不证明调用方覆盖所有收费维度或选择正确 SKU，需对照报价核实全部维度和价格。

没有创建、更新、替换或 import 行为；key 变化仅改变输出明细。预测离线运行；通知发送由调用方负责，`budget_gate.py` 仅输出通用 JSON 事件。Registry 发布尚未验证；已通过只读线上抢占式价格快照核对预测公式，尚未验证权威币种、真实预留折扣和官方账单。

工程来源：[Module 仓库规范](https://bytedance.larkoffice.com/docx/C3TZdz2lnoAZmDxC7zRcOSgzn4d) 第 5.3、5.5 节，revision 2645，读取日期 2026-11-05。本地未找到 PRD/工程规范文件，以用户提供的场景作为能力合同。
