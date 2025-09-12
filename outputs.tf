# ---------------- Outputs ----------------
output "ec2_public_ip" {
  value = aws_instance.sonar_ec2.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.sonar_bucket.bucket
}

output "terraform_state_file" {
  value = abspath("terraform.tfstate")
}