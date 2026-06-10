# Deploying AutoParts.az for $0/mo

Target architecture: one always-free Linux VM running the full docker-compose
stack, with the frontend on Cloudflare Pages. Total monthly cost: $0 + ~$10/year
for the domain.

```
Cloudflare Pages (frontend) ─ Cloudflare DNS ─┐
                                              ▼
                                    Oracle Cloud Always Free VM
                                    ┌──────────────────────────┐
                                    │ caddy (TLS reverse proxy)│
                                    │ autoparts-api (JVM)      │
                                    │ postgres 16              │
                                    │ minio                    │
                                    └──────────────────────────┘
```

## What you need before starting

1. **Domain** (~$10/year) — register at [Cloudflare](https://www.cloudflare.com/products/registrar/) at-cost. Pick something like `autoparts.az`.
2. **Cloudflare account** — free. You'll point DNS through Cloudflare.
3. **Oracle Cloud account** — free, requires a credit card for verification but won't charge while you stay in free limits. Sign up at [oracle.com/cloud/free](https://www.oracle.com/cloud/free/). Pick "always free" region close to your users (Frankfurt for AZ).
4. **Brevo account** — free 300 emails/day. Sign up at [brevo.com](https://www.brevo.com/) and grab the SMTP credentials from Settings → SMTP & API.
5. **GitHub or GitLab account** — for the frontend deploy from Cloudflare Pages.

## Step 1 — Provision the VM

1. In Oracle Cloud Console: **Compute → Instances → Create Instance**.
2. Shape: change image to **Canonical Ubuntu 22.04** and shape to **VM.Standard.A1.Flex** (ARM Ampere — this is the always-free option). Bump to **4 OCPUs / 24 GB memory** (still free).
3. Add your SSH public key.
4. Networking: create a new VCN if you don't have one. Open inbound TCP **80** and **443** on the VCN's security list (and **22** for SSH, scoped to your IP).
5. Create. Wait ~2 minutes. Note the public IP.

## Step 2 — Point DNS at the VM

In Cloudflare DNS for your domain, add:

| Type | Name | Value | Proxy |
|---|---|---|---|
| A | `api` | (VM public IP) | DNS only (gray cloud) |
| A | `cdn` | (VM public IP) | DNS only (gray cloud) |
| CNAME | `www` | (Cloudflare Pages target — set in step 7) | Proxied (orange cloud) |
| CNAME | `@` (apex) | (Cloudflare Pages target) | Proxied (orange cloud) |

Keep `api` and `cdn` as "DNS only" so Caddy can issue real Let's Encrypt certs (Cloudflare proxy would terminate TLS upstream and break the ACME challenge).

## Step 3 — SSH in and install Docker

```sh
ssh ubuntu@<VM-IP>

# install docker + compose plugin
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu
exit  # log out and back in so the group takes effect
```

Reconnect, then:

```sh
docker --version
docker compose version
```

## Step 4 — Open the host firewall

```sh
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

(Oracle's default Ubuntu image has an aggressive iptables policy.)

## Step 5 — Pull the code and configure env

```sh
git clone https://github.com/Shako1989/autoparts-api.git
cd autoparts-api/deploy
cp .env.example .env
nano .env  # fill in real values from your domain + Brevo + chosen passwords
```

Important values to set:

- `API_HOST` → e.g. `api.autoparts.az`
- `MEDIA_HOST` → e.g. `cdn.autoparts.az`
- `POSTGRES_PASSWORD`, `MINIO_ROOT_PASSWORD` → generate with `openssl rand -base64 32`
- `JWT_SECRET` → `openssl rand -base64 48`
- `SMTP_*` → from Brevo's SMTP settings page
- `CORS_ALLOWED_ORIGINS` → your frontend URL(s), comma-separated
- `S3_LISTINGS_PUBLIC_BASE` → `https://<MEDIA_HOST>/autoparts-listings`
- `S3_CATALOG_PUBLIC_BASE` → `https://<MEDIA_HOST>/autoparts-catalog`
- `ADMIN_PHONES` → your phone in E.164 (auto-promotes to STAFF on first OTP verify)

## Step 6 — First boot

```sh
# from autoparts-api/deploy
docker compose -f docker-compose.prod.yml --env-file .env build api
docker compose -f docker-compose.prod.yml --env-file .env up -d
docker compose -f docker-compose.prod.yml --env-file .env logs -f api
```

When the API logs `Started ApiApplication`, it's healthy. Caddy will request a
Let's Encrypt cert for both `API_HOST` and `MEDIA_HOST` on first request.

Create the buckets and set public-read:

```sh
docker exec autoparts-minio sh -c '
  mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  mc mb --ignore-existing local/autoparts-listings
  mc mb --ignore-existing local/autoparts-catalog
  mc anonymous set download local/autoparts-listings
  mc anonymous set download local/autoparts-catalog
'
```

Verify:

```sh
curl -s https://${API_HOST}/actuator/health   # → {"status":"UP"}
```

## Step 7 — Frontend on Cloudflare Pages

1. In Cloudflare dashboard: **Workers & Pages → Create → Pages → Connect to Git**.
2. Pick the `autoparts-web` repo.
3. Build settings:
   - Framework preset: **Vite**
   - Build command: `npm run build`
   - Build output directory: `dist`
   - Root directory: leave blank if `autoparts-web` is the repo root.
4. Environment variables:
   - `VITE_API_URL` → `https://api.autoparts.az/api` (note `/api` suffix — your code expects it).
5. Deploy. Cloudflare gives you a `*.pages.dev` URL. Use that as the CNAME target back in step 2 for `www` and apex.
6. Custom domain: in the Pages project settings, add `www.autoparts.az` and `autoparts.az` — Cloudflare wires the routing automatically.

## Step 8 — First login + admin promotion

1. Visit `https://www.autoparts.az/login`.
2. Enter your phone (the one in `ADMIN_PHONES`) and any email you control.
3. Click **Send code**. Brevo emails the OTP.
4. Enter the code → JWT issued, role auto-promoted to `STAFF`.
5. Admin link appears in the header → you're in `/admin`.

## Backups (do this on day 1)

Create `/home/ubuntu/backup.sh`:

```sh
#!/bin/sh
set -e
DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR=/home/ubuntu/backups
mkdir -p $BACKUP_DIR
docker exec autoparts-postgres pg_dump -U autoparts autoparts \
  | gzip > $BACKUP_DIR/postgres-$DATE.sql.gz
# Keep only the last 14 days locally; copy off-box if you can.
find $BACKUP_DIR -name 'postgres-*.sql.gz' -mtime +14 -delete
```

```sh
chmod +x /home/ubuntu/backup.sh
crontab -e
# add:  0 3 * * * /home/ubuntu/backup.sh
```

MinIO data lives in the `minio-data` named volume. `mc mirror` it to a second
location (R2, B2, S3, or another VM) for off-site backup. For v1 you can defer
this and just back up Postgres — re-uploading images from your laptop is
recoverable, deleted user accounts aren't.

## Updating the API

```sh
cd ~/autoparts-api
git pull
cd deploy
docker compose -f docker-compose.prod.yml --env-file .env build api
docker compose -f docker-compose.prod.yml --env-file .env up -d api
```

Flyway runs migrations on boot, so DB changes apply automatically.

## When you outgrow this

Migration to a normal cloud is straightforward because everything is
Docker-based:

- **Postgres** → AWS RDS, Cloud SQL, or DigitalOcean managed. Restore from
  the nightly `pg_dump`.
- **Object storage** → AWS S3 or Cloudflare R2. `mc mirror` from MinIO into the
  new bucket, then change `S3_*` env vars and redeploy. Existing DB rows
  continue to work because they store object keys, not absolute URLs (only the
  `*_PUBLIC_BASE` changes).
- **API** → ECS Fargate, Cloud Run, or any container host. Same Dockerfile.
- **Frontend** → stays on Cloudflare Pages or moves to Vercel/S3+CloudFront.

No code changes required, just env updates.

## Known limitations of this setup

- **Single point of failure.** One VM. If it goes down, the site is down. Acceptable for early launch; revisit when traffic justifies HA.
- **MinIO public reads served through Caddy.** Slower than a real CDN. For high traffic, swap MinIO for Cloudflare R2 and set `S3_CATALOG_PUBLIC_BASE` to the R2 public URL.
- **Brevo 300/day cap.** ~10 logins/registers per hour. If you grow past that, pay Brevo $25/mo for 20k/day, or wire real SMS.
- **No SMS yet.** OTP is email-only. Wire Twilio behind `OtpSender` when you have revenue.
