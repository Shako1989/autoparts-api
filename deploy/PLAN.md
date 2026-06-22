# AutoParts.az — Deployment Plan (Beginner-Friendly)

This is a step-by-step plan for getting AutoParts.az live on the public internet without prior DevOps experience. Every step explains **what** you're doing, **why**, and **how to verify** it worked.

Total cost: **~$10/year** (just the domain name). Everything else uses real always-free tiers.

Total time: about **3–4 hours** spread across phases. You can stop and resume after any phase.

---

## At-a-glance

```
your-domain.az                              Cloudflare Pages (free)
    │                                       (serves the React frontend)
    │
    └─ www.your-domain.az ─────────────────┘
    │
    └─ api.your-domain.az ──┐
    │                       │
    └─ cdn.your-domain.az ──┤
                            ▼
                     Oracle Cloud "Always Free" VM
                     (4 ARM CPUs, 24 GB RAM, $0 forever)
                     ┌─────────────────────────────┐
                     │  Caddy (TLS termination)    │
                     │  ─ AutoParts API (Spring)   │
                     │  ─ PostgreSQL 16            │
                     │  ─ MinIO (image storage)    │
                     └─────────────────────────────┘
                                  │
                                  │  sends OTP emails via
                                  ▼
                          Brevo SMTP (free 300/day)
```

---

## Quick glossary (read once)

| Term | Plain-English meaning |
|---|---|
| **Domain** | Your website's name, like `autoparts.az`. You rent it for ~$10/year. |
| **DNS** | The phone book of the internet. It maps your domain to an IP address. |
| **VM (Virtual Machine)** | A computer in the cloud that you rent. Oracle gives one away for free, forever. |
| **SSH** | A way to log into a remote computer from your Mac's terminal. |
| **Docker** | Software that packages apps into isolated boxes (containers) so they always run the same way. |
| **docker compose** | A tool to start several containers together with one command. |
| **Container** | A running instance of a Docker image. Think "one running process with its own filesystem." |
| **Image** | The packaged-up template a container is started from. |
| **TLS / HTTPS** | The padlock in the browser. Required for modern websites. |
| **Caddy** | A small web server that gets us free HTTPS automatically. |
| **PostgreSQL** | The database where users, parts, listings, etc. are stored. |
| **MinIO** | A small "S3-compatible" server that holds uploaded images. |
| **SMTP** | The protocol for sending email. Brevo runs an SMTP server we'll point at. |
| **OTP** | One-Time Password. The 6-digit code we email for login. |
| **Cloudflare Pages** | Free hosting for your React frontend, deploys from GitHub automatically. |
| **`.env` file** | A text file holding secret values (passwords, API keys). Never commit it. |

---

## Phase 0 — Prerequisites (15 min)

Before you start, have ready:

1. **A credit card.** Required for Oracle Cloud's identity verification. **They will not charge you** while you stay in the free tier. Cloudflare's domain registration costs ~$10/year and bills the card.
2. **A personal email address** you can check. You'll create accounts at Cloudflare, Oracle, and Brevo.
3. **A laptop with SSH installed.** macOS has it by default — open Terminal and type `ssh` to confirm.
4. **A GitHub account** with access to your two repos (`autoparts-api` and `autoparts-web`).
5. **About an hour of uninterrupted time per phase.**

**Verify you're ready:**

```sh
ssh -V                  # should print a version, not "command not found"
docker --version        # not strictly needed but useful — should also print a version
```

---

## Phase 1 — Register a domain at Cloudflare (20 min)

**What:** Buy a domain name. We use Cloudflare because they sell at-cost (no markup) and DNS+TLS are integrated and free.

**Why:** Without a domain, browsers can't reach your site by name, and you can't get a free TLS certificate from Let's Encrypt.

**Cost:** ~$10/year.

### Steps

1. Go to **https://dash.cloudflare.com/sign-up** and create an account.
2. Verify your email when prompted.
3. In the dashboard, click **Domain Registration → Register Domains**.
4. Search for a domain. Suggestions:
   - `autoparts.az` (premium TLD, may be expensive)
   - `autoparts-az.com`
   - `getautoparts.com`
   - anything you like
