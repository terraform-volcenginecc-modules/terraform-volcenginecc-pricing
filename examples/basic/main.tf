module "pricing" {
  source = "terraform-volcenginecc-modules/pricing/volcenginecc"

  currency     = var.currency
  region       = var.region
  price_source = var.price_source
  cost_items = {
    compute = {
      resource_address = var.resource_address
      unit             = "hourly"
      unit_price       = var.hourly_unit_price
    }
  }
}
