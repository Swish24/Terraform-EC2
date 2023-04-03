variable "defaultEnviornmentName" {
  type = string
  default = "Development"
  description = "The default supplied development envionrment name"
}

variable "defaultTagOwner" {
    type = string
    default = "DJ"
    description = "the default supplied deveopment owner name"
}

variable "instance_name" {
    type = string
    default = "EC2Demo"
    description = "Name of our EC2 instance that we are going to confiugre"
}

variable "domain_name" {
  type = string
  # Please note, you will provide any DNS name you own and plan to use
  default = "blog.sandbox.dvsn.ai"
  description = "Sandbox enviornment"
}