5. Add to cart, complete checkout with your card.
6. Wait 2–5 minutes for the domain to appear under **Websites** in your dashboard.

### Verify

In the Cloudflare dashboard, click **Websites** in the left sidebar. Your domain should appear. Click into it — you'll see the **DNS Records** tab where we'll add records later.

### Stuck?

- "Domain not available" → pick another name.
- "Payment failed" → check your card supports international charges.

---

## Phase 2 — Create an Oracle Cloud account (30 min)

**What:** Sign up for Oracle's free cloud tier so we can get a free VM.

**Why:** Oracle's "Always Free" tier includes an ARM VM with 4 CPUs and 24 GB of RAM. This is dramatically more than other free tiers (Render, Fly, etc.) and never expires.

**Cost:** $0. Card is for identity verification only.

### Steps

1. Go to **https://www.oracle.com/cloud/free/** and click **Start for free**.
2. Pick your home country (e.g. Azerbaijan). **This decides your data residency — pick correctly because you can't change it later.**
3. Pick a **Home Region** geographically close to you. Frankfurt or Amsterdam are common picks for Azerbaijan / Europe. **The region also can't be changed later.**
4. Fill in personal details, verify your phone via SMS, add your credit card.
5. Sign in to the **OCI Console** at https://cloud.oracle.com. You'll land on a dashboard.

### Verify

In the OCI Console, click the hamburger menu (top-left) → **Compute → Instances**. You should see an empty list (no instances yet). You're in.

### Stuck?

- "Account under review" → Oracle sometimes manually reviews new accounts. This can take a few hours. Wait, check email.
- Can't find ARM machines later → some regions are out of always-free ARM capacity. You may need to retry creating the VM at different times of day, or pick a less-popular region from the start.

---

## Phase 3 — Provision the VM (30 min)

**What:** Spin up the actual computer that will run AutoParts.az.

**Why:** This is where the API + database + image storage will live. One machine running everything via Docker.

**Cost:** $0 (Always Free tier).

### Steps

1. In OCI Console: **Compute → Instances → Create Instance**.
2. **Name:** `autoparts-prod` (or anything).
3. **Image and shape** section → click **Edit**:
   - **Image:** select **Canonical Ubuntu 22.04**.
   - **Shape:** click **Change shape**, switch to **Ampere** (ARM), and pick **VM.Standard.A1.Flex**.
   - Bump **OCPU count** to **4** and **Memory** to **24 GB** — both still within the always-free allowance.
4. **Add SSH keys** section:
   - Choose **Generate a key pair for me**.
   - Click **Save private key** — this downloads a `.key` file. **Keep this file safe; you cannot redownload it.**
   - Move it to `~/.ssh/`: `mv ~/Downloads/ssh-key-*.key ~/.ssh/oracle-autoparts.key` and lock permissions: `chmod 600 ~/.ssh/oracle-autoparts.key`.
5. **Networking** section:
   - Leave defaults (creates a new VCN and subnet).
   - Ensure **Assign a public IPv4 address** is checked.
6. Click **Create** at the bottom. Wait 1–2 minutes for the instance status to flip to **Running** (green).
7. **Copy the public IP address** — it's shown on the instance page. You'll use it for SSH and DNS.

### Open ports 80 and 443

By default, only port 22 (SSH) is open. We need 80 (HTTP) and 443 (HTTPS).

1. In the instance page, click the **Subnet** link under "Primary VNIC".
2. Click on the **Default Security List**.
3. Under **Ingress Rules**, click **Add Ingress Rules** and add two rules:
   - Source CIDR `0.0.0.0/0`, IP Protocol `TCP`, Destination Port Range `80`.
   - Source CIDR `0.0.0.0/0`, IP Protocol `TCP`, Destination Port Range `443`.
4. Save.

### Verify

