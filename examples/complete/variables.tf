variable "currency" {
  description = "Currency of the catalog and budgets."
  type        = string
  default     = "CNY"
}

variable "region" {
  description = "Region of all catalog prices."
  type        = string
  default     = "cn-beijing"
}

variable "price_source" {
  description = "Quote/catalog provenance with version and date."
  type        = string
}

variable "monthly_hours" {
  description = "Representative monthly operating hours."
  type        = number
  default     = 730
}

variable "reserved_instance_discount_rate" {
  description = "Discount fraction for eligible components only."
  type        = number
  default     = 0
}

variable "output_format" {
  description = "json, csv, or text report."
  type        = string
  default     = "json"
}

variable "budget_thresholds" {
  description = "Caller-defined monthly and annual budgets; null disables a period."
  type = object({
    monthly = optional(number)
    annual  = optional(number)
  })
  default = {}
}

variable "cost_items" {
  description = "Plan-derived or manually supplied compute/storage/traffic charge components."
  type = map(object({
    resource_address  = string
    unit              = string
    unit_price        = number
    quantity          = optional(number, 1)
    monthly_usage     = optional(number)
    reserved_eligible = optional(bool, false)
  }))
}
