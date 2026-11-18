variable "aws_region" {
  description = "AWS region. The Learner Lab is pinned to us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources and the tag everything is grouped by."
  type        = string
  default     = "tictactest"
}

variable "instance_type" {
  description = <<-EOT
    EC2 instance type. The web console starts one JVM (~45 MiB) per connected
    player, so memory is the limiting factor, not CPU. t3.micro (1 GiB) is
    enough for the ~10 concurrent sessions ttyd is capped at.
  EOT
  type        = string
  default     = "t3.micro"
}

variable "instance_profile_name" {
  description = <<-EOT
    Existing instance profile to attach. The Learner Lab forbids creating IAM
    roles, so the pre-provisioned LabInstanceProfile is looked up as a data
    source instead. It gives the instance SSM access (for deployments without
    SSH) and S3 access (to pull the release artefacts) - no access keys ever
    land on the instance.
  EOT
  type        = string
  default     = "LabInstanceProfile"
}

variable "ssh_ingress_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach port 22. Empty by default: deployments go through
    SSM, so SSH is not needed for normal operation. Set it to your own
    "<ip>/32" temporarily if you need to debug on the box.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.ssh_ingress_cidrs, "0.0.0.0/0")
    error_message = "Refusing to open SSH to the whole internet. Use your own address, e.g. [\"203.0.113.4/32\"]."
  }
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for the optional SSH access. null = no key."
  type        = string
  default     = null
}

# --- web console ------------------------------------------------------------

variable "ttyd_version" {
  description = "Pinned ttyd release. Must match ops/local/fetch-release.sh so local and cloud run the same terminal."
  type        = string
  default     = "1.7.7"
}

variable "ttyd_sha256" {
  description = "SHA-256 of the ttyd binary. The instance refuses to install anything else."
  type        = string
  default     = "8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55"
}

variable "ttyd_max_clients" {
  description = <<-EOT
    Maximum simultaneous games. Each one is a JVM of roughly 45 MiB, so this is
    what keeps a 1 GiB instance from being pushed into the OOM killer by the
    eleventh visitor. Measured numbers in docs/webkonsole.md.
  EOT
  type        = number
  default     = 10
}

variable "initial_version" {
  description = <<-EOT
    Version the instance starts with on first boot, e.g. "1.2.0". This is only
    a seed so the box is not empty after an apply - afterwards the DEPLOYMENT
    decides which version runs, and the infrastructure never touches it again.
    Leave null to bring the instance up without an application.
  EOT
  type        = string
  default     = null
}
