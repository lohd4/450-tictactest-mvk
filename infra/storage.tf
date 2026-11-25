# Two buckets with opposite jobs:
#
#   artifacts  PRIVATE. The deployment copies the release assets here and the
#              instance pulls them with its instance profile. Nothing public.
#   frontend   PUBLIC static website. Only the static site, never a secret.

# --- artefact bucket --------------------------------------------------------
# Why go through S3 instead of letting the instance curl the GitHub release?
#  * works even if the repository becomes private - no token on the instance
#  * the instance authenticates with its instance profile, so there are no
#    access keys on the box at all
#  * after a reboot the instance can re-fetch its jar without depending on
#    GitHub being reachable
# Documented trade-off: one more hop in the pipeline (download from the
# release, upload to S3) and one more thing to rebuild after terraform destroy.

resource "aws_s3_bucket" "artifacts" {
  # S3 bucket names are globally unique, so never a fixed name.
  bucket_prefix = "${var.project_name}-artifacts-"
  force_destroy = true # lab environment: terraform destroy should not get stuck
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled" # an overwritten artefact is still recoverable
  }
}

# --- frontend bucket (public static website) --------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.project_name}-frontend-"
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

# This bucket is deliberately world-readable - it is a public website.
# NOTHING confidential may ever be put here: no credentials, no private URLs,
# no .env files, no state. The only things written are the static site and
# config.js, which contains a public address and nothing else.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false # required, the policy below IS public
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadOfStaticSite"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_ownership_controls.frontend,
  ]
}

# --- the one file the infrastructure owns inside the frontend ---------------
# Only the infrastructure knows the address of the instance, so Terraform writes
# config.js itself. It is NOT part of the frontend release archive
# (package-frontend.sh removes it and fails if it reappears), and the frontend
# deployment syncs with --exclude config.js. That is what keeps a frontend
# release from blanking out the console URL.
resource "aws_s3_object" "frontend_config" {
  bucket        = aws_s3_bucket.frontend.id
  key           = "config.js"
  content_type  = "application/javascript"
  cache_control = "no-store"

  content = <<-EOT
    /* Written by Terraform - do not edit, do not ship in the release archive. */
    window.TICTACTEST_CONFIG = {
      consoleUrl: 'http://${aws_eip.console.public_ip}/',
      versionUrl: 'http://${aws_eip.console.public_ip}/version'
    };
  EOT

  # Changing the content must publish a new object, which it does by default;
  # listed explicitly so the dependency on the EIP is obvious.
  depends_on = [aws_eip.console]
}
