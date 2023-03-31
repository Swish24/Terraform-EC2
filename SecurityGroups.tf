#As this is a lab enviornment, let's grab our public home IP, and populate it within the security group.
#This way, we do not have port 22 open to the world wide web
data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

#Prepare our default VPC to attacht the security groups
data "aws_vpc" "default" {
  default = true
}

#Create a security group to safely allow inbound traffic.
resource "aws_security_group" "Safe_Secure_Inbound" {

  name        = "Safe Secure Inbound"
  description = "Security group for inbound and outbound traffic"
  vpc_id      = data.aws_vpc.default.id
  
}

#Define a security group rule to only allow 22/tcp (SSH) from our own public IP
resource "aws_security_group_rule" "secure_inbound_ssh" {

  security_group_id = "${aws_security_group.Safe_Secure_Inbound.id}"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "All inbound SSH from secure network"
      #source_security_group_id = "${aws_security_group.Loadbalancer_SG.id}"
      cidr_blocks = ["${chomp(data.http.ip.response_body)}/32"]
      type        = "ingress"

  #Ensure our security group has been created before attempting to create the rule
  depends_on = [
    aws_security_group.Safe_Secure_Inbound
  ]
}

#Create new rule to allow inbound 80/tcp (HTTP). This will allow connections to our webserver
resource "aws_security_group_rule" "secure_inbound_http" {

  security_group_id = "${aws_security_group.Safe_Secure_Inbound.id}"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "All inbound http from LB"
      source_security_group_id = "${aws_security_group.Loadbalancer_SG.id}"
      #cidr_blocks       = ["0.0.0.0/0"]
      type        = "ingress"
  depends_on = [
    aws_security_group.Safe_Secure_Inbound
  ]
}

#Create new rule to allow inbound 443/tcp (HTTPS). This will allow secure connections to our webserver
#Note, we are creating this rule as we will configure HTTPS in a later article. You are required to use a certificate in order to use https
resource "aws_security_group_rule" "secure_inbound_https" {

  security_group_id = "${aws_security_group.Safe_Secure_Inbound.id}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "All inbound http from LB"
      source_security_group_id = "${aws_security_group.Loadbalancer_SG.id}"
      type        = "ingress"
  depends_on = [
    aws_security_group.Safe_Secure_Inbound
  ]
}

#Allow our instance to access the internet
resource "aws_security_group" "Outbound_Connections" {
  name        = "outbound connections"
  description = "Security group from instance to internet"
  vpc_id      = data.aws_vpc.default.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [
    aws_security_group.Safe_Secure_Inbound
  ]
}

#Create a new security group for the load balancer.
#This is where we will define what traffic to allow 
resource "aws_security_group" "Loadbalancer_SG" {
  name        = "Loadbalancer SG"
  description = "From WWW to load balancer"
  vpc_id      = data.aws_vpc.default.id
    depends_on = [
    aws_security_group.Safe_Secure_Inbound
  ]
}

#==========================================================================================#
# This is commented out, however in most cases you will want to configure https to allow for secure encrypted communication with your server
# As we have not yet configured a certificate, we cannot use HTTPS.
# This will be covered in the next post of this series
# Allow 443/tcp (HTTPS) inbound.
# This will allow connections to our load balancer on https
# resource "aws_security_group_rule" "load_balancer_inbound_https" {
#       security_group_id = "${aws_security_group.Loadbalancer_SG.id}"
#       from_port   = 443
#       to_port     = 443
#       protocol    = "tcp"
#       description = "All inboun HTTPS from WWW"
#       # source_security_group_id = "${aws_security_group.Safe_Secure_Inbound.id}"
#       cidr_blocks       = ["0.0.0.0/0"]
#       type        = "ingress"
#   depends_on = [
#     aws_security_group.Loadbalancer_SG
#   ]
# }
#==========================================================================================#

# Create a security group to allow for inbound HTTP
# This will allow any IP address to communicate with our security group
resource "aws_security_group_rule" "load_balancer_inbound_http" {
      security_group_id = "${aws_security_group.Loadbalancer_SG.id}"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "All inbound HTTP from WWW"
      # source_security_group_id = "${aws_security_group.Safe_Secure_Inbound.id}"
      cidr_blocks       = ["0.0.0.0/0"]
      type        = "ingress"
  depends_on = [
    aws_security_group.Loadbalancer_SG
  ]
}

# This will allow our load balancer to send traffic to our instance security group
resource "aws_security_group_rule" "load_balancer_outbound" {

  security_group_id = "${aws_security_group.Loadbalancer_SG.id}"
      from_port   = 80
      to_port     = 80
      protocol    = "-1"
      description = "All outbound HTTP to instance SG"
      source_security_group_id = "${aws_security_group.Safe_Secure_Inbound.id}"
      type        = "egress"
  depends_on = [
    aws_security_group.Loadbalancer_SG
  ]
}


# Here we are going to dynamically retrieve the AWS EC2_INSTANCE_CONNECT service IP ranges, to allow secure access to our instance
data "http" "ec2_instance_connect_ranges" {
  request_headers = {
    Accept = "application/json"
  }
  url = "https://ip-ranges.amazonaws.com/ip-ranges.json"
}

locals {
  ip_prefixes = jsondecode(data.http.ec2_instance_connect_ranges.response_body).prefixes
  ip = join(",", [
    for a in toset(local.ip_prefixes): a.ip_prefix if a.service == "EC2_INSTANCE_CONNECT" && a.region == "us-east-1"
  ])
}

output "ec2_instance_connect_prefix" {
    value = "${local.ip}"
}


# Configures security groups to accept 22/tcp (SSH) via EC2 Instance Connect.
# This allows for SSH based sessions within the console UI
# In a production enviornment, you will also restrict access to those who have access to instances via EC2 Instance Connect
# While you could use a VPC endpoint for this, it is not covered under free tier
resource "aws_security_group" "AWS_Session_Connect" {

  name        = "AWS_Session_Connect"
  description = "Allows EC2 instance connect to connect to instance"
  vpc_id      = data.aws_vpc.default.id

  ingress = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "AWS Session Connect inbound us-east-1"
      cidr_blocks = ["${local.ip}"]
      ipv6_cidr_blocks = null,
      prefix_list_ids = null,
      security_groups = null,
      self = null,
    }                                   
  ]
}