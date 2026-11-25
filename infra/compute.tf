data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# The Learner Lab does not allow creating IAM roles, so the pre-provisioned
# profile is looked up instead of declared. It is what lets the instance talk
# to S3 and SSM without any credentials stored on the box.
data "aws_iam_instance_profile" "lab" {
  name = var.instance_profile_name
}

resource "aws_instance" "console" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  subnet_id            = data.aws_subnets.default.ids[0]
  iam_instance_profile = data.aws_iam_instance_profile.lab.name
  key_name             = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.console.id]

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    project_name     = var.project_name
    ttyd_version     = var.ttyd_version
    ttyd_sha256      = var.ttyd_sha256
    ttyd_max_clients = var.ttyd_max_clients
    artifacts_bucket = aws_s3_bucket.artifacts.id
    aws_region       = var.aws_region
    # Not coalesce(): it rejects "" as well as null, so a null initial_version
    # (the default - bring the box up empty and let the DEPLOYMENT fill it)
    # would fail the plan outright.
    initial_version = var.initial_version == null ? "" : var.initial_version
  })

  # user_data only runs on first boot, so without this a change to the
  # provisioning script would be silently ignored on an existing instance -
  # the config would claim something the box is not doing. Replacing is the
  # honest behaviour, and it is safe here precisely BECAUSE the application
  # version is not part of user_data: a replaced instance re-reads its desired
  # version from the artefact bucket and comes back on the same Elastic IP.
  # A normal application deployment never touches user_data and therefore
  # never replaces the instance.
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.project_name}-console" }
}

# A Learner Lab session stops the instance and starts it again later, which
# hands out a new public IP every time. An Elastic IP keeps the address - and
# therefore the frontend's config.js - valid across sessions.
resource "aws_eip" "console" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-console" }
}

resource "aws_eip_association" "console" {
  instance_id   = aws_instance.console.id
  allocation_id = aws_eip.console.id
}