```sh
ssh -i ~/.ssh/oracle-autoparts.key ubuntu@<your-public-ip>
```

You should land in a shell that says `ubuntu@autoparts-prod:~$`. Type `exit` to come back.

### Stuck?

- "Out of capacity" → Oracle is full for that shape in that region. Try again later, or try a slightly smaller shape (2 OCPU / 12 GB).
- SSH refused → ports might still be propagating; wait 30 seconds and retry.
- SSH `Permission denied (publickey)` → check the key file is in `~/.ssh/`, has mode 600, and you're using `ubuntu` (not `root`) as the username.

---

## Phase 4 — Point your domain at the VM (15 min)

**What:** Tell Cloudflare DNS to route `api.your-domain` and `cdn.your-domain` to the Oracle VM's IP.

**Why:** Without DNS, browsers can't find your VM. The `api` subdomain will serve the backend API; `cdn` will serve uploaded images.

**Cost:** $0.

### Steps

1. In Cloudflare dashboard → click your domain → **DNS → Records → Add record**.

2. Add the API record:
   - **Type:** A
   - **Name:** `api`
   - **IPv4 address:** your Oracle VM's public IP from Phase 3
   - **Proxy status:** **DNS only** (gray cloud, click the orange cloud to toggle off)
   - **TTL:** Auto
   - Save.

3. Add the media record:
   - **Type:** A
   - **Name:** `cdn`
   - **IPv4 address:** same VM IP
   - **Proxy status:** **DNS only** (gray cloud)
   - Save.

**Important:** keep these two as "DNS only" (gray cloud). Caddy needs to talk directly to Let's Encrypt to fetch TLS certificates; the Cloudflare proxy interferes with that. We'll add the frontend records with the orange cloud later.

### Verify

```sh
dig api.your-domain.az +short
dig cdn.your-domain.az +short
```

Both should print your VM's IP. If they print nothing, wait 1–2 minutes and retry (DNS propagation).

### Stuck?

- DNS not resolving after 10 minutes → check there are no typos in the A records.
- `dig` not installed → try `nslookup api.your-domain.az` instead.

---

## Phase 5 — Create a Brevo SMTP account (15 min)

**What:** Sign up for a free email-sending service. We'll use it to deliver the OTP login codes.

**Why:** We can't send email directly from the VM (residential IPs are spam-blocked). Brevo gives us 300 emails/day for free.

**Cost:** $0.

### Steps

1. Go to **https://www.brevo.com** and click **Sign up free**.
2. Fill in details, verify your email.
3. After login, go to **Settings (top-right) → SMTP & API**.
4. Click **Create a new SMTP key** if there isn't one. Copy the credentials:
   - **SMTP server:** `smtp-relay.brevo.com`
   - **Port:** `587`
   - **Login:** your Brevo email (looks like `abc123@smtp-brevo.com`)
   - **Password:** the master password / SMTP key shown
5. Set the **From address**. By default Brevo lets you send from your verified signup email. For a more professional look, add `no-reply@your-domain.az` later:
   - **Senders & IPs → Senders → Add a sender**, enter `no-reply@your-domain.az`. Brevo will email you a verification link from that address — you'll need to set up DNS first (next phase).

### Verify

Keep the SMTP host, port, login, password in a notepad — you'll paste them into `.env` in Phase 7.

### Stuck?

- Brevo asks to verify your domain via DNS records — skip for now; you can add the verification TXT records later. Sending will work from your personal verified email immediately.

---

## Phase 6 — Install Docker on the VM (20 min)

**What:** Set up Docker and the docker-compose plugin on your fresh Ubuntu VM.

**Why:** All our services run as Docker containers. We need Docker installed to start them.

**Cost:** $0.

### Steps

SSH into the VM (from Phase 3) and run:

```sh
ssh -i ~/.ssh/oracle-autoparts.key ubuntu@<your-public-ip>

# 1. update package lists and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# 2. add Docker's official GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# 3. install Docker engine + compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 4. let your user run docker without sudo
sudo usermod -aG docker ubuntu

# 5. log out and back in for group to take effect
exit
```

