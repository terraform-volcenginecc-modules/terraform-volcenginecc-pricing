# terraform-volcenginecc-pricing

Provider-free Terraform plan cost estimation with monthly/annual forecasts and budget events, using caller-supplied prices.

## 1. Overview

This tool owns no resources, data sources or notification channels. Supply charge components directly, or convert a saved workload plan JSON with `scripts/plan_to_tfvars.py` and an explicit price catalog. The forecast describes the entire planned workload after changes, including unchanged resources; it is not a change-only cost delta. Deleted resources are absent from planned values and must be removed from the catalog mapping.

| Classification | Capability | Implementation | Boundary |
|---|---|---|---|
| core | Monthly/annual forecast | cost_items, monthly_cost, annual_cost | Caller-supplied linear rates |
| core | Currency and region | currency, region | Metadata; no currency conversion or automatic price lookup |
| core | Reserved discount | reserved_instance_discount_rate | Only eligible components |
| core | Formats and budgets | output_format, budget_thresholds | Structured event, no message delivery |
| complete/recommended | Plan mapping and CI gate | Python scripts, complete example | Explicit coverage and known quantities |
| deferred | Live price lookup, billing reconciliation | None | No authoritative price API integration |

AWS reference: the [AWS pricing product data source](https://registry.terraform.io/providers/hashicorp/aws/6.0.0/docs/data-sources/pricing_product) selects a single product using configuration filters. This module follows explicit product/rate selection and adds arithmetic and budget evaluation. A specific AWS pricing module repository was not provided; no compatibility with an unidentified module is claimed.

## 2. Usage

Provide actual prices and their provenance through caller variables:

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

There is no provider authentication for this tool. Workload provider authentication, region, plan generation and backend remain caller-owned. Registry publication and Registry consumption are not verified; examples retain the intended source without a fabricated release version. Local validation rewrites sources in temporary copies.

## 3. Examples

- basic: one hourly resource with an actual caller-provided quote; reports monthly and annual costs.
- complete: compute, storage and traffic components; covers currency, region, discount, hours, output format, monthly/annual budgets and CI alert integration. Accepts a plan-derived component map.

## 4. Requirements

| Tool | Constraint / validation baseline |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0`; baseline 1.5.7 |
| OpenTofu | Same configuration; baseline 1.11.8 |
| Python | 3.9+ for the optional adapter and CI scripts |
| Provider | None; no provider schema/version is applicable |

Versions inside the accepted range are not individually certified. Terraform 1.5.7 was used for basic and complete plan, apply, second plan and destroy in isolated module copies. Both second plans reported no changes, and no cloud resources were created. OpenTofu 1.11.8 passed static configuration checks.

## 5. Providers

| Name | Source | Version |
|---|---|---|
| None | None | Not applicable |

## 6. Resources

| Mode | Type | Responsibility |
|---|---|---|
| None | None | Pure expressions and outputs; no resource lifecycle |

## 7. Inputs

| Name | Type | Default | Required / meaning |
|---|---|---|---|
| `currency` | `string` | `"CNY"` | Three uppercase letters; every rate and budget must use this currency |
| `region` | `string` | `"cn-beijing"` | Nonblank catalog region; use separate module calls per region/currency |
| `price_source` | `string` | None | Required nonblank quote/catalog provenance, version and date |
| `monthly_hours` | `number` | `730` | 0–744, representative operating hours |
| `reserved_instance_discount_rate` | `number` | `0` | 0–1 fraction saved; 0.30 means 30% off |
| `output_format` | `string` | `"json"` | json, csv or text |
| `budget_thresholds` | `object({monthly=optional(number),annual=optional(number)})` | `{}` | Nonnegative thresholds; null disables a period, zero is valid |
| `cost_items` | `map(object({resource_address=string,unit=string,unit_price=number,quantity=optional(number,1),monthly_usage=optional(number),reserved_eligible=optional(bool,false)}))` | `{}` | Stable keys identify charge components, not Terraform resource ownership |

Root inputs are nonnullable; explicit null selects the default where a default exists, and price_source must be supplied. Each item requires a nonblank key/address and nonnegative price and quantity. `unit` is hourly, monthly or usage. `monthly_usage` is mandatory and nonnegative for usage, and must be omitted for other units. Quantity is a multiplier: hourly = price × quantity × monthly_hours; monthly = price × quantity; usage = price × quantity × monthly_usage. Model distinct billing dimensions as separate items, even for one resource. A zero price is an explicit caller decision.

## 8. Outputs

| Name | Type | Meaning |
|---|---|---|
| `monthly_cost` | `number` | Unrounded recurring monthly total; zero for empty input |
| `annual_cost` | `number` | Monthly total × 12 |
| `item_costs` | `map(object)` | Address, unit, unit_price, quantity, nullable monthly_usage, applied discount_rate, monthly_cost, annual_cost |
| `budget_exceeded` | `bool` | Any enabled period strictly exceeds its threshold |
| `alert_payload` | `object` | event, currency, region, exceeded, budgets; each budget has threshold, forecast, exceeded |
| `report` | `object` | currency, region, price_source, monthly_hours, reserved_instance_discount_rate, totals, items, budgets, budget_exceeded |
| `formatted_report` | `string` | JSON: full report; CSV: item/address/currency/region/monthly/annual rows plus TOTAL; text: rows, totals, provenance and budget status |

Outputs contain no credentials. Keys/addresses and negotiated prices may still be commercially sensitive; control access to exported plans and reports. CSV/text monetary values use two decimals for presentation; budget comparisons use unrounded numbers. Read `report` or `alert_payload` for complete budget details regardless of output_format.

## 9. Notes

Budget equality is within budget. Null budgets do not alert; a zero budget alerts on any positive forecast. Discounts apply only where `reserved_eligible=true`; avoid applying them to already discounted quotes. Annual estimates assume twelve identical representative months. Taxes, one-time/upfront reservation charges, exchange rates, tiered pricing, free quotas, time-varying usage and real reservation eligibility are not inferred. Supply separately calculated effective rates/usage where appropriate.

The adapter accepts plan JSON format 1.x, traverses nested planned modules and matches exact managed instance addresses (including count/for_each indexes). Every managed resource must have at least one component or a documented exclusion in `ignored_resources`. It rejects stale mappings, missing rates/quantities, incomplete plans and unknown quantities. Data sources are not chargeable objects. Mapping completeness proves address coverage, not that the caller included every billing dimension or selected the correct SKU; verify prices and all dimensions against the quote.

There is no create/update/replacement/import behavior. Key changes only change output rows. Forecast evaluation is offline; notification delivery belongs to the caller, and `budget_gate.py` emits a generic JSON event without sending it. Registry publication remains unverified. Read-only online spot price snapshots were used to verify forecast arithmetic; authoritative currency, real reservation discounts and official bill comparison were not verified.

Engineering reference: [module repository standard](https://bytedance.larkoffice.com/docx/C3TZdz2lnoAZmDxC7zRcOSgzn4d), sections 5.3 and 5.5, revision 2645, read 2026-11-05. Local PRD/standard files were not present; the supplied scenario is the capability contract.
