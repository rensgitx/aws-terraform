module "s3_bucket" {
  source        = "../../modules/s3-buckets"
  env           = var.env
  bucket_prefix = var.bucket_prefix
}

module "tile_tracker" {
  source                  = "../../modules/apps/tile-tracker"
  env                     = var.env
  tile_email              = var.tile_email
  tile_password           = var.tile_password
  tile_notification_email = var.tile_notification_email
  tile_tracker_bucket     = var.apps_bucket
}