Reconnect with the same SSH command, then verify:

```sh
docker --version
docker compose version
docker run --rm hello-world
```

The last command downloads a tiny test image and prints a "Hello from Docker!" message. If that works, Docker is set up correctly.

### Open the host firewall

Ubuntu's default firewall blocks ports 80/443 even though Oracle's network rules allow them. Add explicit rules:

```sh
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

### Verify

```sh
sudo iptables -L INPUT -n | grep -E "80|443"
```

Should show ACCEPT lines for both ports.

### Stuck?

- "docker: permission denied" after logout/login → confirm `groups` shows `docker` listed.
- `netfilter-persistent: command not found` → `sudo apt-get install -y iptables-persistent`, then re-run the save command.

---

## Phase 7 — Configure your .env file (20 min)

**What:** Clone your code from GitHub onto the VM and fill in production secrets.

**Why:** The API needs to know things like the database password, JWT secret, SMTP credentials. We pass these as environment variables, not committed in the repo.

**Cost:** $0.

### Steps

1. On the VM (still in your SSH session):

```sh
cd ~
git clone https://github.com/Shako1989/autoparts-api.git
cd autoparts-api/deploy
cp .env.example .env
```

2. Generate strong values for the passwords:

```sh
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
echo "JWT_SECRET=$(openssl rand -base64 48 | tr -d '/+=')"
```

Copy each line.

3. Open `.env` for editing:

```sh
nano .env
```

In nano: arrow keys to move, edit normally, **Ctrl+O Enter** to save, **Ctrl+X** to exit.

Replace the placeholder values with real ones:

| Variable | Value |
|---|---|
| `API_HOST` | `api.your-domain.az` (your actual domain) |
| `MEDIA_HOST` | `cdn.your-domain.az` |
| `POSTGRES_PASSWORD` | the generated value from step 2 |
| `MINIO_ROOT_PASSWORD` | the generated value |
| `JWT_SECRET` | the generated value (at least 32 chars) |
| `ADMIN_PHONES` | your phone in E.164, e.g. `+994501234567` (you'll log in with this; gets STAFF role automatically) |
| `CORS_ALLOWED_ORIGINS` | `https://www.your-domain.az,https://your-domain.az` |
| `S3_LISTINGS_PUBLIC_BASE` | `https://cdn.your-domain.az/autoparts-listings` |
| `S3_CATALOG_PUBLIC_BASE` | `https://cdn.your-domain.az/autoparts-catalog` |
| `SMTP_HOST` | `smtp-relay.brevo.com` (from Brevo) |
| `SMTP_USERNAME` | your Brevo SMTP login |
| `SMTP_PASSWORD` | your Brevo SMTP key |
| `OTP_EMAIL_FROM` | `no-reply@your-domain.az` (or your verified Brevo sender) |

Leave the other values (`POSTGRES_DB`, `POSTGRES_USER`, `JWT_ISSUER`, `JWT_ACCESS_TTL`, etc.) as defaults from `.env.example`.

### Verify

```sh
cat .env | grep -E "^[A-Z]" | wc -l    # should print ~20
```

Confirm no placeholder text like `change-me-...` or `your-...` remains:

```sh
grep -E "change-me|your-" .env
```

If anything's printed, you missed a value — re-edit.

### Stuck?

- Lost in `nano`? Press **Ctrl+X** to abort, then `nano .env` again.

---

## Phase 8 — First deploy (30 min)

**What:** Build the API Docker image on the VM, start Postgres + MinIO + the API + Caddy, watch them come up.

**Why:** This is the actual deployment. After this step you have a live API on `https://api.your-domain.az`.

**Cost:** $0.

### Steps

On the VM, from `~/autoparts-api/deploy`:

```sh
# Build the API image (first build is slow, ~5 min on ARM)
docker compose -f docker-compose.prod.yml --env-file .env build api

# Start everything
docker compose -f docker-compose.prod.yml --env-file .env up -d

# Tail the API log so you see startup
docker compose -f docker-compose.prod.yml --env-file .env logs -f api
```

