output "vpc_ips" {
  value = {
    platform = "10.0.0.0/16"
    productA = "10.5.0.0/16"
  }
}

output "platform_subnet_ips" {
  value = {
    a_global  = "10.0.0.0/20"
    b_global  = "10.0.16.0/20"
    c_global  = "10.0.32.0/20"
    a_private = "10.0.128.0/20"
    b_private = "10.0.144.0/20"
    c_private = "10.0.160.0/20"
  }
}

output "productA_subnet_ips" {
  value = {
    a_global  = "10.5.0.0/20"
    b_global  = "10.5.16.0/20"
    c_global  = "10.5.32.0/20"
    a_private = "10.5.128.0/20"
    b_private = "10.5.144.0/20"
    c_private = "10.5.160.0/20"
  }
}
