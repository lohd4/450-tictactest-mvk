# The Learner Lab hands out a ready-made default VPC and we are not allowed to
# build much of our own, so the instance lives in the default VPC's first
# subnet. That is also plenty for a single public web server.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "console" {
  name_prefix = "${var.project_name}-console-"
  description = "TicTacTest web console: public HTTP, optional SSH, outbound for artefacts"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "${var.project_name}-console" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- ingress ----------------------------------------------------------------
# Every open port is justified. Anything not listed here stays closed.

# Port 80 is the only port the public needs: nginx serves the version endpoint
# and reverse-proxies the terminal (including its WebSocket). It must be open
# to the world because anyone with the link should be able to play.
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.console.id
  description       = "Web console and version endpoint (nginx)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Deliberately NOT opened: 7681 (ttyd). ttyd binds to 127.0.0.1 and is only
# reachable through nginx, so exposing it would just be a second, unprotected
# way in with no version endpoint and no CORS header.

# SSH is off by default - deployments run through SSM. It can be enabled for a
# specific address when something needs debugging on the box itself.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_ingress_cidrs)

  security_group_id = aws_security_group.console.id
  description       = "Optional SSH for debugging"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# --- egress -----------------------------------------------------------------
# Outbound is open because the instance has to reach: the Amazon Linux package
# mirrors (Corretto, nginx), GitHub (ttyd binary) and the AWS APIs for S3 and
# SSM. Restricting this to prefix lists would be the next refinement.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.console.id
  description       = "Package mirrors, GitHub, S3 and SSM endpoints"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
