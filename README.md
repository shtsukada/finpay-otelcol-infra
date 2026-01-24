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

finpay-otelcol-infra/
├─ terraform/
│  ├─ *.tf                            # EC2/EIPなどIaC本体(ec2.tf, eip.tf, ...)
│  ├─ envs/dev/terraform.tfvars*      # ローカル専用（gitignore）
│  └─ user_data/install_k3s.sh.tftpl  # k3s導入スクリプト(template)
├─ argocd/
│  ├─ bootstrap/ # Argo CD 本体導入
│  ├─ root-app/  # finpay-root(app-of-apps)
│  └─ apps/      # child apps(monitoring)
└─ hack/
   └─ kubeconfig.sh                # kubeconfig 取得（ssh経由）

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

## 破棄（destroy）

```bash
cd terraform
terraform destroy -var-file=envs/dev/terraform.tfvars
```

---

## Quickstart

```bash
# apply -> kubeconfig -> argocd -> root -> monitoring

./hack/kubeconfig.sh <EC2_PUBLIC_IP>
export KUBECONFIG=4(pwd)/kubeconfig
kubectl get nodes

kubectl apply -k argocd/bootstrap
kubectl -n argocd rollout status deploy/argocd-server
kubectl wait --for=condition=Established crd/application.argoproj.io

kubectl apply -k argocd/root-app
kubectl -n argocd get applications
```

期待値:

* `finpay-root` が `Synced/Healthy`
* `finpay-monitoring` が `Synced/Healthy`

> UIアクセス/初期PW/再現チェック/Troubleshootingはdocsを参照。

---

## Docs

* Argo CD access / 初期ログイン / 再現チェック / Troubleshooting: `docs/argocd-access-and-repro.md`

---

## セキュリティ注意（MVPでも必須）

* `allowed_cidrs` は必ず絞る
* 秘密情報（鍵、トークン）を repo にコミットしない（tfvars は gitignore）
* 外部公開しない（port-forward 前提）

---

## License

MIT (see `LICENSE`)
