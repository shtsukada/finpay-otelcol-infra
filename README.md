# finpay-otelcol-infra

Terraformで **EC2(amd64) + single-node k3s** を構築し、Argo CD を bootstrap（app-of-apps）して
`finpay-otelcol-monitoring`（および将来的に `finpay-otelcol-app`）を GitOps 同期する **CD起点** リポジトリです。

MVPは **外部公開はせず**、操作は `kubectl port-forward` を前提にしています。

---

## 目的（このリポの役割）

* **再現性**：誰がやっても同じ手順で環境を作れる（version pin / IaC）
* **CD起点**：Argo CD の root Application（app-of-apps）をここで管理し、下流リポを同期する
* **MVPの焦点**：まずは `monitoring` を同期して「break → alert → normal」デモの土台を作る

---

## リポジトリ構成

```
finpay-otelcol-infra/
├─ terraform/
│  ├─ versions.tf
│  ├─ provider.tf
│  ├─ variables.tf
│  ├─ main.tf
│  ├─ outputs.tf
│  ├─ envs/dev/terraform.tfvars*   # ローカル専用（gitignore）
│  └─ user_data/install_k3s.sh.tftpl
├─ argocd/
│  ├─ bootstrap/
│  │  ├─ kustomization.yaml
│  │  └─ root-app.yaml             # app-of-apps の root
│  └─ apps/
│     └─ monitoring.yaml           # child app（監視スタック）
└─ hack/
   └─ kubeconfig.sh                # kubeconfig 取得（ssh経由）
```

> `terraform/envs/dev/terraform.tfvars` は **gitignore** 前提（秘密情報や環境差分をここに置くため）。

---

## 前提（ローカル）

* Terraform（推奨: versions.tf で pin）
* AWS CLI v2（`aws sts get-caller-identity` が通る）
* SSH クライアント（EC2へログイン可能）
* `kubectl`（kubeconfig を取得後に利用）
* `kustomize`（`kubectl apply -k` を使うため）
* （任意）Helm（手元で監視を触る場合）

---

## 前提（AWS 側）

* EC2 にログイン可能な **key pair**（`ssh_key_name`）
* VPC/Subnet（MVPは public subnet 推奨）
* Security Group で SSH(22) を **自分のIP/32** などに絞る（重要）

---

## 重要な方針（MVP）

* 外部公開しない（Ingress/LoadBalancerは使わない）
* Argo CD / Grafana / Prometheus / Tempo へのアクセスは `port-forward` で行う
* 監視スタック（monitoring）は Helm を Argo CD が同期（app-of-apps）

---

## Terraform: apply（dev）

### 1) 初期化

```bash
cd terraform
terraform init
```

### 2) Plan / Apply

```bash
terraform plan  -var-file=envs/dev/terraform.tfvars
terraform apply -var-file=envs/dev/terraform.tfvars
```

### 3) 出力確認

例：

```bash
terraform output
terraform output -raw instance_public_ip
```

---

## kubeconfig の取得

`hack/kubeconfig.sh` を使って、EC2から kubeconfig を取得しローカルで利用します。

```bash
./hack/kubeconfig.sh <EC2_PUBLIC_IP>
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

期待値：

* node が `Ready`
* `kubectl get ns` が成功

> うまくいかない場合は、EC2上で `sudo k3s kubectl get nodes` が通るかを先に確認してください。

---

## Argo CD: bootstrap（app-of-apps）

### 1) Argo CD をインストール

```bash
kubectl create ns argocd || true
kubectl apply -k argocd/bootstrap
```

> `argocd/bootstrap/kustomization.yaml` が root-app を含む想定です。

### 2) root app を作成（app-of-apps）

```bash
kubectl apply -f argocd/bootstrap/root-app.yaml
```

### 3) 状態確認

```bash
kubectl -n argocd get pods
kubectl -n argocd get applications
```

期待値：

* argocd server / repo-server / application-controller などが Running
* `Application` が作成されている

---

## child app: monitoring の同期

`argocd/apps/monitoring.yaml` が `finpay-otelcol-monitoring` を参照します。

### 差し替えポイント（最初に必ず）

`monitoring.yaml` 内の以下は自分の環境に合わせます：

* repoURL: `https://github.com/shtsukada/finpay-otelcol-monitoring.git`
* targetRevision: `main` もしくは `v0.1.0`（pinするならタグ）
* path: `charts/finpay-otelcol`

---

## Argo CD UI へのアクセス（port-forward）

### 1) port-forward

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

ブラウザで：

* `https://localhost:8080`

### 2) 初期 admin パスワード取得

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

ユーザー名：

* `admin`

---

## Monitoring へのアクセス（port-forward）

monitoring が同期されてから実施します（namespace は `monitoring` を想定）。

```bash
kubectl -n monitoring port-forward svc/grafana 3000:3000
kubectl -n monitoring port-forward svc/prometheus 9090:9090
kubectl -n monitoring port-forward svc/tempo 3200:3200
```

---

## 破棄（destroy）

```bash
cd terraform
terraform destroy -var-file=envs/dev/terraform.tfvars
```

---

## Troubleshooting

### k3s が起動しない

* EC2上で `sudo systemctl status k3s` を確認
* user_data のログ（`/var/log/cloud-init-output.log`）を確認
* version pin が正しいか（`INSTALL_K3S_VERSION`）確認

### kubectl が繋がらない

* `hack/kubeconfig.sh` が取得した kubeconfig の `server:` が `<EC2_PUBLIC_IP>` になっているか
* SG が SSH だけでなく、必要なら 6443 を許可しているか（MVPは ssh 経由取得で回避可）

### Argo CD が同期しない

* `argocd/apps/monitoring.yaml` の repoURL/path/targetRevision を確認
* private repo の場合は credentials が必要（MVPは public を推奨）
* `kubectl -n argocd logs deploy/argocd-repo-server` を確認

---

## セキュリティ注意（MVPでも必須）

* `allowed_cidrs` は必ず絞る
* 秘密情報（鍵、トークン）を repo にコミットしない（tfvars は gitignore）
* 外部公開しない（port-forward 前提）

---

## License

MIT (see `LICENSE`)
