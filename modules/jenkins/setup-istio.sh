#!/bin/bash
set -e

# Cấu hình
CLUSTER_NAME="skyline-cicd-eks"
REGION="ap-southeast-1"

echo "Updating kubeconfig for cluster $CLUSTER_NAME..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "Installing Helm if not exists..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

echo "Adding Istio Helm repo..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

echo "1. Installing Istio Base..."
helm upgrade --install istio-base istio/base -n istio-system --create-namespace

echo "2. Installing Istio Discovery (istiod)..."
helm upgrade --install istiod istio/istiod -n istio-system --wait

echo "3. Installing Istio Ingress Gateway..."
helm upgrade --install istio-ingress istio/gateway -n istio-system --wait

echo "Enabling Istio Injection for default namespace..."
kubectl label namespace default istio-injection=enabled --overwrite

echo "Istio installation completed!"