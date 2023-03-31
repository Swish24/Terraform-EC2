//Add our EC2 instance as an input, this will allow us to attach it to a target group
data "aws_instance" "ec2_instance" {
    instance_id = "${aws_instance.ec2_instance.id}"
  filter {
    name   = "tag:ALB"
    values = ["true"]
  }
  depends_on = [
  aws_instance.ec2_instance
  ]
}

//Provide the subnets available within our VPC
data "aws_subnets" "all" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

//Define our load balancer
resource "aws_lb" "load_balancer" {
  //Put it in all subnets received by above
  subnets         = data.aws_subnets.all.ids

  //Name of the load balancer
  name               = "EC2Demo"
  //This is an internet facing load balancer, so we will select false
  internal           = false

  //Define our load balancer type, there are three, Application, Network and Gateway
  //As we are running a web server, we will choose application
  load_balancer_type = "application"

  //Define the security groups attached to our load balancer.
  //We are going to attach the load balancer SG we created earlier.

  security_groups    = ["${aws_security_group.Loadbalancer_SG.id}"]
  #subnets            = [for subnet in aws_subnet.public : subnet.id]

  //Deletion protection ensures this requires an extra step before deleting it
  enable_deletion_protection = false

}


//Define our target group that the load balancer will direct traffic to
resource "aws_lb_target_group" "target_group" {
  name     = "EC2-Target-Group"
  //The load balancer will forward the http traffic to the webserver
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}


//Attach our target group to the load balancer
resource "aws_lb_target_group_attachment" "attachment_group" {
  count            = length(data.aws_instance.ec2_instance.*.id)
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = element(data.aws_instance.ec2_instance.*.id, count.index)
}

//Define an http listener for our load balancer.
//This will allow our load balancer to expect traffic on this port
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

    //Forward the traffic to our target group we previously defined.
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.target_group.arn
    }

    //Make sure our load balancer is created before attempting to create this
    depends_on = [
        aws_lb.load_balancer
    ]
}