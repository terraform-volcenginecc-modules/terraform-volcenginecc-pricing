module "pricing" {
  source = "terraform-volcenginecc-modules/pricing/volcenginecc"

  currency                        = var.currency
  region                          = var.region
  price_source                    = var.price_source
  monthly_hours                   = var.monthly_hours
  reserved_instance_discount_rate = var.reserved_instance_discount_rate
  output_format                   = var.output_format
  budget_thresholds               = var.budget_thresholds
  cost_items                      = var.cost_items
}
