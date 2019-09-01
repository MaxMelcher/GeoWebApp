variable "location2" {
  default = "northeurope"
}


resource "azurerm_resource_group" "rg-lfx-secondary" {
  location = "${var.location2}"
  name     = "rg-lfx-secondary"
}

resource "azurerm_sql_server" "sql-server-lfx-secondary" {
  name                         = "sql-server-lfx-secondary"
  resource_group_name          = "${azurerm_resource_group.rg-lfx-secondary.name}"
  location                     = "${var.location2}"
  version                      = "12.0"
  administrator_login          = "mamelch"
  administrator_login_password = "${random_string.random-sql-pwd.result}"
}


resource "azurerm_sql_database" "sql-db-lfx-secondary" {
  create_mode         = "OnlineSecondary"
  source_database_id  = "${azurerm_sql_database.sql-db-lfx-primary.id}"
  name                = "${azurerm_sql_database.sql-db-lfx-primary.name}"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"
  location            = "${var.location2}"
  server_name         = "${azurerm_sql_server.sql-server-lfx-secondary.name}"
  edition             = "${azurerm_sql_database.sql-db-lfx-primary.edition}"
}

resource "azurerm_sql_firewall_rule" "fw-sql-secondary" {
  name                = "AllowAllAzureIps"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"
  server_name         = "${azurerm_sql_server.sql-server-lfx-secondary.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


resource "azurerm_app_service_plan" "app-plan-lfx-secondary" {
  name                = "app-plan-lfx-secondary"
  location            = "${var.location2}"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"

  sku {
    tier = "PremiumV2"
    size = "P1v2"
  }
}

resource "azurerm_app_service" "app-lfx-secondary" {
  name                = "app-lfx-secondary"
  location            = "${var.location2}"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"
  app_service_plan_id = "${azurerm_app_service_plan.app-plan-lfx-secondary.id}"


  app_settings = {
    "SOME_KEY" = "some-value"
  }
}


resource "azurerm_virtual_network" "vnet-lfx-secondary" {
  name                = "vnet-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"
  location            = "${var.location2}"
  address_space       = ["10.253.0.0/16"]
}

resource "azurerm_subnet" "frontend-secondary" {
  name                 = "frontend"
  resource_group_name  = "${azurerm_resource_group.rg-lfx-secondary.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet-lfx-secondary.name}"
  address_prefix       = "10.253.0.0/24"
}

resource "azurerm_subnet" "backend-secondary" {
  name                 = "backend"
  resource_group_name  = "${azurerm_resource_group.rg-lfx-secondary.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet-lfx-secondary.name}"
  address_prefix       = "10.253.2.0/24"
}

resource "azurerm_public_ip" "pip-lfx-secondary" {
  name                = "pip-lfx-secondary"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"
  location            = "${var.location2}"
  allocation_method   = "Static"
  sku                 = "Standard"
}


# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name-secondary      = "${azurerm_virtual_network.vnet-lfx-secondary.name}-beap"
  frontend_port_name-secondary             = "${azurerm_virtual_network.vnet-lfx.name}-feport"
  frontend_ip_configuration_name-secondary = "${azurerm_virtual_network.vnet-lfx-secondary.name}-feip"
  http_setting_name-secondary              = "${azurerm_virtual_network.vnet-lfx-secondary.name}-be-htst"
  listener_name-secondary                  = "${azurerm_virtual_network.vnet-lfx-secondary.name}-httplstn"
  request_routing_rule_name-secondary      = "${azurerm_virtual_network.vnet-lfx-secondary.name}-rqrt"
  redirect_configuration_name-secondary    = "${azurerm_virtual_network.vnet-lfx-secondary.name}-rdrcfg"
}


resource "azurerm_application_gateway" "appgw-lfx-secondary" {
  name                = "appgw-lfx"
  resource_group_name = "${azurerm_resource_group.rg-lfx-secondary.name}"
  location            = "${var.location2}"
  zones               = [1, 2, 3]

  waf_configuration {
    enabled          = "true"
    firewall_mode    = "Prevention"
    rule_set_version = "3.0"
  }

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = "${azurerm_subnet.frontend-secondary.id}"
  }

  frontend_port {
    name = "${local.frontend_port_name-secondary}"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${local.frontend_ip_configuration_name-secondary}"
    public_ip_address_id = "${azurerm_public_ip.pip-lfx-secondary.id}"
  }

  backend_address_pool {
    name      = "${local.backend_address_pool_name-secondary}"
    fqdn_list = ["app-lfx.azurewebsites.net"]
  }

  backend_http_settings {
    name                                = "${local.http_setting_name-secondary}"
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
    name                           = "${local.listener_name-secondary}"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name-secondary}"
    frontend_port_name             = "${local.frontend_port_name-secondary}"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${local.request_routing_rule_name-secondary}"
    rule_type                  = "Basic"
    http_listener_name         = "${local.listener_name-secondary}"
    backend_address_pool_name  = "${local.backend_address_pool_name-secondary}"
    backend_http_settings_name = "${local.http_setting_name-secondary}"
  }
}
