# Forgejo

Forgejo 15 LTS with SQLite, running as an unprivileged user. The existing
`cloudflared` network carries HTTP traffic to port 3000; no host ports are
published. Git uses HTTPS. New repositories default to private and public
registration is disabled.

## Prepare the host

Create both persistent directories before deploying. Use the UID/GID you will
set in Arcane (1001:1001 below matches this project's defaults):

```sh
sudo install -d -m 0750 -o 1001 -g 1001 /srv/docker/forgejo/data /srv/docker/forgejo/config
docker network inspect cloudflared --format '{{range .IPAM.Config}}{{println .Subnet}}{{end}}'
```

Append the network's actual subnet(s) to `REVERSE_PROXY_TRUSTED_PROXIES`. This
trusts forwarded client IP headers from containers on that network. For example,
if the command reports `172.20.0.0/16`, use
`127.0.0.0/8,::1/128,172.20.0.0/16`. Do not copy that example subnet without
checking. Reverse proxy authentication remains disabled; users log in to Forgejo.

## Deploy through Arcane

1. Commit and push these files to the repository Arcane already uses.
2. Create a Git sync named `forgejo`, with Compose path
   `opt/docker/forgejo/compose.yml` and your deployment branch.
3. Copy `.env.example` into Arcane's project environment editor and set your
   hostname, UID/GID, and trusted proxy subnets. `.env.example` is documentation;
   Arcane does not automatically use it as the project's `.env`.
4. Deploy the project. The Compose file maps environment values explicitly, so
   it does not need `env_file: .env`.

Arcane's local environment overrides survive Git sync. Keep credentials out of
Git. Image upgrades should be explicit changes to the pinned tag, with a backup
before deployment. Syncing a changed Compose file can redeploy a running project.

For manual recovery, place this project on the host, copy `.env.example` to
`.env`, fill in the values, and run `docker compose up -d` from that folder.
The external `cloudflared` network must already exist.

## First-time setup and Cloudflare

Before making the installation page reachable, create a Cloudflare Access policy
for your Forgejo hostname that only permits you. Then add a published application
route to your existing tunnel:

- Hostname: the value of `APP_DOMAIN`, such as `git.example.com`
- Service: `http://forgejo:3000`

Open the HTTPS URL and complete Forgejo's installation form. Keep SQLite and the
configured database path, and expand **Administrator Account Settings** to create
your administrator during installation. Registration can stay disabled.

The installer saves configuration and generated secrets in
`/srv/docker/forgejo/config/app.ini` and locks the installation page. Do not set
`INSTALL_LOCK=false` in Compose, which would reopen it on subsequent starts.
Verify you can log in, the installation page is closed, and registration is
disabled. Enable two-factor authentication for your account.

After installation, remove the temporary browser-only Access gate if you want
ordinary HTTPS Git clients to use this hostname. Forgejo then handles repository
authentication itself. Keeping Cloudflare Access requires additional client
authentication; a Forgejo token alone does not satisfy an Access login page.
SMTP is not configured, so email notifications and email password recovery are
unavailable until you add mail settings.

## Using Forgejo as an Arcane Git source

Create a dedicated Forgejo account with read access only to the deployment
repository, then add it to Arcane's Git repositories using a personal access
token. Store the token in Arcane's repository credentials.

For this local Arcane instance, the repository URL can be
`http://forgejo:3000/OWNER/REPOSITORY.git` because both containers share the Docker
network. This connection carries credentials over the local Docker network and
avoids the Cloudflare route. Use the public HTTPS URL for remote clients.

Keep a copy of this infrastructure repository outside Forgejo so that restoring
Forgejo does not require a running Forgejo instance. Arcane Git sync deploys
Compose projects; it does not back up Forgejo's application data.

## Backups and upgrades

Pause automatic deployment during a backup or restore. Stop Forgejo, back up all
of `/srv/docker/forgejo` together, and start it again. This captures a consistent
SQLite database alongside repositories, attachments, and configuration secrets.
Store backups off-server, preserve ownership and permissions, and test a restore.

Restore both `data` and `config` while Forgejo is stopped, then start the same
image version used for that backup. Retain the matching Compose file and
environment values. An image downgrade alone cannot undo a database migration.

Cloudflare's request size limits also apply to HTTPS pushes, LFS, and package
uploads. Large binary transfers may need a separate private access route.

## References

- [Forgejo Docker installation and v15 proxy defaults](https://forgejo.org/docs/v15.0/admin/installation/docker/)
- [Forgejo configuration](https://forgejo.org/docs/v15.0/admin/config-cheat-sheet/)
- [Arcane Git sync and environment overrides](https://getarcane.app/docs/features/projects)
- [Cloudflare upload limits](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-413/)
