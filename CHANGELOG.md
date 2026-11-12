# Changelog

## Unreleased

- Fix equal annual budget alerts by calculating decimal coefficients before converting forecast totals.
- Preserve decimal price, quantity and usage precision through plan conversion and CI event serialization.
- Accept valid plans that omit the optional resource_changes field, including empty plans.
- Add provider-free recurring cost forecasts, selective reserved discounts, budget events and JSON/CSV/text reports.
- Add explicit Terraform plan price mapping, CI budget gate and bilingual basic/complete examples.
