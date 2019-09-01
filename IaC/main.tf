variable "location1" {
  default = "westeurope"
}

variable "location2" {
  default = "northeurope"
}

resource "azurerm_resource_group" "rg-lfx" {
  location = "${var.location1}"
  name     = "rg-lfx"
}

resource "azurerm_app_service_plan" "app-plan-lfx" {
  name                = "app-plan-lfx"
  location            = "${azurerm_resource_group.rg-lfx.location}"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"

  sku {
    tier = "Standard"
    size = "P1V2"
  }
}

resource "azurerm_app_service" "app-lfx" {
  name                = "app-lfx"
  location            = "${azurerm_resource_group.rg-lfx.location}"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  app_service_plan_id = "${azurerm_app_service_plan.app-plan-lfx.id}"


  app_settings = {
    "SOME_KEY" = "some-value"
  }
}

resource "random_string" "random-sql-pwd" {
  length  = 16
  special = true
}

resource "azurerm_sql_server" "sql-server-lfx-primary" {
  name                         = "sql-server-lfx-primary"
  resource_group_name          = "${azurerm_resource_group.rg-lfx.name}"
  location                     = "${azurerm_resource_group.rg-lfx.location}"
  version                      = "12.0"
  administrator_login          = "mamelch"
  administrator_login_password = "${random_string.random-sql-pwd.result}"
}


resource "azurerm_sql_server" "sql-server-lfx-secondary" {
  name                         = "sql-server-lfx-secondary"
  resource_group_name          = "${azurerm_resource_group.rg-lfx.name}"
  location                     = "${var.location2}"
  version                      = "12.0"
  administrator_login          = "mamelch"
  administrator_login_password = "${random_string.random-sql-pwd.result}"
}

resource "azurerm_sql_database" "sql-db-lfx-primary" {
  name                             = "sql-db-lfx"
  resource_group_name              = "${azurerm_resource_group.rg-lfx.name}"
  location                         = "${azurerm_resource_group.rg-lfx.location}"
  server_name                      = "${azurerm_sql_server.sql-server-lfx-primary.name}"
  edition                          = "Standard"
  requested_service_objective_name = "S1"
}

resource "azurerm_sql_database" "sql-db-lfx-secondary" {
  create_mode         = "OnlineSecondary"
  source_database_id  = "${azurerm_sql_database.sql-db-lfx-primary.id}"
  name                = "${azurerm_sql_database.sql-db-lfx-primary.name}"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  location            = "${var.location2}"
  server_name         = "${azurerm_sql_server.sql-server-lfx-secondary.name}"
  edition             = "${azurerm_sql_database.sql-db-lfx-primary.edition}"
}

resource "azurerm_sql_firewall_rule" "fw-sql-primary" {
  name                = "AllowAllAzureIps"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  server_name         = "${azurerm_sql_server.sql-server-lfx-primary.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_sql_firewall_rule" "fw-sql-secondary" {
  name                = "AllowAllAzureIps"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  server_name         = "${azurerm_sql_server.sql-server-lfx-secondary.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_storage_account" "storage-lfx" {
  name                     = "storagelfx"
  resource_group_name      = "${azurerm_resource_group.rg-lfx.name}"
  location                 = "${azurerm_resource_group.rg-lfx.location}"
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
}

resource "azurerm_virtual_network" "vnet-lfx" {
  name                = "vnet-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  location            = "${azurerm_resource_group.rg-lfx.location}"
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
  location            = "${azurerm_resource_group.rg-lfx.location}"
  allocation_method   = "Static"
  sku                 = "Standard"
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
  location            = "${azurerm_resource_group.rg-lfx.location}"
  zones               = [1, 2, 3]

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
    name                  = "${local.http_setting_name}"
    cookie_based_affinity = "Disabled"
    path                  = ""
    port                  = 80
    protocol              = "Http"
    request_timeout       = 86400
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

resource "azurerm_traffic_manager_endpoint" "test" {
  name                = "${azurerm_traffic_manager_profile.tm-profile.name}"
  resource_group_name = "${azurerm_resource_group.rg-lfx.name}"
  profile_name        = "${azurerm_traffic_manager_profile.tm-profile.name}"
  target              = "terraform.io"
  type                = "externalEndpoints"
  weight              = 100
  endpoint_location   = "westeurope"
}
