variable "location1" {
  default = "westeurope"
}

resource "azurerm_storage_account" "storage-lfx" {
  name                     = "storagelfx"
  resource_group_name      = "${azurerm_resource_group.rg-lfx.name}"
  location                 = "${var.location1}"
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
}

resource "azurerm_resource_group" "rg-lfx" {
  location = "${var.location1}"
  name     = "rg-lfx"
}

resource "azurerm_app_service_plan" "app-plan-lfx" {
  name                = "app-plan-lfx"
  location            = "${var.location1}"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"

  sku {
    tier = "PremiumV2"
    size = "P1v2"
  }
}

resource "azurerm_app_service" "app-lfx" {
  name                = "app-lfx"
  location            = "${var.location1}"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  app_service_plan_id = "${azurerm_app_service_plan.app-plan-lfx.id}"


  app_settings = {
    "location" = "${var.location1}"
  }
}

resource "random_string" "random-sql-pwd" {
  length  = 16
  special = true
}

resource "azurerm_sql_server" "sql-server-lfx-primary" {
  name                         = "sql-server-lfx-primary"
  resource_group_name          = "${azurerm_resource_group.rg-lfx.name}"
  location                     = "${var.location1}"
  version                      = "12.0"
  administrator_login          = "mamelch"
  administrator_login_password = "${random_string.random-sql-pwd.result}"
}

resource "azurerm_sql_database" "sql-db-lfx-primary" {
  name                             = "sql-db-lfx"
  resource_group_name              = "${azurerm_resource_group.rg-lfx.name}"
  location                         = "${var.location1}"
  server_name                      = "${azurerm_sql_server.sql-server-lfx-primary.name}"
  edition                          = "Standard"
  requested_service_objective_name = "S1"
}

resource "azurerm_sql_firewall_rule" "fw-sql-primary" {
  name                = "AllowAllAzureIps"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  server_name         = "${azurerm_sql_server.sql-server-lfx-primary.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


resource "azurerm_virtual_network" "vnet-lfx" {
  name                = "vnet-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  location            = "${var.location1}"
  address_space       = ["10.254.0.0/16"]
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = "${azurerm_resource_group.rg-lfx.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet-lfx.name}"
  address_prefix       = "10.254.0.0/24"
}

resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = "${azurerm_resource_group.rg-lfx.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet-lfx.name}"
  address_prefix       = "10.254.2.0/24"
}

resource "azurerm_public_ip" "pip-lfx" {
  name                = "pip-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  location            = "${var.location1}"
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "appgw-lfx"
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.vnet-lfx.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.vnet-lfx.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet-lfx.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.vnet-lfx.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.vnet-lfx.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.vnet-lfx.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.vnet-lfx.name}-rdrcfg"
}

resource "azurerm_application_gateway" "appgw-lfx" {
  name                = "appgw-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  location            = "${var.location1}"
  zones               = [1, 2, 3]

  waf_configuration {
    enabled          = "true"
    firewall_mode    = "Prevention"
    rule_set_version = "3.0"

    disabled_rule_group {
      rule_group_name = "General"
      rules           = []
    }
  }

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = "${azurerm_subnet.frontend.id}"
  }

  frontend_port {
    name = "${local.frontend_port_name}"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${local.frontend_ip_configuration_name}"
    public_ip_address_id = "${azurerm_public_ip.pip-lfx.id}"
  }

  backend_address_pool {
    name      = "${local.backend_address_pool_name}"
    fqdn_list = ["app-lfx.azurewebsites.net"]
  }

  backend_http_settings {
    name                                = "${local.http_setting_name}"
    cookie_based_affinity               = "Disabled"
    path                                = ""
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 86400
    pick_host_name_from_backend_address = "true"

  }

  probe {
    interval                                  = 30
    minimum_servers                           = 0
    name                                      = "primary"
    path                                      = "/"
    pick_host_name_from_backend_http_settings = true
    protocol                                  = "Http"
    timeout                                   = 30
    unhealthy_threshold                       = 3
  }

  http_listener {
    name                           = "${local.listener_name}"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}"
    frontend_port_name             = "${local.frontend_port_name}"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${local.request_routing_rule_name}"
    rule_type                  = "Basic"
    http_listener_name         = "${local.listener_name}"
    backend_address_pool_name  = "${local.backend_address_pool_name}"
    backend_http_settings_name = "${local.http_setting_name}"

  }
}