Wait for the log line:
```
Started ApiApplication in N.NN seconds
```

This usually takes 30–60 seconds. Press **Ctrl+C** to stop tailing (the containers keep running).

### Create the MinIO buckets

```sh
docker exec autoparts-minio sh -c '
  mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  mc mb --ignore-existing local/autoparts-listings
  mc mb --ignore-existing local/autoparts-catalog
  mc anonymous set download local/autoparts-listings
  mc anonymous set download local/autoparts-catalog
'
```

### Verify

```sh
# API health (from inside the VM)
curl -sS https://api.your-domain.az/actuator/health

# Should return: {"status":"UP"}
```

This call goes through Caddy → API. Caddy will automatically request a Let's Encrypt TLS certificate on the first request — it can take up to 60 seconds the first time. If you see a TLS error, retry after a minute.

Also from your **laptop** (not the VM):

```sh
curl -sS https://api.your-domain.az/actuator/health
```

Same `{"status":"UP"}` response. If your laptop can reach it, the world can.

### Stuck?

- API container won't start → `docker compose logs api` and look for the actual error. Common: Postgres not ready (wait and retry), bad env var (re-check `.env`).
- TLS error from Caddy → `docker compose logs caddy`. If you see "no such host" or DNS errors, the DNS records from Phase 4 haven't propagated yet. Wait and retry.
- `502 Bad Gateway` → API isn't responding; check API logs.

---

## Phase 9 — Deploy the frontend on Cloudflare Pages (30 min)

**What:** Build the React app and host it on Cloudflare's free static site CDN, connected to your GitHub repo so it auto-deploys.

**Why:** The frontend is a bunch of static files (HTML, JS, CSS). Cloudflare Pages serves them globally with TLS for free.

**Cost:** $0.

### Steps

1. In Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git**.
2. Authorize Cloudflare to read your GitHub.
3. Pick the `autoparts-web` repository.
4. Configure build:
   - **Project name:** `autoparts-web` (or anything; appears in the deploy URL)
   - **Production branch:** `main`
   - **Framework preset:** **Vite**
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`
   - **Root directory:** leave blank
5. **Environment variables** (click "Add variable"):
   - Name: `VITE_API_URL`
   - Value: `https://api.your-domain.az/api`
6. Click **Save and Deploy**.

Wait ~2 minutes for the first build. Cloudflare gives you a `*.pages.dev` URL when it's done.

### Hook up the custom domain

Still in the Pages project:
1. Click the **Custom domains** tab → **Set up a custom domain**.
2. Enter `www.your-domain.az`. Cloudflare configures DNS automatically (the CNAME is added with proxy enabled).
3. Repeat for the apex `your-domain.az`.

### Verify

Open `https://www.your-domain.az` in your browser. You should see the AutoParts homepage. The header includes "Sign in" — clicking it goes to the login page.

### Stuck?

- Build fails on Cloudflare → check the build log; usually a typo or missing env var.
- Page loads but API calls fail with CORS error → confirm `CORS_ALLOWED_ORIGINS` on the VM `.env` includes your frontend URL, restart the API container.
- "DNS not configured" warning in Pages → wait 1–2 minutes for Cloudflare to push the records.

---

## Phase 10 — First login and admin bootstrap (10 min)

**What:** Create your first user account by logging in. The phone in `ADMIN_PHONES` (Phase 7) gets auto-promoted to STAFF.

**Why:** You need an admin account to manage the catalog from the UI.

**Cost:** $0.

### Steps

1. Open `https://www.your-domain.az/login`.
2. Enter:
   - **Phone:** the one in `ADMIN_PHONES`, e.g. `+994501234567`
   - **Email:** an email you can check
3. Click **Send code**.
4. Check your email — within ~10 seconds, a message from Brevo (with sender `no-reply@your-domain.az`) arrives with the 6-digit code.
5. Enter the code, click **Continue**.

