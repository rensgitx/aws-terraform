variable "env" {
  type        = string
  description = "Environment"
}

variable "tile_tracker_bucket" {
  type        = string
  description = "S3 bucket containing the lambda assets (layers, function)"     
}

variable "tile_email" {
  type        = string
  description = "Tile user's email"
  sensitive   = true
}

variable "tile_password" {
  type        = string
  description = "Tile user's password"
  sensitive   = true      
}

variable "tile_notification_email" {
  type        = string
  description = "Email address for Cloudwatch alerts"
}
