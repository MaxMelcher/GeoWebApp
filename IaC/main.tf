resource "azurerm_traffic_manager_profile" "tm-profile" {
  name                = "tm-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"

  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "tm-lfx"
    ttl           = 100
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}

resource "azurerm_traffic_manager_endpoint" "primary" {
  name                = "tme-primary"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  profile_name        = "${azurerm_traffic_manager_profile.tm-profile.name}"
  target              = "${azurerm_public_ip.pip-lfx.ip_address}"
  type                = "externalEndpoints"
  weight              = 100
  endpoint_location   = "westeurope"
}

resource "azurerm_traffic_manager_endpoint" "secondary" {
  name                = "tme-secondary"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  profile_name        = "${azurerm_traffic_manager_profile.tm-profile.name}"
  target              = "${azurerm_public_ip.pip-lfx-secondary.ip_address}"
  type                = "externalEndpoints"
  weight              = 100
  endpoint_location   = "francecentral"
}
