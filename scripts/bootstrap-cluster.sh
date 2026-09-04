#!/usr/bin/env bash
###############################################################################
# Bootstrap the Nodebase EKS cluster environment.
#
# Prerequisites (must be run BEFORE this script):
#   1. EKS cluster created via AWS Console (name: nodebase, region: eu-west-1)
#   2. ECR repository created via AWS Console (name: nodebase, region: eu-west-1)
#   3. kubectl configured: aws eks update-kubeconfig --name nodebase --region eu-west-1
#   4. helm installed
#
# Run from the nodebase-ops repo root:
#   ./scripts/bootstrap-cluster.sh
#
# This installs: ingress-nginx, cert-manager, ArgoCD,
# applies the ClusterIssuer, and registers the ArgoCD Application.
###############################################################################
set -euo pipefail

REGION="${REGION:-eu-west-1}"
EKS_CLUSTER="${EKS_CLUSTER:-nodebase}"

echo "==> Verifying AWS CLI and kubectl access"
aws eks update-kubeconfig --name "${EKS_CLUSTER}" --region "${REGION}"
kubectl cluster-info

echo "==> 1/4 Installing ingress-nginx"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

echo "==> 2/4 Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io || true
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

echo "==> 3/4 Installing ArgoCD"
helm repo add argo https://argoproj.github.io/argo-helm || true
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set server.service.type=LoadBalancer

echo "==> Waiting for ingress-nginx, cert-manager, argocd to become ready"
kubectl wait --for=condition=Available deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s || true
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=180s || true
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=180s || true

echo "==> 4/4 Applying ClusterIssuer and ArgoCD Application"
kubectl apply -f prod/certificate/issuer.yml
kubectl apply -f prod/ingress/ingress.yml
kubectl apply -f prod/nodebase/application.yml

echo ""
echo "Bootstrap complete."
echo "ArgoCD login:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "ArgoCD server endpoint:"
echo "  kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "To get the ingress NLB hostname (point DNS here):"
echo "  kubectl get svc ingress-nginx-controller -n ingress-nginx"
