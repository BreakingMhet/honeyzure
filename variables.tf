variable "destination_email" {
  description = "Destination email for the alert"
}

variable "sql_admin" {
  description = "Entra ID email of the user designed to be the administrator of the SQL Server"
}

variable "enable_storage" {
  description = "Specify the creation of the honey storage"
}

variable "enable_sqldb" {
  description = "Specify the creation of the honey sqldb"
}