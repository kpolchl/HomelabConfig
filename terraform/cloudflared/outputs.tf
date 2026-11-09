output "tunnel_id" {
  description = "ID of the existing Cloudflare Tunnel."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared.nextserwewusek.id
}

output "tunnel_name" {
  description = "Name of the existing Cloudflare Tunnel."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared.nextserwewusek.name
}

output "service_hostnames" {
  description = "Public hostnames routed through the tunnel."
  value = {
    for name, svc in local.services :
    name => "${svc.subdomain}.${var.cloudflare_zone}"
  }
}

output "ssh_command" {
  description = "Example SSH command through Cloudflare Access."
  value       = "cloudflared access ssh --hostname ${local.services.ssh.subdomain}.${var.cloudflare_zone}"
}
