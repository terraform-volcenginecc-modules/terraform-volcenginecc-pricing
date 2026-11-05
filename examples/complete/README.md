# Combined forecast and budget integration

Estimate a planned multi-resource workload and produce an event suitable for a caller-owned CI alert flow. Map compute hourly charges, storage monthly charges and traffic usage charges separately, including multiple components for one resource. No resources or notification channels are created.

The source is `terraform-volcenginecc-modules/pricing/volcenginecc`; Registry publication/consumption are unverified. Copy the example to a temporary directory and replace source with the absolute repository path for local use. Terraform 1.5.7 and OpenTofu 1.11.8 share this configuration.

Prepare a saved workload plan using `terraform show -json`. Prepare a private `catalog.json` with currency, region, price_source, rates and resources. Each rate contains unit, actual unit_price and optional reserved_eligible. Every full resource address maps to a component map; each component has rate_key and exactly one of fixed quantity or quantity_path (an array of attribute names/indexes into planned resource values). usage components also require monthly_usage. For example, use quantity 1 for an instance, quantity_path ["size"] for a disk's capacity if that field exists in its verified schema, and monthly_usage for forecast traffic. Match SKUs and billing units to the actual quote. Explicit exclusions use an address-to-reason ignored_resources map.

Prepare a private `budget.tfvars` with monthly_hours, reserved_instance_discount_rate, output_format and budget_thresholds containing your approved numeric monthly and annual budgets. The adapter supplies cost_items, currency, region and price_source; do not override them with inconsistent metadata.

Run these commands from the repository after placing the workload plan JSON and catalog in the working directory and preparing the local example copy:

```bash
python3 scripts/plan_to_tfvars.py --plan plan.json --catalog catalog.json > costs.tfvars.json
terraform -chdir=examples/complete init -backend=false
terraform -chdir=examples/complete plan -input=false -var-file=../../costs.tfvars.json -var-file=budget.tfvars -out=estimate.tfplan
terraform -chdir=examples/complete show -json estimate.tfplan > estimate.json
python3 scripts/budget_gate.py estimate.json
```

The command paths above assume examples/complete is the prepared local copy within your temporary repository copy. Keep workload planning separate from this estimate-only configuration. No apply is required: report, formatted_report and alert_payload are in planned_values.outputs. The gate prints an event and exits 0 within budget, 2 over budget, or 1 on malformed/unknown output. A CI runner can route the event to its existing notification integration. Nothing is sent by these scripts.

An empty map produces a zero estimate. All managed workload addresses must be priced or explicitly excluded; unknown/missing quantities and stale mappings fail. Deleted addresses must be removed. Choose json for a full serialized report, csv for cost rows and text for a readable summary. Budgets use strict greater-than and unrounded totals; a discount of 0.30 applies 30% savings only to eligible components. Annual cost is monthly × 12, excluding upfront charges, taxes and tiered/free-quota calculation.

Delete generated plans, JSON, private quote/budget files and temporary directories after use. No cloud destroy is needed. Live pricing, actual billing reconciliation and notification delivery are not validated.
