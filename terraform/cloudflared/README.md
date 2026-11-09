# Cloudflare Tunnel

Terraform configuration for the **existing** homelab Cloudflare Tunnel.

The tunnel itself is created and run by Ansible/cloudflared. Terraform only
manages the tunnel configuration, DNS records, and Cloudflare Access
applications. It does **not** create the tunnel or its token.

Terraform looks the tunnel up by name via the
`cloudflare_zero_trust_tunnel_cloudflared` data source.

## Services

| Service   | Public hostname                          | Origin                                      | Access |
|-----------|------------------------------------------|---------------------------------------------|--------|
| Immich    | `immichdev.<cloudflare_zone>`            | `http://host.containers.internal:2283`      | No     |
| WcsStudio | `wcsstudiodev.<cloudflare_zone>`         | `http://host.containers.internal:4000`      | No     |
| Cockpit   | `cockpitdev.<cloudflare_zone>`           | `https://host.containers.internal:9090`     | Yes    |
| SSH       | `sshdev.<cloudflare_zone>`               | `ssh://host.containers.internal:22`         | Yes    |

Cockpit uses a self-signed certificate, so its ingress rule sets
`origin_request.no_tls_verify = true`.

Every hostname gets a proxied `CNAME` pointing at
`<tunnel-id>.cfargotunnel.com`.

Cloudflare Access is only created for services with `access = true` in the
`local.services` map. Immich and WcsStudio are intentionally left out so the
Immich mobile app, API clients, and share links keep working; their own
authentication protects them. The global `cloudflare_access_enabled` switch
still disables Access for every service.

The catch-all ingress rule returns `http_status:404`.

## Access identity

Cockpit and SSH are protected by Cloudflare Access and use the GitHub OAuth
login method. The policy allows:

- the email in `cloudflare_email`
- any extra emails in `cloudflare_access_emails`
- optionally, a GitHub organization/team

GitHub OAuth returns the account's **primary email**, so if the GitHub account
has several verified emails, list all of them:

```hcl
cloudflare_email = "you@example.com"
cloudflare_access_emails = [
  "you@work.example.com",
]
```

The policy uses OR logic, so any listed email passes. If GitHub returns an
address that is not in the list, Access shows `That account does not have
access`.

The GitHub IdP is pinned, so the app skips the login-method picker:

```hcl
cloudflare_github_idp_id = "REPLACE_WITH_GITHUB_IDP_ID"
```

A GitHub organization/team rule is optional and only needed if you belong to
an organization:

```hcl
# cloudflare_github_organization = "your-github-org"
# cloudflare_github_team         = "optional-team"
```

## Usage

Set the existing tunnel name in `terraform.tfvars` (defaults to
`homelab`):

```hcl
cloudflare_tunnel_name = "homelab"
```

Then:

```sh
export TF_VAR_cloudflare_token="..."

terraform init
terraform plan
```

The tunnel must already exist and be remotely managed (`config_src = "cloudflare"`).
The Ansible `cloudflared` role owns the connector and its token.

## SSH

Connect through the tunnel with:

```sh
cloudflared access ssh --hostname sshdev.<cloudflare_zone>
```

Or add an SSH config entry:

```sshconfig
Host ssh-homelab
    HostName sshdev.<cloudflare_zone>
    ProxyCommand cloudflared access ssh --hostname %h
    User root
```
