# 🚀 Servas Deployment Guide

This guide covers two approaches to deploy the Servas app:

1. **Using Kind + Helm**
2. **Using Rancher Fleet for GitOps**

It also includes common gotchas and troubleshooting steps.

---

## 🧱 Prerequisites

- Docker
- `kubectl`
- [Kind](https://kind.sigs.k8s.io/)
- [Helm](https://helm.sh/)
- [Fleet CLI](https://fleet.rancher.io/cli/)
- (Optional) [Ingress NGINX Controller](https://kubernetes.github.io/ingress-nginx/)

---

## ⚙️ Deployment Using Kind + Helm

### 1. Create a Kind Cluster

Create a `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
```

Then:

```bash
kind create cluster --config kind-config.yaml
```

### 2. Install Ingress NGINX

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 3. Deploy Database (MariaDB)

Use a Helm chart or Kubernetes manifest to deploy MariaDB, for example:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mydb bitnami/mariadb \
  --set auth.rootPassword=secretpassword \
  --set auth.database=servasdb
```

### 4. Configure DNS for `servas.local`

Add to `/etc/hosts`:

```
127.0.0.1 servas.local
```

### 5. Update `values.yaml`

Ensure your environment variables are correct:

```yaml
env:
  database_host: mydb-mariadb
  database_port: 3306
  database_user: root
  database_password: secretpassword
  database_name: servasdb
  database_connection: mysql
  secret_key: CHANGEME1234567890SECRET
  app_key: base64:YOUR_GENERATED_APP_KEY
```

To generate a new app key:

```bash
php artisan key:generate --show
```

### 6. Deploy the App with Helm

```bash
helm upgrade --install servas ./servas-chart
```

Verify the app:

```bash
kubectl get all
kubectl logs deploy/servas-servas-chart
```

Then open [http://servas.local](http://servas.local)

---

## 🌐 Deployment Using Fleet

### 1. Setup Fleet with Helm

Create a `deploy.sh` script:

```bash
#!/bin/bash
set -e

echo "🔧 Uninstalling Fleet CRDs via Helm..."
helm uninstall fleet || true
helm uninstall fleet-crd || true

echo "🔧 Installing Fleet CRDs via Helm..."
helm repo add rancher-charts https://charts.rancher.io
helm install fleet-crd rancher-charts/fleet-crd --namespace cattle-fleet-system --create-namespace
helm install fleet rancher-charts/fleet --namespace cattle-fleet-system

echo "⏳ Waiting for Fleet controller to be ready..."
kubectl rollout status -n cattle-fleet-system deploy/fleet-controller --timeout=120s

echo "📦 Applying Fleet bundle from ./fleet-bundle"
fleet apply dev ./fleet-bundle
echo "✅ Deployment triggered via Fleet. Monitor with: kubectl get bundles -A"
```

Then run:

```bash
chmod +x deploy.sh
./deploy.sh
```

### 2. Bundle Directory Structure

```
fleet-bundle/
├── fleet.yaml
├── values.yaml
└── helm/
    └── servas-chart/
        ├── Chart.yaml
        ├── templates/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── ingress.yaml
```

### `fleet.yaml`

```yaml
defaultNamespace: default
helm:
  chart: ./helm/servas-chart
  releaseName: servas
targets:
  - name: local
    clusterName: local
```

---

## 🧠 Gotchas & Troubleshooting

| Problem | Fix |
|--------|-----|
| ❌ `502 Bad Gateway` | App not listening on `0.0.0.0:80`. Check `containerPort`, app binding, and Dockerfile. |
| ❌ `No APP_KEY specified` | Run `php artisan key:generate --show` and set it in `values.yaml`. |
| ❌ `connect() failed (111: Connection refused)` | Database might be inaccessible or Laravel env misconfigured. |
| ❌ `fleet apply` fails with CRD error | Wait or delete stuck CRDs using `kubectl delete crd bundles.fleet.cattle.io`. |
| ❌ Ingress doesn't work | Ensure DNS (`/etc/hosts`) points `servas.local` to `127.0.0.1`. |
| ❌ `fleet-bundle` stuck at `0/0` | Check for correct structure, missing `Chart.yaml`, or invalid paths. Use `kubectl describe bundle -n fleet-local <bundle-name>` for details. |
| ❌ `port-forward` fails | Ensure the Service exposes the right port (`targetPort` should match container's exposed port). |

---

## ✅ Final Checklist

- [x] Kind cluster created
- [x] NGINX ingress installed
- [x] Database reachable (`mydb-mariadb:3306`)
- [x] Laravel env variables set correctly
- [x] `APP_KEY` generated and passed
- [x] Fleet bundle path and structure valid
- [x] DNS routing `servas.local` to localhost

---

## 🧼 Cleanup

```bash
kind delete cluster
helm uninstall servas
helm uninstall mydb
helm uninstall fleet -n cattle-fleet-system
helm uninstall fleet-crd -n cattle-fleet-system
```

---

## 🧩 References

- [Fleet Docs](https://fleet.rancher.io/)
- [Helm Charts](https://helm.sh/docs/)
- [Laravel Deployments](https://laravel.com/docs/deployment)
- [Kind](https://kind.sigs.k8s.io/)
