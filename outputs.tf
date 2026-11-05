output "monthly_cost" {
  description = "Unrounded recurring monthly cost in the declared currency."
  value       = local.monthly_cost
}

output "annual_cost" {
  description = "Unrounded monthly cost multiplied by 12."
  value       = local.annual_cost
}

output "item_costs" {
  description = "Per-component recurring estimates keyed by caller's stable logical keys."
  value       = local.item_costs
}

output "budget_exceeded" {
  description = "True if any enabled budget is strictly exceeded. Equality is within budget."
  value       = local.alert_payload.exceeded
}

output "alert_payload" {
  description = "Structured forecast event for caller-owned CI/notification integration; nothing is sent."
  value       = local.alert_payload
}

output "report" {
  description = "Structured costs, assumptions, price provenance and period budgets."
  value       = local.report
}

output "formatted_report" {
  description = "JSON includes the full report; CSV includes cost rows; text includes costs and budget status."
  value       = var.output_format == "json" ? jsonencode(local.report) : var.output_format == "csv" ? local.csv_report : local.text_report
}
