variable "cloudflare_zone" {
  type        = "string"
  description = "The CloudFlare zone to configure records within"
}

resource "cloudflare_record" "app" {
  domain  = var.cloudflare_zone
  name    = "app"
  value   = aws_lb.app.dns_name
  type    = "CNAME"
  proxied = true
}

output "public_hostname" {
  value       = cloudflare_record.app.hostname
  description = "The CloudFlare proxied DNS name"
}
