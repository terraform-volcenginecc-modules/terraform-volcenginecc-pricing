# COMPLETE Cost Estimation Example

## 1. Overview

This example combines compute, storage, traffic or other charge components and outputs cost reports and monthly and annual budget events. Compared with basic, it supports configurable hours, discounts, thresholds and formats, plus workload Plan conversion and a CI gate. Callers supply prices and forecast usage for one currency and region. No provider, credentials, prerequisite cloud resources or notification channels are needed.

## 2. Usage

Prepare Terraform 1.5.7, prices for each billing dimension, quantities, forecast usage and budgets. This example calls the cost estimation module directly from the Registry; `terraform init` downloads it.

Set inputs in `examples/complete/terraform.tfvars`. These prices and budgets illustrate the calculation in CNY and are not cloud product quotes:

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

Run these commands in the `examples/complete` directory:

```shell
terraform init -backend=false
terraform plan -input=false -out=估算.tfplan
terraform apply 估算.tfplan
terraform plan -input=false -detailed-exitcode
terraform destroy
```

The first Plan should expose `report`, `formatted_report` and `alert_payload`, without cloud resource creation. Monthly costs are `1 × 730 × (1 - 0.20) = 584` for compute, `2 × 20 = 40` for storage, and `0.5 × 100 = 50` for traffic. The total is 674 CNY per month and 8088 CNY per year. Monthly cost exceeds 650, so its alert is `true`. Annual cost is below 10000, so its alert is `false`. The top-level `exceeded` is `true`.

Apply saves outputs to State. Keep inputs and code unchanged; the second Plan should show no changes. `-detailed-exitcode` returns 0 for no changes, 1 for an error, and 2 for changes. Confirm that the State belongs to this example before Destroy, which clears only stored outputs.

To check the CI gate, export the saved Plan as JSON after the first Plan and before Destroy:

```shell
terraform show -json 估算.tfplan > 估算.json
python3 ../../scripts/budget_gate.py 估算.json
```

With the demonstration inputs, the gate emits a `cost_budget_forecast` event and exits 2. To check equal budgets, set the monthly threshold to 674 and annual threshold to 8088, save a new Plan, export JSON and rerun the gate. Neither period should exceed its threshold, and the gate should exit 0. Budget changes alter outputs; after applying the updated configuration, rerun Plan to check idempotence. The gate emits events, and callers implement notification delivery.

## 3. Requirements

| Name | Version |
|---|---|
| Terraform | Example constraint: `>= 1.5.7, < 1.12.0`; verified version: `1.5.7` |

The example declares no provider constraints. Optional Plan conversion and budget gate scripts additionally require Python 3.9+, with `decimal_json.py` beside both scripts.

## 4. Providers

| Name | Source |
|---|---|
| None | No provider configuration or passing |

## 5. Resources

| Name | Description |
|---|---|
| `module.pricing` | Calls the Registry module with `source = "terraform-volcenginecc-modules/pricing/volcenginecc"` for multiple costs, discounts and budgets. |

The example root declares no Resource or Data Source and creates no notification channels.

## 6. Inputs

| Name | Description |
|---|---|
| `currency` | `string`, default `"CNY"`. Currency of all prices and budgets, expressed as three uppercase letters; no currency conversion is performed. |
| `region` | `string`, default `"cn-beijing"`. Nonblank region for all prices; no automatic regional price lookup. |
| `price_source` | Required nonblank `string`. Quote or catalog provenance, preferably with version and date. |
| `monthly_hours` | `number`, default 730, from 0 to 744. Used only by hourly components. |
| `reserved_instance_discount_rate` | `number`, default 0, from 0 to 1. `0.20` means 20% off, applied only to items with `reserved_eligible = true`. |
| `output_format` | `string`, default `"json"`; `json`, `csv` or `text`. Changes only `formatted_report`. |
| `budget_thresholds` | Object with optional numeric `monthly` and `annual` fields, default `{}`. Thresholds must be nonnegative. Omission or `null` disables a period; 0 is a valid budget. |
| `cost_items` | Required map of charge components; `{}` represents zero cost. Each item needs an identifier, billing unit and price. Nested fields and calculations follow below. |

