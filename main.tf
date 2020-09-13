provider "aws" {
  region     = "ap-south-1"
  profile    = "ver2"
}


//CREATING KEY
resource "tls_private_key" "webtls" {
  algorithm   = "RSA"
  rsa_bits    = "4096"
}


//KEY IMPORTING
resource "aws_key_pair" "webkey" {
  depends_on=[tls_private_key.webtls]
  key_name   = var.key
  public_key = tls_private_key.webtls.public_key_openssh
}


//SAVING PRIVATE
resource "local_file" "webfile" {
  depends_on = [tls_private_key.webtls]

  content  = tls_private_key.webtls.private_key_pem
  filename = "$(var.key).pem"
  file_permission= 0400
}

//VPC
resource  "aws_vpc" "myvpc"  {
     cidr_block   =  "192.168.0.0/16"
     instance_tenancy = "default"
     enable_dns_hostnames  = true

     tags = {
          Name = "webpvc"
     }
}

resource  "aws_subnet" "public"  {
     vpc_id   = "${aws_vpc.myvpc.id}"
     cidr_block = "192.168.0.0/24"
     availability_zone = "ap-south-1a"

     tags = {
          Name = "webpubsubnet"
     }
}

resource "aws_subnet" "private" {
     vpc_id = "${aws_vpc.myvpc.id}"
     cidr_block = "192.168.1.0/24"
     availability_zone = "ap-south-1b"

     tags = {
          Name = "webprivatesub"
     }
}

resource "aws_internet_gateway" "gw" {
     vpc_id = "${aws_vpc.myvpc.id}"

     tags = {
          Name = "webgw"
     }
}

resource "aws_route_table" "rt"  {
     vpc_id = "${aws_vpc.myvpc.id}"

     route {
          cidr_block = "0.0.0.0/0"
          gateway_id = "${aws_internet_gateway.gw.id}"
     }

     tags = {
          Name = "rt"
     }
}

resource "aws_route_table_association"  "asstopublic" {
     subnet_id  = aws_subnet.public.id
     route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "webserver"  {
     name = "wordpress"
     description = "Allow http"
     vpc_id      = "${aws_vpc.myvpc.id}"

     ingress {
          description = "HTTP"
          from_port = 80
          to_port   = 80
          protocol  = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
     }
     ingress {
          description = "SSH"
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks  = ["0.0.0.0/0"]
     }

     egress {
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
     }

     tags = {
          Name = "webserver_sg"
     }
}
resource "aws_security_group" "database" {
  name = "MYSQL"
     description = "Allow  MYSQL"
     vpc_id      = "${aws_vpc.myvpc.id}"


     ingress {
          description = "MYSQL"
          from_port = 3306
          to_port   = 3306
          protocol  = "tcp"
          security_groups = [aws_security_group.webserver.id]
          
       
     }
      egress {
         from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
      }

      tags = {
        Name = "webdb"
      }
}

resource "aws_eip" "nat" {
     vpc=true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.id}"
  depends_on    = [aws_internet_gateway.gw]


  tags = {
    Name = "NAT GateWay"
  }
}
resource "aws_route_table" "p" {
     vpc_id = "${aws_vpc.myvpc.id}"

     route {
          cidr_block = "0.0.0.0/0"
          nat_gateway_id = "${aws_nat_gateway.nat-gw.id}"
     }

     tags = {
          Name = "db"
     }

}


resource " aws_route_table_association" "nat" {
  subnet_id  = aws_subnet.private.id
  route_table_id = aws_route_table.p.id
}


resource "aws_instance" "wordpress" {
     ami     = "ami-000cbce3e1b899ebd"
     instance_type = "t2.micro"
     associate_public_ip_address = true
     subnet_id = aws_subnet.public.id
     vpc_security_group_ids = [aws_security_group.webserver.id]
     key_name = var.key

     tags = {
          Name = "wordpress"
     }
}

resource "aws_instance"  "mysql" {
     ami           =  "ami-08706cb5f68222d09"
     instance_type = "t2.micro"
     subnet_id     =  aws_subnet.private.id
     vpc_security_group_ids = [aws_security_group.database.id]
     key_name = var.key

     tags = {
          Name= "mysql"
     }

}