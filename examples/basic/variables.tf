variable "currency" {
  description = "Currency of the supplied quote."
  type        = string
  default     = "CNY"
}

variable "region" {
  description = "Region of the supplied quote."
  type        = string
  default     = "cn-beijing"
}

variable "price_source" {
  description = "Quote/catalog provenance with version and date."
  type        = string
}

variable "resource_address" {
  description = "Address of the resource being estimated."
  type        = string
}

variable "hourly_unit_price" {
  description = "Actual quoted hourly price; no vendor price is assumed."
  type        = number
}
