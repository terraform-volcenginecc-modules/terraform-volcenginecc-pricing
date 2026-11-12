# terraform-volcenginecc-pricing

Produce monthly and annual cost reports and budget evaluations during Terraform Plan using caller-supplied prices and usage.

## 1. Overview

This module estimates costs before deployment and supports CI budget checks. Callers supply prices, quantities and usage for compute, storage, traffic or other charge components. The module totals monthly and annual costs, applies eligible discounts and produces budget events. Inputs can be configured directly or converted from workload plan JSON with the bundled script. It has no provider dependency and does not create cloud resources, fetch prices or send notifications.

## 2. Usage

Prepare Terraform 1.5.7 and prices with provenance for one currency and region. This module needs no provider configuration, authentication credentials or prerequisite cloud resources. `resource_address` identifies an object in the report and can be a resource ID, Terraform address or clear business label.

In `examples/basic`, the following configuration calls the cost estimation module from the Registry. `terraform init` downloads the module:

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

Set inputs in `examples/basic/terraform.tfvars`. This price illustrates the calculation; replace it with your own quote:

```hcl
currency          = "CNY"
region            = "cn-beijing"
price_source      = "illustrative rates; not a vendor quote"
resource_address  = "compute"
hourly_unit_price = 1
```

Run these commands in the `examples/basic` directory:

```shell
terraform init -backend=false
terraform plan -input=false
terraform apply
terraform plan -input=false -detailed-exitcode
terraform destroy
```

The first Plan displays the cost report in `report`. With the default 730 hours per month, these inputs yield 730 CNY per month and 8760 CNY per year. Apply saves outputs to State. With unchanged inputs and code, the second Plan should show no changes. `-detailed-exitcode` returns 0 for no changes, 1 for an error, and 2 for changes. Destroy removes outputs from State and preserves existing cloud resources.

## 3. Examples

- basic: estimate one hourly object from a price, object identifier and quote provenance. It uses the default 730 hours and quantity 1, with no discount or budget thresholds, and exposes `report`.
- complete: combine multiple charge components and configure currency, region, hours, discount, output format, and monthly and annual budgets. It exposes `report`, `formatted_report` and `alert_payload`, accepts inputs from the conversion script, and supports a CI budget gate.

Neither example requires cloud resources or a provider. When estimating existing resources, callers obtain prices and prepare usage appropriate for the forecast month.

## 4. Requirements

| Name | Version |
|---|---|
| Terraform | Source constraint: `>= 1.5.7, < 1.12.0`; verified version: `1.5.7` |
| Python | `3.9+` for optional scripts |

Not every Terraform version in the allowed range has been verified. Python is used only by `scripts/plan_to_tfvars.py` and `scripts/budget_gate.py`; module calculations do not depend on it.

## 5. Providers

| Name | Source |
|---|---|
| None | No provider dependency |

The module declares and passes no providers and has no provider aliases. When processing another workload's Plan, its caller remains responsible for provider authentication and plan generation.

## 6. Resources

| Mode | Type | Name |
|---|---|---|
| No resource operations | No Resource or Data Source | None |

The module calculates results through expressions and does not manage objects identified in `cost_items`.

## 7. Inputs

| Name | Type | Default | Required in create mode | Description |
|---|---|---|---|---|
| `currency` | `string` | `"CNY"` | No | Three uppercase letters. Prices and budgets must use this currency. Changing it updates report metadata without currency conversion. |
| `region` | `string` | `"cn-beijing"` | No | Region of the prices; cannot be empty or whitespace. Changing it does not fetch prices. Use separate calls for different regions. |
| `price_source` | `string` | None | Yes | Nonblank quote provenance; include the quote or catalog version and date to make the estimate traceable. |
| `monthly_hours` | `number` | `730` | No | Operating hours for a representative month, from 0 to 744; affects only `hourly` components. |
| `reserved_instance_discount_rate` | `number` | `0` | No | Fraction saved, from 0 to 1. `0.30` means 30% off, applied only to items with `reserved_eligible = true`. |
| `output_format` | `string` | `"json"` | No | `json`, `csv` or `text`; changes only the format of `formatted_report`. |
| `budget_thresholds` | `object({ monthly = optional(number), annual = optional(number) })` | `{}` | No | Nonnegative monthly and annual thresholds. Omission or `null` disables a period; 0 is a valid budget. |
| `cost_items` | `map(object({ resource_address = string, unit = string, unit_price = number, quantity = optional(number, 1), monthly_usage = optional(number), reserved_eligible = optional(bool, false) }))` | `{}` | No | Stable keys identify charge components. An empty map yields zero cost. Nested constraints and calculations follow below. |

The table uses the standard documentation header; this module estimates costs and has no create mode. All root variables declare `nullable = false`: explicit `null` selects a default where one exists, and `price_source` requires a nonblank string.

Each `cost_items` key and `resource_address` must be nonblank. `unit` must be `hourly`, `monthly` or `usage`; `unit_price` and `quantity` must be nonnegative. `usage` requires nonnegative `monthly_usage`; other units must omit it or set it to `null`. `quantity` defaults to 1 and `reserved_eligible` to `false`. Model separate billing dimensions as separate items, such as instance, disk and traffic charges for the same object.

