# BASIC Cost Estimation Example

## 1. Overview

This example estimates one hourly object and outputs monthly and annual costs. Callers supply an object identifier, hourly price and quote provenance. No provider, credentials or prerequisite cloud resources are needed. It uses 730 hours per month and quantity 1, without discounts or budget thresholds. Use complete to combine charge components, adjust hours or check budgets.

## 2. Usage

Prepare Terraform 1.5.7 and an hourly quote matching the selected currency and region. This example calls the cost estimation module directly from the Registry; `terraform init` downloads it.

Set inputs in `examples/basic/terraform.tfvars`. These values demonstrate the calculation; the price is not a cloud product quote:

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

Terraform automatically reads that directory's `terraform.tfvars`. The first Plan's `report` should show 730 CNY per month and 8760 CNY per year, with both budget periods disabled and no cloud resource creation. Apply only saves outputs to State. Keep inputs and code unchanged; the second Plan should show no changes. `-detailed-exitcode` returns 0 for no changes, 1 for an error, and 2 for changes. Confirm that the State belongs to this example before Destroy, which clears only stored outputs.

## 3. Requirements

| Name | Version |
|---|---|
| Terraform | Example constraint: `>= 1.5.7, < 1.12.0`; verified version: `1.5.7` |

This example has no provider version constraints and does not depend on Python.

## 4. Providers

| Name | Source |
|---|---|
| None | No provider configuration or passing |

## 5. Resources

| Name | Description |
|---|---|
| `module.pricing` | Calls the Registry module with `source = "terraform-volcenginecc-modules/pricing/volcenginecc"` for one hourly cost estimate. |

The example root declares no Resource or Data Source. An object identifier does not establish resource ownership.

## 6. Inputs

| Name | Description |
|---|---|
| `currency` | `string`, default `"CNY"`. Quote currency, expressed as three uppercase letters; no currency conversion is performed. |
| `region` | `string`, default `"cn-beijing"`. Nonblank quote region; prices are not fetched automatically. |
| `price_source` | Required nonblank `string`. Quote provenance, preferably with version and date. |
| `resource_address` | Required nonblank `string`. Resource ID, Terraform address or business label for the report's `compute` entry. The module does not manage that object. |
| `hourly_unit_price` | Required nonnegative `number`. Hourly price for one object, in `currency`. |

The example uses root defaults: `monthly_hours = 730`, `quantity = 1`, discount rate 0 and disabled budgets. Monthly cost = `hourly_unit_price × 730`; annual cost = monthly cost × 12. Explicit `null` for `currency` or `region` selects the root default; provide explicit values for the other three required inputs.

## 7. Outputs

| Name | Description |
|---|---|
| `report` | Full cost object with currency, region, provenance, the 730-hour assumption, `compute` details, monthly and annual totals, and disabled budget information. View it during Plan or read it after Apply with `terraform output -json report`. |

This example exposes only `report`. A zero price still produces a `compute` entry, with zero monthly and annual costs.

## 8. Example

This directory is the basic example, suitable for checking one object's hourly price and monthly and annual calculations. The complete example adds multiple charge components, discounts, budgets and optional CI gate integration.

## 9. Notes

This example requires no provider authentication or AK/SK credentials. If you obtain quotes separately, supply authentication through the query tool's runtime environment. Do not include quote credentials in estimate inputs.

After Apply, run `terraform plan` again; no changes are required for idempotence. Changes to the price, object identifier or provenance update only the report. Destroy clears the example's stored outputs and preserves existing cloud resources. Import is unnecessary.

730 hours represents a forecast month, and annual costs assume twelve identical months. The estimate does not fetch current prices or reconcile actual bills. Update inputs when quotes or configurations change.

Single-item cost calculations were verified with Terraform 1.5.7. Quotes, object identifiers, exported Plans and State may contain sensitive business information; keep them outside the source tree with controlled access.
