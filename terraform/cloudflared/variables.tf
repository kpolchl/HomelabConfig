variable "cloudflare_zone" {
  description = "Domain used to expose services."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID for cloudflare_zone."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Email address allowed through Cloudflare Access."
  type        = string
  sensitive   = true
}

variable "cloudflare_access_email_domain" {
  description = "Optional email domain allowed through Cloudflare Access (e.g. example.com). Leave empty to disable."
  type        = string
  default     = ""
}

variable "cloudflare_access_emails" {
  description = "Additional email addresses allowed through Cloudflare Access."
  type        = list(string)
  default     = []
}

variable "cloudflare_github_idp_id" {
  description = "ID of the GitHub identity provider. Leave empty to keep email-only policies and all login methods."
  type        = string
  default     = ""
}

variable "cloudflare_github_organization" {
  description = "GitHub organization allowed through Cloudflare Access. Leave empty to use email-based policies only."
  type        = string
  default     = ""
}

variable "cloudflare_github_team" {
  description = "Optional GitHub team within cloudflare_github_organization."
  type        = string
  default     = ""
}

variable "cloudflare_token" {
  description = "Cloudflare API token used by the provider."
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_name" {
  description = "Name of the existing Cloudflare Tunnel created by Ansible/cloudflared."
  type        = string
  default     = "homelab"
}

variable "cloudflare_access_enabled" {
  description = "Create Cloudflare Access applications for services that have access = true."
  type        = bool
  default     = true
}

variable "cloudflare_ssh_usernames" {
  description = "Unix usernames allowed to connect over SSH through Cloudflare Access."
  type        = list(string)
  default     = ["root"]
}
