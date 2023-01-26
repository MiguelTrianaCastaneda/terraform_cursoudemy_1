# -------------------------
# Define el provider de AWS
# -------------------------
provider "aws" {
  region = "us-east-1"
}

# ----------------------------------------------------------
# Define un DataSource para encontrar la AZ "A" de la region
# ----------------------------------------------------------
data "aws_subnet" "az_a"{
  availability_zone = "us-east-1a"
}


# ----------------------------------------------------------
# Define un DataSource para encontrar la AZ "B" de la region
# ----------------------------------------------------------
data "aws_subnet" "az_b"{
  availability_zone = "us-east-1b"
}


# -----------------------------------------------------------
# Define una instancia EC2 con AMI Ubuntu para el servidor 1
# -----------------------------------------------------------
resource "aws_instance" "servidor_1" {    
  ami           = var.ubuntu_ami["us-east-1"] 
  instance_type = var.tipo_instancia
  subnet_id     = data.aws_subnet.az_a.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  // Escribimos un "here document" que es
  // usado durante la inicialización
  user_data = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers! Soy servidor 1" > index.html
              nohup busybox httpd -f -p ${var.puerto_servidor} &
              EOF
  
  tags = {
    Name = "servidor-triana-1"
  }
} 

# -----------------------------------------------------------
# Define una instancia EC2 con AMI Ubuntu para el servidor 2
# -----------------------------------------------------------
resource "aws_instance" "servidor_2" {    
  ami           = var.ubuntu_ami["us-east-1"]  
  instance_type = var.tipo_instancia 
  subnet_id = data.aws_subnet.az_b.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  // Escribimos un "here document" que es
  // usado durante la inicialización
  user_data = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers! Soy servidor 2" > index.html
              nohup busybox httpd -f -p ${var.puerto_servidor} &
              EOF
  
  tags = {
    Name = "servidor-triana-2"
  }
} 


# ------------------------------------------------------
# Define un grupo de seguridad con acceso al puerto 8080
# ------------------------------------------------------
resource "aws_security_group" "mi_grupo_de_seguridad" {
  name   = "primer-servidor-sg"
  ingress {
    security_groups = [ aws_security_group.alb.id ]
    description = "Acceso al puerto 8080 desde el exterior"
    from_port   = var.puerto_servidor
    to_port     = var.puerto_servidor
    protocol    = "TCP"
  }
}

# ------------------------------------------------------
# Define un ALB como balanceador de aplicación
# ------------------------------------------------------
resource "aws_alb" "alb" {
  load_balancer_type  = "application"
  name                = "terraformers-alb"
  security_groups     = [aws_security_group.alb.id]
  subnets = [ data.aws_subnet.az_a.id, data.aws_subnet.az_b.id]
}
  
# ------------------------------------------------------
# Define un grupo de seguridad para el ALB
# ------------------------------------------------------
resource "aws_security_group" "alb" {
  name   = "alb-sg"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Acceso al puerto 80 desde el exterior"
    from_port   = var.puerto_lb
    to_port     = var.puerto_lb
    protocol    = "TCP"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Acceso al puerto 8080 de nuestras instancias"
    from_port   = var.puerto_servidor
    to_port     = var.puerto_servidor
    protocol    = "TCP"
  }
  
}

# --------------------------------------------------------------------------
# Define la VPC por defecto de nuestra cuenta AWS a traves de un DataSource
# --------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# ------------------------------------------------------------------------------
# Define el Target Group que comprende las 2 instancias que gestionara
# el ALB: se utiliza para enrutar solicitudes a uno o más objetivos registrados
# ------------------------------------------------------------------------------

resource "aws_alb_target_group" "this" {
  name      = "terraformers-alb-target-group"
  port      = var.puerto_lb
  vpc_id    = data.aws_vpc.default.id
  protocol  = "HTTP"

  health_check {
    enabled   = true
    matcher   = "200"
    path      = "/"
    port      = var.puerto_servidor
    protocol  = "HTTP"
  }
}

# --------------------------------------------------------------------------
# Creamos en attachment del servidor 1 contra su target group
# --------------------------------------------------------------------------

resource "aws_alb_target_group_attachment" "servidor_1" {
  target_group_arn  = aws_alb_target_group.this.arn
  target_id         = aws_instance.servidor_1.id
  port              = var.puerto_servidor
}

# --------------------------------------------------------------------------
# Creamos en attachment del servidor 2 contra su target group
# --------------------------------------------------------------------------

resource "aws_alb_target_group_attachment" "servidor_2" {
  target_group_arn  = aws_alb_target_group.this.arn
  target_id         = aws_instance.servidor_2.id
  port              = var.puerto_servidor
}

# --------------------------------------------------------------------------
# Creamos el listener que dirige todas las peticiones entrantes del ALB
# hacia las instancias
# --------------------------------------------------------------------------

resource "aws_alb_listener" "this" {
  load_balancer_arn = aws_alb.alb.arn
  port              = var.puerto_lb
  protocol          = "HTTP"

  default_action {
    target_group_arn  = aws_alb_target_group.this.arn
    type              = "forward"
  }     
  
}
