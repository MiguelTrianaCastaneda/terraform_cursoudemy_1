variable "puerto_servidor" {
  description   = "Puerto para las instancias EC2"
  type          = number
  default       = 80

  validation {
    condition = var.puerto_servidor > 0 && var.puerto_servidor <= 65536
    error_message = "El valor del puerto debe estar comprendido entre 1 y 65536"
  }
}

variable "puerto_lb" {
  description   = "Puerto para el ALB"
  type          = number
  default       = 80
}

variable "tipo_instancia" {
  description   = "Tipo de las instancias EC2"
  type          = string
  default       = "t2.micro"
}

variable "ubuntu_ami" {
  description   = "AMI por región"
  type          = map(string)
  default = {
    us-east-1 = "ami-0778521d914d23bc1" 
    us-west-2 = "ami-04bad3c587fe60d89"
  }
}
