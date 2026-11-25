# Outputs are the interface between the infrastructure and everything else:
# a human who wants to play, and the deployment workflow of Auftrag 3.
#
# None of these are confidential. They are public addresses and resource names,
# and the frontend bucket publishes the console URL to every visitor anyway.
# What WOULD be confidential - AWS credentials, the session token, the state
# file - is never an output and never leaves the local machine.

output "play_url" {
  description = "Open this to play: the static frontend with the embedded terminal."
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "console_url" {
  description = "The web console itself (nginx in front of ttyd)."
  value       = "http://${aws_eip.console.public_ip}/"
}

output "version_url" {
  description = "Plain-text endpoint reporting the running backend version. Used by the deployment check."
  value       = "http://${aws_eip.console.public_ip}/version"
}

output "frontend_bucket" {
  description = "S3 bucket serving the frontend. The deployment syncs into it."
  value       = aws_s3_bucket.frontend.id
}

output "artifacts_bucket" {
  description = "Private bucket the release artefacts are copied into, and that the instance pulls from."
  value       = aws_s3_bucket.artifacts.id
}

output "instance_id" {
  description = "EC2 instance ID. The deployment targets it with `aws ssm send-command`."
  value       = aws_instance.console.id
}

output "public_ip" {
  description = "Elastic IP of the instance. Stable across Learner Lab sessions."
  value       = aws_eip.console.public_ip
}

output "aws_region" {
  description = "Region everything lives in, so the pipeline does not have to guess."
  value       = var.aws_region
}

# Convenience: everything the deployment workflow needs, in one blob to copy
# into GitHub Variables after an apply.
output "github_variables" {
  description = "Values to store as GitHub Actions *Variables* (not Secrets - none of this is sensitive)."
  value = {
    AWS_REGION       = var.aws_region
    INSTANCE_ID      = aws_instance.console.id
    ARTIFACTS_BUCKET = aws_s3_bucket.artifacts.id
    FRONTEND_BUCKET  = aws_s3_bucket.frontend.id
    VERSION_URL      = "http://${aws_eip.console.public_ip}/version"
    PLAY_URL         = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
  }
}
