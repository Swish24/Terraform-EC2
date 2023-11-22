//Define the AMI that we will use in our instance configuration
data "aws_ami" "amz-linux-ami" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name ="name"
        values = [
            "al2023-ami-2023.*"
        ]
    }
}

//Here we will define our EC2 resource type. We ant to use a resource type as it will persist through changes
resource "aws_instance" "ec2_instance" {
    //Select the EC2 instance size
    instance_type = "t2.micro"

    //Here we will define our AMI variable as we configured previously
    ami = data.aws_ami.amz-linux-ami.id

    //Here we will configure our security group rules used for the instance
    vpc_security_group_ids = ["${aws_security_group.Safe_Secure_Inbound.id}","${aws_security_group.AWS_Session_Connect.id}",
    "${aws_security_group.Outbound_Connections.id}"]

    //Name of our SSH key pair
    key_name ="AWSInstanceKey"

    //Define the root EBS volume parameters
    root_block_device {

    //EBS volume size for our root device
    volume_size = 30 # in GB <<----- I increased this!
    
    //Configure GP3 as the volume type
    volume_type = "gp3"

    //Encryt the volume using KMS. We are going to select no, however this will be covered in a later article
    encrypted   = false

    //Delete the volume when the instance is deleted
    delete_on_termination = true
    }

    //Because we defined our global default name and owner tags, we are not going to configure those here
    //Here we are going to set our "Name" to our variable of instance_name, and an ALB value of "true". We will use this later when we configure our EC2 instance groups to be used within our ALB targets
    tags = {
        Name = "${var.instance_name}",
        ALB = "true"
    }

    //Here we have a custom configured user_data configuration to pass to the instance.
    //The instance will execute this script upon booting into the OS, and perform these commands
    //Here we are running all latest updates from the configured distributions. We are then going to install docker & docker compose.
    //Then we are going to configure an nginx linuxserver.io container
    user_data = "${file("ec2-userdata.sh")}"

    //This option is important, this is if we want to recreate our instance if our user-data file has been modified.
    //This will help enusre the fleet has the most latest user-data changes
    user_data_replace_on_change = true

    //Here we are going to add a dependency, this will ensure the security groups we want are configured already
    depends_on = [
      aws_security_group.Safe_Secure_Inbound,
      aws_security_group.AWS_Session_Connect,
      aws_security_group.Outbound_Connections,
      aws_security_group.Loadbalancer_SG
    ]
}

//Create an output to print out our instance DNS name
output "ec2_instance_public_dns" {
  value = aws_instance.ec2_instance.public_dns
}

//Create an output to print out our load balancer DNS Name
output "lb_public_dns" {
    value = aws_lb.load_balancer.dns_name
}