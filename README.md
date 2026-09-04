# Nodebase GitOps (EKS)

Kubernetes manifests for deploying **Nodebase** to AWS EKS using **ArgoCD**, **nginx Ingress**, and **cert-manager**.

The app repo (`nodebase`) CI builds Docker images, pushes to ECR, and updates image tags here. ArgoCD watches this repo and syncs to the cluster.

## Layout

```text
nodebase-ops/
├── prod/
│   ├── certificate/issuer.yml      # Let's Encrypt ClusterIssuer (apply once)
│   ├── ingress/ingress.yml         # Production hostname
│   └── nodebase/                   # App manifests (ArgoCD watches this path)
```

## Prerequisites

- AWS EKS cluster provisioned via the `nodebase-infra` Terraform repo
- ECR repository `nodebase` (from Terraform)
- Add-ons installed (below)

## One-time cluster setup

1. **EKS cluster** provisioned via `nodebase-infra` (Terraform).
2. **Database** — Neon DB (external), connection string goes in `.env` as `DATABASE_URL`.
3. Install add-ons:
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

   helm repo add jetstack https://charts.jetstack.io
   helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true
   ```

4. Install ArgoCD:
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm install argocd argo/argo-cd -n argocd --create-namespace --set server.service.type=LoadBalancer
   ```

5. Apply cluster issuer:
   ```bash
   kubectl apply -f prod/certificate/issuer.yml
   ```

6. **Route53** (optional for now): point `nodebase.aws.ishankdev.me` → nginx LoadBalancer hostname.

## Register ArgoCD app

```bash
kubectl apply -f prod/certificate/issuer.yml
kubectl apply -f prod/ingress/ingress.yml
kubectl apply -f prod/nodebase/application.yml
```

ArgoCD syncs `prod/nodebase/` including PreSync migrate Job.

## App secrets

The deployment mounts `prod/nodebase/nodebase-secret.yml` (a Kubernetes `Secret` with an `.env` key) at `/app/.env`. This repo keeps it in plaintext for a solo-dev setup. For a more secure approach, migrate to Sealed Secrets (kubeseal) or an external secrets store.

## Configure placeholders

Search/replace across this repo:

| Placeholder | Value used |
|-------------|------------|
| `YOUR_GITHUB_ORG` | `IshankSharma2178` |
| `YOUR_AWS_ACCOUNT` | `916785371700` |
| `app.yourdomain.com` | `nodebase.aws.ishankdev.me` |
| `you@yourdomain.com` | `ishanksharma4444@gmail.com` |
| `REPLACE_WITH_GIT_SHA` | Updated by CI (image tag) |

## External services (after first deploy)

| Service | Setting |
|---------|---------|
| Inngest Cloud | App URL → `https://nodebase.aws.ishankdev.me/api/inngest` |
| Google/GitHub OAuth | Callback URLs → production domain |
| Polar | Success URL → production domain |
| Stripe / Google Form / Telegram | Webhook URLs → production domain |

## GitHub Actions secrets (app repo)

See the `deploy.yml` workflow in the `nodebase` app repo.

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | ECR push permissions |
| `AWS_SECRET_ACCESS_KEY` | ECR push permissions |
| `OPS_REPO_PAT` | PAT with write access to `nodebase-ops` |
| `OPS_REPO_NAME` | `IshankSharma2178/nodebase-ops` |

## Files per app folder

| File | Purpose |
|------|---------|
| `deployment.yml` | Next.js pods |
| `service.yml` | ClusterIP :80 → :3000 |
| `certificate.yml` | cert-manager Certificate |
| `nodebase-secret.yml` | App `.env` secret |
| `migrate-job.yml` | ArgoCD PreSync `prisma migrate deploy` |
| `application.yml` | ArgoCD Application |
| `hpa.yml` | CPU autoscaling |
| `pdb.yml` | Safe rollouts |