Each `cost_items` entry has this full type:

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

Keys and `resource_address` must be nonblank. Identifiers can be resource IDs, Terraform addresses or business labels. Model separate billing dimensions for one object as separate items. `unit` is `hourly`, `monthly` or `usage`; prices and quantities are nonnegative. `quantity` must match the rate's unit and defaults to 1; `reserved_eligible` defaults to `false`.

Hourly monthly cost = price × quantity × hours; monthly cost for monthly units = price × quantity; usage cost = price × quantity × `monthly_usage`. Usage components require nonnegative `monthly_usage`; other components omit it or set it to `null`. Eligible costs are multiplied by `1 - reserved_instance_discount_rate`; annual cost is monthly cost × 12. Avoid applying another discount to already discounted quotes.

For root variables with defaults, explicit `null` selects the default. This example has no default for `cost_items`, so provide an explicit map; `price_source` also requires a nonblank string.

## 7. Outputs

| Name | Description |
|---|---|
| `report` | Full cost object with currency, region, provenance, hours, discount settings, item costs, totals and budgets, for checking forecast assumptions. |
| `formatted_report` | String in the selected format. JSON contains the full report and preserves high-precision amounts; CSV contains item and TOTAL rows; text displays costs, provenance and budget status. |
| `alert_payload` | Budget event object with `event = "cost_budget_forecast"`, currency, region, combined `exceeded`, and `budgets.monthly` and `budgets.annual`, for CI or notification programs. |

Each period contains `threshold`, `forecast` and `exceeded`. Disabled periods have a `null` threshold and `false` status. Alerts require the forecast to strictly exceed the threshold; equality does not alert. CSV and text display two decimal places without affecting budget comparisons.

All three outputs are visible during Plan and can be read with `terraform output` after Apply. For high-precision amounts, read JSON `formatted_report` with a decimal-aware parser to avoid rounding from ordinary double-precision parsing.

## 8. Example

This directory is the complete example. Use it to combine compute, storage and traffic dimensions, check discounts and both budget periods, or integrate Plan conversion and a CI gate. The basic example estimates only one hourly component.

## 9. Notes

This example needs no provider authentication or AK/SK credentials. When generating another workload's Plan or obtaining quotes, supply credentials through the relevant provider or query tool's supported runtime environment.

After Apply, run `terraform plan` again; no changes are required for idempotence. Changes to cost settings or budgets update only outputs. Destroy clears this example's stored outputs while preserving existing cloud resources and caller-owned notification channels. Import is unnecessary.

Currency and region identify caller-supplied quotes without verifying price ownership or converting currencies. `monthly_usage` should represent the forecast month; using month-to-date traffic as full-month usage affects the forecast. Annual results assume twelve identical months. The module neither reconciles bills nor fetches prices automatically.

The optional `scripts/plan_to_tfvars.py` uses an explicit catalog to convert a workload Plan into `currency`, `region`, `price_source` and `cost_items`. It covers all planned managed resources after changes, including unchanged objects. Callers separately configure hours, discounts, budgets and format. When using generated JSON inputs, avoid duplicate values for the same variables in `terraform.tfvars`. Root README section 9 describes catalog, address mapping and usage requirements.

The gate exits 0 within budget and 2 over budget. Detectable errors such as read failures, missing or unknown outputs, sensitive outputs, or errored or incomplete Plans return 1. It checks the required output and boolean `exceeded`, without validating the full event schema. Callers handle notification delivery and delivery verification.

Cost calculations, multiple currency labels, discounts, and monthly and annual budget boundaries were verified with Terraform 1.5.7. Keep quotes, resource identifiers, Plan JSON, State and event files outside the source tree with controlled access.
