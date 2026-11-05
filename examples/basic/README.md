# Basic cost estimation

Estimate one caller-owned hourly resource without creating it or querying cloud APIs. Provide an actual quoted hourly price, its currency/region, provenance and resource address.

The module source is `terraform-volcenginecc-modules/pricing/volcenginecc`; publication and Registry consumption remain unverified. For local use, copy this example to a temporary directory and change its module source to the absolute path of the repository.

Set `hourly_unit_price`, `price_source` and `resource_address` in a private `quote.tfvars` file; optionally set `currency` (CNY) and `region` (cn-beijing). The module defaults to 730 hours/month and no discount. The amount is price × 730/month and × 12/year. Quotes must cover the intended region and currency.

```bash
terraform init -backend=false
terraform plan -input=false -var-file=quote.tfvars -out=estimate.tfplan
terraform show -json estimate.tfplan > estimate.json
```

Read `planned_values.outputs.report.value` from estimate.json. No apply is needed to read the forecast. Delete the generated plan/JSON and temporary working directory after use; there are no cloud resources to destroy.

Validation baselines are Terraform 1.5.7 and OpenTofu 1.11.8 with the same configuration. This is a linear recurring estimate, not an official bill; taxes, upfront charges and live price lookup are outside scope.