You're in. The page should show:
- Your name in the header (if you entered one)
- An **Admin** link (because your phone is on the allowlist)

Click **Admin** → you're at `/admin`. Browse around: Categories, Parts, Diagrams.

### Verify

```sh
# On the VM, check that your user is STAFF in the database
docker exec autoparts-postgres psql -U autoparts -d autoparts \
  -c "select phone, email, role from users order by created_at desc limit 5;"
```

Your phone should show `role = STAFF`.

### Stuck?

- Email never arrives → Brevo SMTP creds might be wrong in `.env`. Check `docker compose logs api | grep -i otp` for delivery errors. Also check spam folder.
- "Invalid code" → the OTP expired (10 min) or has typos. Click "Change phone" and request a new one.
- Header doesn't show Admin link → sign out and back in (the role was set after your previous login).

---

## Phase 11 — Set up backups (15 min)

**What:** A nightly cron job that dumps the Postgres database to a file on the VM.

**Why:** This is the most important step. If the VM dies, you lose your data — unless you have backups. Postgres data is the only truly precious thing; MinIO images can be re-uploaded if needed.

**Cost:** $0.

### Steps

On the VM:

```sh
cat > ~/backup.sh <<'EOF'
#!/bin/sh
set -e
DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR=/home/ubuntu/backups
mkdir -p $BACKUP_DIR
docker exec autoparts-postgres pg_dump -U autoparts autoparts \
  | gzip > $BACKUP_DIR/postgres-$DATE.sql.gz
# Keep only the last 14 days
find $BACKUP_DIR -name 'postgres-*.sql.gz' -mtime +14 -delete
EOF

chmod +x ~/backup.sh

# Schedule it to run at 03:00 every day
( crontab -l 2>/dev/null; echo "0 3 * * * /home/ubuntu/backup.sh" ) | crontab -

# Test it now
~/backup.sh
ls -lh ~/backups/
```

You should see a `postgres-YYYYMMDD-HHMM.sql.gz` file. That's your backup.

### For extra safety (optional)

Set up off-machine backup by uploading the dump to a remote storage:
- A second VM
- AWS S3 (free tier)
- Backblaze B2 (free 10GB)
- A USB drive synced via `rsync`

For v1, on-machine backups are fine while you have low traffic. Revisit when you have real users.

### Verify

```sh
crontab -l
```

Should show `0 3 * * * /home/ubuntu/backup.sh`.

### Stuck?

- `pg_dump` fails → the database isn't running or the password is wrong. Test the API health first.

---

## Phase 12 — Smoke test the live site (10 min)

**What:** Verify the whole stack works end-to-end as a real user would.

**Why:** Each phase verified its own slice. Now we walk through the user journey to catch anything we missed.

### Checklist

In a browser, on `https://www.your-domain.az`:

1. **Homepage loads** with the AutoParts heading.
2. **Sign in** as your admin account (Phase 10).
3. **Open admin → Categories** → see the seeded categories from your dev data, or empty if it's a fresh deploy.
4. **Create a category** → it saves; appears in the list.
5. **Create a part** → save; appears in the parts list.
6. **Upload an image** for the category (Edit Category → Icon → Upload). Confirm the icon appears in the list view.
7. **Become a seller** (Header → Become a seller). Fill the form.
8. **Create a listing** with a compatible vehicle.
9. **Sign out**.
10. **Open in an incognito window** → browse the catalog without a car selected → see the banner. Pick a car → only matching parts show.
11. **Click a listing** → details load, photos render.

If all 11 work, congratulations — you're live.

### Stuck?

- Image upload fails → check MinIO bucket policy: `docker exec autoparts-minio mc anonymous get local/autoparts-catalog` should say `download`. If not: `docker exec autoparts-minio mc anonymous set download local/autoparts-catalog`.
- Images don't render after upload → confirm `MEDIA_HOST` DNS resolves and Caddy is up: `curl -I https://cdn.your-domain.az/`.

---

## Day 2 — Operating the deployment

### Updating the API

