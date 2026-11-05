output "report" {
  description = "Structured multi-resource forecast."
  value       = module.pricing.report
}

output "formatted_report" {
  description = "Report in the requested format."
  value       = module.pricing.formatted_report
}

output "alert_payload" {
  description = "Forecast event for caller-owned CI and notifications."
  value       = module.pricing.alert_payload
}
