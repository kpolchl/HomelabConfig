# Services exposed through the Cloudflare Tunnel.
#
# Each entry becomes:
#   - a DNS CNAME: <subdomain>.<cloudflare_zone>
#   - a tunnel ingress rule
#   - a Cloudflare Access application, if access = true
#
# Set access = false for services whose own authentication is enough and
# whose clients cannot complete the Access browser login (e.g. the Immich
# mobile app or the WcsStudio API).
#
# Add a new service by adding an entry here. The catch-all 404 rule is
# appended automatically.
locals {
  services = {
    immich = {
      subdomain     = "immichdev"
      service       = "http://host.containers.internal:2283"
      app_type      = "self_hosted"
      no_tls_verify = false
      access        = false
    }
    wcsstudio = {
      subdomain     = "wcsstudiodev"
      service       = "http://host.containers.internal:4000"
      app_type      = "self_hosted"
      no_tls_verify = false
      access        = false
    }
    cockpit = {
      subdomain     = "cockpitdev"
      service       = "https://host.containers.internal:9090"
      app_type      = "self_hosted"
      no_tls_verify = true
      access        = true
    }
    ssh = {
      subdomain     = "sshdev"
      service       = "ssh://host.containers.internal:22"
      app_type      = "ssh"
      no_tls_verify = false
      access        = true
    }
  }

  access_include = concat(
    [{ email = { email = var.cloudflare_email } }],
    [for email in var.cloudflare_access_emails : { email = { email = email } }],
    var.cloudflare_access_email_domain == "" ? [] : [
      { email_domain = { domain = var.cloudflare_access_email_domain } }
    ],
    var.cloudflare_github_organization == "" ? [] : [
      {
        github_organization = merge(
          {
            identity_provider_id = var.cloudflare_github_idp_id
            name                 = var.cloudflare_github_organization
          },
          var.cloudflare_github_team == "" ? {} : { team = var.cloudflare_github_team }
        )
      }
    ]
  )
}

# Looks up the existing tunnel created by Ansible/cloudflared.
# Terraform does not create the tunnel or its token.
data "cloudflare_zero_trust_tunnel_cloudflared" "nextserwewusek" {
  account_id = var.cloudflare_account_id

  filter = {
    name = var.cloudflare_tunnel_name
  }
}

# Configures the existing tunnel ingress rules.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "nextserwewusek" {
  account_id = var.cloudflare_account_id
  tunnel_id  = data.cloudflare_zero_trust_tunnel_cloudflared.nextserwewusek.id

  config = {
    ingress = concat(
      [
        for name, svc in local.services : merge(
          {
            hostname = "${svc.subdomain}.${var.cloudflare_zone}"
            service  = svc.service
          },
          svc.no_tls_verify ? {
            origin_request = {
              no_tls_verify = true
            }
          } : {}
        )
      ],
      [{ service = "http_status:404" }]
    )
  }
}

# Creates one CNAME per service, all pointing at the tunnel.
resource "cloudflare_dns_record" "service" {
  for_each = local.services

  zone_id = var.cloudflare_zone_id
  name    = "${each.value.subdomain}.${var.cloudflare_zone}"
  content = "${data.cloudflare_zero_trust_tunnel_cloudflared.nextserwewusek.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel: ${each.key}"
}

# Protects services marked with access = true using Cloudflare Access.
resource "cloudflare_zero_trust_access_application" "service" {
  for_each = var.cloudflare_access_enabled ? {
    for name, svc in local.services : name => svc if svc.access
  } : {}

  account_id                = var.cloudflare_account_id
  name                      = "${each.key} (${var.cloudflare_zone})"
  domain                    = "${each.value.subdomain}.${var.cloudflare_zone}"
  type                      = each.value.app_type
  session_duration          = "24h"
  allowed_idps              = var.cloudflare_github_idp_id == "" ? null : [var.cloudflare_github_idp_id]
  auto_redirect_to_identity = var.cloudflare_github_idp_id != ""

  lifecycle {
    precondition {
      condition     = var.cloudflare_github_organization == "" || var.cloudflare_github_idp_id != ""
      error_message = "cloudflare_github_idp_id must be set when cloudflare_github_organization is used."
    }
  }

  policies = [
    merge(
      {
        name       = "Allow ${each.key}"
        decision   = "allow"
        precedence = 1
        include    = local.access_include
      },
      each.value.app_type == "ssh" ? {
        connection_rules = {
          ssh = {
            usernames = var.cloudflare_ssh_usernames
          }
        }
      } : {}
    )
  ]
}
