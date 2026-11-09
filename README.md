# Homelab

One box, a handful of services, and everything in code so I can rebuild it from scratch whenever I break it.

Ansible sets up the host and runs the services as rootless Podman Quadlet units. Terraform handles the Cloudflare side: tunnel ingress, DNS, and Access policies. The tunnel itself (and its token) belongs to the Ansible `cloudflared` role, so Terraform only configures an existing tunnel and never creates one.

## What's running

| Service   | Ansible role | Address             | Behind Cloudflare Access |
|-----------|--------------|---------------------|:------------------------:|
| Immich    | `immich`     | `immich.<zone>`     | no  |
| WcsStudio | `wcs_studio` | `wcsstudio.<zone>`  | no  |
| Cockpit   | `cockpit`    | `cockpit.<zone>`    | yes |
| SSH       | host sshd + `cloudflared` | `ssh.<zone>` | yes |

Tunnel details live in [`terraform/cloudflared/README.md`](terraform/cloudflared/README.md).

## Repo map

```text
.
├── ansible/
│   ├── site.yml                  # main playbook
│   ├── inventory/                # hosts.yml.example lives here
│   ├── group_vars/servers/       # vars.yml (plain) + vault.yml (encrypted)
│   └── roles/                    # common, firewalld, cockpit, immich,
│                                 # wcs_studio, cloudflared
├── terraform/cloudflared/        # ingress, DNS, Access apps
├── Makefile
└── README.md
```

## Before you start

- A fresh Rocky Linux 10 install
- Root login over SSH key
- Ansible 2.15+ (with `ansible-vault`) and Terraform 1.2+
- `cloudflared` on your laptop, for SSH through the tunnel
- A Cloudflare account with a zone and an existing remotely-managed tunnel

## Secrets

Nothing sensitive gets committed. These files stay on your machine (or encrypted):

| File | What's inside |
|------|---------------|
| `ansible/group_vars/servers/vault.yml` | Ansible secrets, encrypted |
| `ansible/.vault_pass` | The vault password |
| `ansible/inventory/hosts.yml` | Real host address and user |
| `terraform/cloudflared/terraform.tfvars` | Cloudflare token and account values |
| `terraform/cloudflared/terraform.tfstate` | State, which includes secrets |

Set up the vault password:

```sh
printf '%s' 'your-vault-password' > ansible/.vault_pass
chmod 600 ansible/.vault_pass
```

Edit the encrypted vars any time with `make vault-edit`.

Then copy the Terraform example and fill in your values:

```sh
cp terraform/cloudflared/terraform.tfvars.example terraform/cloudflared/terraform.tfvars
```

## Getting it running

**1. Inventory**

```sh
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
```

Put in your host, address, and SSH user.

**2. Put your SSH key on the server**

```sh
ssh-copy-id -i ~/.ssh/key.pub user@addr
```

**3. Dry run, then deploy**

```sh
make check    # nothing gets changed
make deploy   # host + services
```

**4. Cloudflare**

```sh
make tf-init
make tf-plan    # read-only, have a look first
make tf-apply
```

## SSH through the tunnel

Once Access is in place, no ports need to be open to reach the box:

```sh
cloudflared access ssh --hostname ssh.<zone>
```

For everyday use, add it to `~/.ssh/config` and just run `ssh homelab`:

```sshconfig
Host homelab
    HostName ssh.<zone>
    User root
    ProxyCommand cloudflared access ssh --hostname %h
```