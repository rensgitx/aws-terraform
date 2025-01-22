variable "env" {
  type        = string
  description = "Environment"
}

variable "bucket_prefix" {
  type        = string
  description = "A unique string prefix that identifies your s3 buckets."
  sensitive   = true
}

variable "tile_email" {
  sensitive = true
}

variable "tile_password" {
  sensitive = true
}

variable "apps_bucket" {
  type        = string
  description = "S3 bucket where the tile-tracker app lives"
}

variable "tile_notification_email" {
  sensitive = true
}
