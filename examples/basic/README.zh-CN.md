# BASIC 成本估算 示例

## 1. 概述

本示例估算一个按小时计费的对象，输出月度、年度成本报告。调用方提供对象标识、小时单价和报价来源，无需准备 Provider、凭据或前置云资源。示例固定使用每月 730 小时和数量 1，不配置折扣或预算阈值；需要组合计费项、调整小时数或检查预算时，使用 complete 示例。

## 2. 用法

先准备 Terraform 1.5.7 和对象的小时报价，确认报价币种与地域一致。本示例直接调用 Registry 中的成本估算模块，执行 `terraform init` 时下载模块。

在 `examples/basic/terraform.tfvars` 填写参数。以下是演示输入，单价不是实际云产品报价：

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

Terraform 自动读取该目录的 `terraform.tfvars`。首次 Plan 的 `report` 应显示月费 730 CNY、年费 8760 CNY，两个预算周期均未启用，不创建云资源。Apply 只保存输出到 State；保持输入与源码不变，再次 Plan 应无变化。`-detailed-exitcode` 返回 0 表示无变化、1 表示执行错误、2 表示有变化。确认状态属于本示例后执行 Destroy，它只清除保存的输出。

## 3. 依赖要求

| 名称 | 版本 |
|---|---|
| Terraform | 本示例约束为 `>= 1.5.7, < 1.12.0`；已验证版本为 `1.5.7` |

本示例没有 Provider 版本约束，也不依赖 Python。

## 4. Providers

| 名称 | 来源 |
|---|---|
| None | 无 Provider 配置或传递 |

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.pricing` | 通过 `source = "terraform-volcenginecc-modules/pricing/volcenginecc"` 调用 Registry 模块，用于单项小时费用估算。 |

本示例 root 没有直接声明 Resource 或 Data Source，传入的对象标识不建立资源管理关系。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `currency` | `string`，默认 `"CNY"`。填写报价币种，要求三个大写字母；不执行换汇。 |
| `region` | `string`，默认 `"cn-beijing"`。填写报价所属地域，不能为空或纯空白；不会自动查询该地域价格。 |
| `price_source` | `string`，必填且非空。填写报价来源，建议包含版本和日期。 |
| `resource_address` | `string`，必填且非空。填写资源 ID、Terraform 地址或业务标识，用于报告中的 `compute` 项；模块不会管理该对象。 |
| `hourly_unit_price` | `number`，必填且非负。填写单个对象每小时的单价，单位与 `currency` 一致。 |

本示例使用根模块的默认 `monthly_hours = 730`、`quantity = 1`、折扣率 0 和空预算。月费 = `hourly_unit_price × 730`，年费 = 月费 × 12。`currency`、`region` 传入 `null` 时由根模块采用默认值；其他三个必填输入应提供明确值。

## 7. 输出

| 名称 | 说明 |
|---|---|
| `report` | 完整成本对象，包含币种、地域、报价来源、730 小时假设、`compute` 明细、月费、年费及未启用的预算信息。可在 Plan 阶段查看，Apply 后可通过 `terraform output -json report` 读取。 |

本示例只暴露 `report`。即使单价为 0，报告仍包含 `compute` 项，月费和年费为 0。

## 8. 示例

本目录即为 basic 示例，适合核对单个对象的小时单价和月度、年度计算。complete 示例增加多计费项、折扣、预算和可选的 CI 门禁集成。

## 9. 说明

本示例无需 Provider 认证或 AK/SK 凭据。如果自行查询报价，认证由查询工具的运行环境提供；报价凭据不应写入估算参数。

Apply 后再次执行 `terraform plan`，结果无变化才满足幂等要求。修改单价、对象标识或报价来源只更新报告；Destroy 清除本示例的状态输出，已有云资源继续保留，也无需 Import。

730 小时是代表月份的预测假设，年费假设十二个相同月份。估算不会查询实时价格或核对实际账单，报价或配置变化后应更新输入。

单项费用计算已使用 Terraform 1.5.7 验证。报价、对象标识及导出的 Plan、State 可能包含敏感业务信息，应保存在工程外并控制访问。