When you push new commits to `autoparts-api`:

```sh
ssh -i ~/.ssh/oracle-autoparts.key ubuntu@<your-vm-ip>
cd ~/autoparts-api && git pull
cd deploy
docker compose -f docker-compose.prod.yml --env-file .env build api
docker compose -f docker-compose.prod.yml --env-file .env up -d api
docker compose -f docker-compose.prod.yml --env-file .env logs --tail=100 api
```

Flyway runs migrations automatically. Watch the log for the `Successfully applied N migrations` line.

### Updating the frontend

Cloudflare Pages auto-deploys on every push to `main` of `autoparts-web`. Nothing to do on the VM.

### Diagnosing a problem

```sh
docker compose -f docker-compose.prod.yml --env-file .env ps         # which containers are running
docker compose -f docker-compose.prod.yml --env-file .env logs api   # API logs
docker compose -f docker-compose.prod.yml --env-file .env logs caddy # TLS / proxy issues
```

### Restoring from a backup

```sh
# Stop the API so it can't write during restore
docker compose -f docker-compose.prod.yml --env-file .env stop api

# Restore
cat ~/backups/postgres-YYYYMMDD-HHMM.sql.gz \
  | gunzip \
  | docker exec -i autoparts-postgres psql -U autoparts -d autoparts

# Restart
docker compose -f docker-compose.prod.yml --env-file .env up -d api
```

---

## When you outgrow this setup

This single-VM setup is fine until you have hundreds of concurrent users or millions of images. When you do outgrow it:

| Symptom | Migration |
|---|---|
| Postgres slow, query times growing | Move to managed Postgres (Neon, AWS RDS, or Cloud SQL). Restore from `pg_dump`, update `DB_*` env vars, restart. |
| MinIO becomes a bottleneck on image reads | Replace with Cloudflare R2 (free egress). `mc mirror` data over, update `S3_CATALOG_PUBLIC_BASE` and `S3_LISTINGS_PUBLIC_BASE`. |
| Brevo 300/day cap hit | Upgrade Brevo to $25/mo for 20k/day, OR wire real SMS via Twilio behind the existing `OtpSender` interface. |
| VM downtime is a problem | Move to a load-balanced setup (2 API containers behind a load balancer), separate DB host. |

Because everything is Docker-based, none of these migrations require code changes — only env var updates.

---

## Cheat sheet

| Thing | Command |
|---|---|
| SSH to VM | `ssh -i ~/.ssh/oracle-autoparts.key ubuntu@<ip>` |
| Tail API logs | `docker compose -f docker-compose.prod.yml --env-file .env logs -f api` |
| Restart API | `docker compose -f docker-compose.prod.yml --env-file .env restart api` |
| Restart everything | `docker compose -f docker-compose.prod.yml --env-file .env restart` |
| Stop everything | `docker compose -f docker-compose.prod.yml --env-file .env stop` |
| Run backup now | `~/backup.sh` |
| List backups | `ls -lh ~/backups/` |
| API health (from anywhere) | `curl https://api.your-domain.az/actuator/health` |

---

## What to do if something goes badly wrong

The safest reset is **rebuild from scratch**:

1. Terminate the VM in OCI Console (it's just a VM; no harm done).
2. Provision a new one (Phase 3 again — takes 5 minutes).
3. SSH in, install Docker (Phase 6).
4. `git clone`, copy your `.env` (which you should have saved locally too!), `docker compose up`.
5. Restore Postgres from your latest backup.

The point of putting everything in Docker and storing secrets in `.env` is that nothing on the VM is irreplaceable except the data, and the data is backed up. Don't be afraid to nuke and rebuild if you get stuck.

---

## Done

When you finish Phase 12, you have:

- A real domain pointing at your own server
- HTTPS everywhere, automatically renewed
- The full API + frontend live for the world to see
- Daily database backups
- A path off this setup when you outgrow it

Total monthly cost: **$0**. Total annual cost: **~$10** for the domain.

Take a screenshot of your homepage on the real domain. You earned it.
