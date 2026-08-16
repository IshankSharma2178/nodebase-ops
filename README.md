# Nodebase GitOps (EKS)

Kubernetes manifests for deploying **Nodebase** to AWS EKS using **ArgoCD**, **nginx Ingress**, **cert-manager**, and **Sealed Secrets**.

Move this folder to its own Git repository (`nodebase-ops`) when ready. The app repo (`nodebase`) CI updates image tags here.

## Layout

```text
nodebase-ops/
├── prod/
│   ├── certificate/issuer.yml      # Let's Encrypt ClusterIssuer (apply once)
│   ├── ingress/ingress.yml         # Production hostname
│   └── nodebase/                   # App manifests (ArgoCD watches this path)
├── staging/
│   ├── ingress/ingress.yml
│   └── nodebase/
└── scripts/seal-secret.sh
```

## One-time cluster setup

1. **EKS cluster** with managed node group (or Karpenter).
2. **RDS PostgreSQL** — create DB `nodebase`, note connection string for `DATABASE_URL`.
3. Install add-ons:
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

   helm repo add jetstack https://charts.jetstack.io
   helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true

   helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
   helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

   kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
4. Apply cluster issuer:
   ```bash
   kubectl apply -f prod/certificate/issuer.yml
   ```
5. **ECR** repository `nodebase` + IAM OIDC role for GitHub Actions (see app repo `cd.yml`).
6. **Route53**: point `app.yourdomain.com` → nginx LoadBalancer hostname.

## Configure placeholders

Search/replace across this repo:

| Placeholder | Replace with |
|-------------|--------------|
| `YOUR_GITHUB_ORG` | Your GitHub org/user |
| `YOUR_AWS_ACCOUNT` | AWS account ID |
| `app.yourdomain.com` | Production domain |
| `staging.app.yourdomain.com` | Staging domain |
| `you@yourdomain.com` | ACME email in `issuer.yml` |
| `REPLACE_WITH_GIT_SHA` | First deploy image tag (CD updates automatically) |

## Create sealed secrets

```bash
cp prod/nodebase/.env.template prod/nodebase/.env
# edit prod/nodebase/.env with real values

chmod +x scripts/seal-secret.sh
./scripts/seal-secret.sh prod
# commit prod/nodebase/sealed-secret.yml only
```

Repeat for staging:

```bash
cp staging/nodebase/.env.template staging/nodebase/.env
./scripts/seal-secret.sh staging

## Register ArgoCD apps

```bash
kubectl apply -f prod/certificate/issuer.yml
kubectl apply -f prod/ingress/ingress.yml
kubectl apply -f prod/nodebase/application.yml
kubectl apply -f staging/ingress/ingress.yml   # optional
kubectl apply -f staging/nodebase/application.yml  # optional
```

ArgoCD syncs `prod/nodebase/` including PreSync migrate Job.

## External services (after first deploy)

| Service | Setting |
|---------|---------|
| Inngest Cloud | App URL → `https://app.yourdomain.com/api/inngest` |
| Google/GitHub OAuth | Callback URLs → production domain |
| Polar | Success URL → production domain |
| Stripe / Google Form / Telegram | Webhook URLs → production domain |

## GitHub Actions secrets (app repo)

| Secret | Purpose |
|--------|---------|
| `AWS_ROLE_ARN` | OIDC role to push to ECR |
| `OPS_REPO_PAT` | PAT with write access to `nodebase-ops` |
| `NEXT_PUBLIC_APP_URL` | Baked into client bundle at build time |
| `ARGOCD_AUTH_TOKEN` | Optional: trigger sync after deploy |

## Manual first deploy

```bash
# From nodebase app repo
docker build --build-arg NEXT_PUBLIC_APP_URL=https://app.yourdomain.com -t nodebase:local .
aws ecr get-login-password | docker login --username AWS --password-stdin YOUR_AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
docker tag nodebase:local YOUR_AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/nodebase:manual1
docker push YOUR_AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/nodebase:manual1
# Update deployment.yml + migrate-job.yml image tags, then argocd sync
```

## Files per app folder

| File | Purpose |
|------|---------|
| `deployment.yml` | Next.js pods |
| `service.yml` | ClusterIP :80 → :3000 |
| `ingress` (shared) | TLS + routing |
| `certificate.yml` | cert-manager Certificate |
| `sealed-secret.yml` | Encrypted `.env` |
| `migrate-job.yml` | ArgoCD PreSync `prisma migrate deploy` |
| `application.yml` | ArgoCD Application |
| `hpa.yml` | CPU autoscaling |
| `pdb.yml` | Safe rollouts |
# nodebase-ops
