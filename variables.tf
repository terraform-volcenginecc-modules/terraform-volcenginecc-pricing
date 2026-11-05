variable "currency" {
  description = "Currency of every supplied price and budget; no exchange conversion is performed."
  type        = string
  default     = "CNY"
  nullable    = false
  validation {
    condition     = can(regex("^[A-Z]{3}$", var.currency))
    error_message = "currency must be a three-letter uppercase currency code."
  }
}

variable "region" {
  description = "Region to which all supplied prices apply; metadata, not an API price filter."
  type        = string
  default     = "cn-beijing"
  nullable    = false
  validation {
    condition     = length(trimspace(var.region)) > 0
    error_message = "region must not be blank."
  }
}

variable "price_source" {
  description = "Provenance of supplied prices, including quote/catalog version and date."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.price_source)) > 0
    error_message = "price_source must describe the price provenance."
  }
}

variable "monthly_hours" {
  description = "Operating hours per representative month for hourly components."
  type        = number
  default     = 730
  nullable    = false
  validation {
    condition     = var.monthly_hours >= 0 && var.monthly_hours <= 744
    error_message = "monthly_hours must be between 0 and 744."
  }
}

variable "reserved_instance_discount_rate" {
  description = "Fraction saved (0.30 means 30% off), applied only to reserved_eligible items."
  type        = number
  default     = 0
  nullable    = false
  validation {
    condition     = var.reserved_instance_discount_rate >= 0 && var.reserved_instance_discount_rate <= 1
    error_message = "reserved_instance_discount_rate must be between 0 and 1."
  }
}

variable "output_format" {
  description = "Serialization for formatted_report: json, csv, or text."
  type        = string
  default     = "json"
  nullable    = false
  validation {
    condition     = contains(["json", "csv", "text"], var.output_format)
    error_message = "output_format must be json, csv, or text."
  }
}

variable "budget_thresholds" {
  description = "Monthly and annual budgets in currency. null disables a period; zero is a valid budget."
  type = object({
    monthly = optional(number)
    annual  = optional(number)
  })
  default  = {}
  nullable = false
  validation {
    condition = alltrue([
      for value in [var.budget_thresholds.monthly, var.budget_thresholds.annual] :
      value == null ? true : value >= 0
    ])
    error_message = "Budget thresholds must be null or nonnegative."
  }
}

variable "cost_items" {
  description = "Stable keyed charge components. Prices and budgets must share currency/region. usage requires monthly_usage."
  type = map(object({
    resource_address  = string
    unit              = string
    unit_price        = number
    quantity          = optional(number, 1)
    monthly_usage     = optional(number)
    reserved_eligible = optional(bool, false)
  }))
  default  = {}
  nullable = false
  validation {
    condition = alltrue([
      for key, item in var.cost_items : try(
        length(trimspace(key)) > 0 &&
        length(trimspace(item.resource_address)) > 0 &&
        contains(["hourly", "monthly", "usage"], item.unit) &&
        item.unit_price >= 0 && item.quantity >= 0 &&
        (item.unit == "usage" ? item.monthly_usage != null && item.monthly_usage >= 0 : item.monthly_usage == null),
        false
      )
    ])
    error_message = "Each item needs a nonblank key/address, hourly/monthly/usage unit and nonnegative price/quantity. Only usage requires monthly_usage."
  }
}
