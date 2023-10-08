output "public_subnet_ids" {
  value   = aws_subnet.pub_subnet.*.id
}

output "private_subnet_ids" {
  value   = aws_subnet.priv_subnet.*.id
}