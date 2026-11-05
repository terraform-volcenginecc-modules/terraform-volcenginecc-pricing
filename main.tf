locals {
  gross_monthly = {
    for key, item in var.cost_items : key => item.quantity * item.unit_price * (
      item.unit == "hourly" ? var.monthly_hours : item.unit == "usage" ? coalesce(item.monthly_usage, 0) : 1
    )
  }
  item_costs = {
    for key, item in var.cost_items : key => {
      resource_address = item.resource_address
      unit             = item.unit
      unit_price       = item.unit_price
      quantity         = item.quantity
      monthly_usage    = item.monthly_usage
      discount_rate    = item.reserved_eligible ? var.reserved_instance_discount_rate : 0
      monthly_cost     = local.gross_monthly[key] * (item.reserved_eligible ? 1 - var.reserved_instance_discount_rate : 1)
      annual_cost      = local.gross_monthly[key] * (item.reserved_eligible ? 1 - var.reserved_instance_discount_rate : 1) * 12
    }
  }
  monthly_cost = sum(concat([0], [for item in values(local.item_costs) : item.monthly_cost]))
  annual_cost  = local.monthly_cost * 12
  budgets = {
    monthly = {
      threshold = var.budget_thresholds.monthly
      forecast  = local.monthly_cost
      exceeded  = var.budget_thresholds.monthly == null ? false : local.monthly_cost > var.budget_thresholds.monthly
    }
    annual = {
      threshold = var.budget_thresholds.annual
      forecast  = local.annual_cost
      exceeded  = var.budget_thresholds.annual == null ? false : local.annual_cost > var.budget_thresholds.annual
    }
  }
  alert_payload = {
    event    = "cost_budget_forecast"
    currency = var.currency
    region   = var.region
    exceeded = anytrue([for budget in values(local.budgets) : budget.exceeded])
    budgets  = local.budgets
  }
  report = {
    currency                        = var.currency
    region                          = var.region
    price_source                    = var.price_source
    monthly_hours                   = var.monthly_hours
    reserved_instance_discount_rate = var.reserved_instance_discount_rate
    monthly_cost                    = local.monthly_cost
    annual_cost                     = local.annual_cost
    items                           = local.item_costs
    budgets                         = local.budgets
    budget_exceeded                 = local.alert_payload.exceeded
  }
  # Quote every string cell and escape embedded quotes per RFC 4180.
  csv_report = join("\r\n", concat(
    ["item,resource_address,currency,region,monthly_cost,annual_cost"],
    [
      for key in sort(keys(local.item_costs)) : join(",", concat(
        [for cell in [key, local.item_costs[key].resource_address, var.currency, var.region] : "\"${replace(cell, "\"", "\"\"")}\""],
        [format("%.2f", local.item_costs[key].monthly_cost), format("%.2f", local.item_costs[key].annual_cost)]
      ))
    ],
    ["\"TOTAL\",\"\",\"${var.currency}\",\"${replace(var.region, "\"", "\"\"")}\",${format("%.2f", local.monthly_cost)},${format("%.2f", local.annual_cost)}"]
  ))
  text_report = join("\n", concat(
    ["Cost forecast: ${var.currency} / ${var.region}", "Price source: ${var.price_source}"],
    [
      for key in sort(keys(local.item_costs)) :
      format("%s: %.2f/month, %.2f/year", key, local.item_costs[key].monthly_cost, local.item_costs[key].annual_cost)
    ],
    [
      format("TOTAL: %.2f/month, %.2f/year", local.monthly_cost, local.annual_cost),
      "Budget exceeded: ${local.alert_payload.exceeded}"
    ]
  ))
}