Costs are calculated per item:

- `hourly`: monthly cost = price × quantity × `monthly_hours`.
- `monthly`: monthly cost = price × quantity.
- `usage`: monthly cost = price × quantity × `monthly_usage`.

For eligible items, multiply the monthly cost by `1 - reserved_instance_discount_rate`. Annual cost is monthly cost × 12. Quantity units must match the price, such as capacity for a per-GiB rate. Zero prices are explicit caller inputs; avoid applying another discount to an already discounted quote.

## 8. Outputs

| Name | Type | Description |
|---|---|---|
| `monthly_cost` | `number` | Unrounded monthly total; 0 for empty charge input. |
| `annual_cost` | `number` | Unrounded annual total, equal to monthly cost × 12. |
| `item_costs` | `object`, indexed by charge key | Object identifier, rate, quantity, usage, applied discount, and monthly and annual costs per item; empty object for empty input. |
| `budget_exceeded` | `bool` | `true` when any enabled forecast strictly exceeds its threshold; equality returns `false`. |
| `alert_payload` | `object` | `event`, `currency`, `region`, `exceeded` and `budgets`, for caller-owned CI or notification programs. |
| `report` | `object` | Full report with currency, region, provenance, hours, discount setting, totals, `items`, `budgets` and `budget_exceeded`. |
| `formatted_report` | `string` | Selected by `output_format`: full report for JSON, item and TOTAL rows for CSV, or costs, provenance and budget status for text. |

Each `item_costs` entry contains `resource_address`, `unit`, `unit_price`, `quantity`, `monthly_usage`, `discount_rate`, `monthly_cost` and `annual_cost`. `monthly_usage` is `null` for non-usage items; `discount_rate` is 0 for ineligible items.

`budgets` always contains `monthly` and `annual`, each with `threshold`, `forecast` and `exceeded`. Disabled periods have a `null` threshold and `false` exceeded status. `alert_payload.event` is always `cost_budget_forecast`; the top-level `exceeded` combines both period results.

CSV and text display monetary values to two decimal places; budget comparisons use unrounded costs. JSON `formatted_report` preserves the decimal representation of calculated values. Use a decimal-aware JSON parser for high-precision amounts; ordinary double-precision parsing may round them.

Costs are calculated with decimal integer coefficients before conversion to Terraform numbers, avoiding chained fractional errors at equal-budget boundaries. Precision remains subject to Terraform's numeric limits.

## 9. Notes

The module owns no cloud resources and has no create, update, replacement or Import operations. Changes to prices, quantities, usage or budgets recalculate outputs. Changes to charge keys or object identifiers update report rows. After Apply, run a normal `terraform plan`; no changes are required for idempotence. Destroy removes the call's stored outputs and preserves resources identified in the report.

Currency and region are caller conventions. The module does not verify that quotes match a currency, region or SKU. Annual forecasts assume twelve identical representative months, and 730 hours is an estimate parameter. Callers must account for taxes, tiered prices, free quotas, exchange rates, one-time charges and actual reservation eligibility, and convert variable usage into suitable forecast inputs.

The optional `scripts/plan_to_tfvars.py` accepts workload Plan JSON containing `planned_values` with `format_version` 1.x, including empty plans without `resource_changes`. It traverses nested modules and matches full managed instance addresses to the price catalog. The forecast covers all planned resources after changes, including unchanged resources. Remove catalog mappings for deleted objects. Data sources are not treated as chargeable objects.

The catalog requires `currency`, `region`, `price_source`, `resources` and `rates`. `resources` maps full addresses to charge components. Each component references a price with `rate_key` and specifies exactly one of `quantity` or `quantity_path`; the latter is a nonempty sequence of attribute keys and array indexes resolving to a known quantity. `rates` supplies `unit`, `unit_price` and optional `reserved_eligible`; usage components also require `monthly_usage`. Record exclusion reasons in `ignored_resources`. The script rejects missing or stale address mappings, unknown quantities, and errored or incomplete plans. Address coverage does not establish correct rates or complete billing dimensions.

Both scripts require `decimal_json.py` in the same directory. Run the following from the repository root after preparing the workload Plan JSON and catalog outside the source tree. Use the generated inputs in a complete call. The caller prepares the files at these paths:

```shell
python3 scripts/plan_to_tfvars.py --plan /tmp/成本估算/工作负载.json --catalog /tmp/成本估算/价格目录.json > /tmp/成本估算/成本输入.tfvars.json
```

`scripts/budget_gate.py` reads `alert_payload` from estimate Plan JSON and emits an event. It exits 0 within budget and 2 over budget. It exits 1 for file or JSON read errors, plans marked errored or incomplete, missing outputs, sensitive outputs, or a nonboolean `exceeded`. It does not validate the full event schema or send notifications. The complete example explains how to save an estimate Plan and run the gate.

Cost calculations, multiple currency labels, discounts and budget boundaries were verified with Terraform 1.5.7. Reports, Plan JSON and State may contain resource identifiers and negotiated prices; keep them outside the source tree with controlled access.
