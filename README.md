# Nodebase GitOps (EKS)

Kubernetes manifests for deploying **Nodebase** to AWS EKS using **ArgoCD**, **nginx Ingress**, and **cert-manager**.

The app repo (`node4work`) CI builds Docker images, pushes to ECR, and updates image tags here. ArgoCD watches this repo and syncs to the cluster.

## Layout

```text
nodebase-ops/
├── prod/
│   ├── certificate/issuer.yml      # Let's Encrypt ClusterIssuer (apply once)
│   ├── ingress/ingress.yml         # Production hostname
│   └── nodebase/                   # App manifests (ArgoCD watches this path)
├── scripts/
│   └── bootstrap-cluster.sh        # One-time cluster add-on installer
```

## Prerequisites

- AWS EKS cluster created via AWS Console (name: `nodebase`, region: `eu-west-1`)
- ECR repository created via AWS Console (name: `nodebase`, region: `eu-west-1`)
- kubectl configured: `aws eks update-kubeconfig --name nodebase --region eu-west-1`
- helm installed

## One-time cluster setup

1. **EKS cluster** created via AWS Console.
2. **ECR repository** `nodebase` created via AWS Console.
3. **Database** — Neon DB (external), connection string goes in the K8s secret as `DATABASE_URL`.
4. Run the bootstrap script:
   ```bash
   ./scripts/bootstrap-cluster.sh
   ```
   This installs ingress-nginx, cert-manager, and ArgoCD, then applies the ClusterIssuer, Ingress, and ArgoCD Application.

5. Create the app secret:
   ```bash
   kubectl apply -f prod/nodebase/nodebase-secret.yml
   ```

6. **DNS**: point `nodebase.aws.ishankdev.me` CNAME → nginx ingress LB hostname.

## Register ArgoCD app (already done by bootstrap)

```bash
kubectl apply -f prod/certificate/issuer.yml
kubectl apply -f prod/ingress/ingress.yml
kubectl apply -f prod/nodebase/application.yml
```

ArgoCD syncs `prod/nodebase/` including PreSync migrate Job.

## App secrets

The deployment uses `prod/nodebase/nodebase-secret.yml` (a Kubernetes `Secret` with an `.env` key) mounted at `/app/.env`. This file is gitignored — create it manually on the cluster.

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

See the `deploy.yml` workflow in the `node4work` app repo.

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
| `nodebase-secret.yml` | App `.env` secret (gitignored, create manually) |
| `migrate-job.yml` | ArgoCD PreSync `prisma migrate deploy` |
| `application.yml` | ArgoCD Application |
| `hpa.yml` | CPU autoscaling |
| `pdb.yml` | Safe rollouts |
