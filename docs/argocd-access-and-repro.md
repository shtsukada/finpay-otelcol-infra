# Argo CD Access & Repro Checklist

このドキュメントは、finpay-otelcol-infra の Argo CD を **bootstrap -> root app -> monitoring app**の順で適用し、UIログインと再現チェック(Synced/Healthy)までを迷わず実行できることを目的にしています。

---

## 0. 前提・要件

### 必須コマンド
* 必須: `kubectl`, `git`, `ssh`
* 任意: `argocd` CLI

### kubeconfig
* このリポジトリは`hack/kubeconfig.sh`でkubeconfigを取得してローカルから操作します。
```bash
.hack/kubeconfig.sh <EC2_PUBLIC_IP>
export KUBECONFIG=$(pwd)kubeconfig
kubectl get nodes
```
期待値:
* Node が `Ready`
* `kubectl get ns` が成功

### ネットワーク前提
* ローカル環境からKubernetes APIに到達できること(通常 `:6443`)
* (リモート構成なら)SSHも到達できること

## 1. One-path Quickstart
以下の順序を固定します。
bootstrap -> root-app -> monitoring

```bash
# 1) Argo CD を bootstrap(インストール)
kubectl apply -k argocd/bootstrap

# 2) argocd-server の起動待ち(server が Available になるまで)
kubectl -n argocd rollout status deploy/argocd-server

# 3) Argo CD の CRD が確率するのを待つ(Application)
kubectl wait --for=condition=Established crd/applications.argoproj.io

# 4) root app を適用(app-of-apps の入口)
kubectl apply -k argocd/root-app

# 5) アプリ状態確認(Synced/Healthy を見る)
kubectl -n argocd get applications
```
期待値:
* `finpay-root` が `Synced` / `Healthy`
* `finpay-monitoring` が `Synced` / `Healthy`
>Synced=Gitの期待値(desired state)と、クラスタの実態(live state)が一致
>Healthy=リソースが"健康状態"と判定されている(DeploymentがAvailable等)

## 2. Argo CDへアクセス(Port-forward)
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

## 3. 初期パスワード取得 & ログイン
初期PW取得(argocd-initial-admin-secret)
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```
UIログイン
* URL: `http://localhost:8080`
* user: `admin`
* password: 上記で取得したPW

## 4. 再現の自己点検チェックリスト
* [ ] `kubectl -n argocd get application` で `finpay-root` が表示される
* [ ] `finpay-root` が `Synced/Healthy`
* [ ] `finpay-monitoring` が `Synced/Healthy`
* [ ] `kubectl get ns monitoring` が `Active`
* [ ] `kubectl -n monitoring get pods` が `Running`(例:Prometheus/Grafana/Loki/Tempo/otelcol等)

## 5. Troubleshooting
### A. 証明書/ブラウザ警告
症状:
* `https://localhost:8080`で警告が出て画面が進まない

対処:
* ブラウザの「詳細」→「このサイトに進む(安全ではありません)」等で継続
* もしくはCLIを使う(argocd login --insecure)

### B. Kubernetes API (:6443)疏通
症状:
* `kubectl` が `Unable to connect to the server` / `i/o timeout` 等
* Argo CDのapply以前に詰まる

確認:(例)
```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl config view --minify
```
ポイント:
* kubeconfigの`server: http://...:6443`がローカルから到達可能か
* (リモートk3sなら)Security Group/Firewall/経路が6443で遮断されていないか

### C. Security Group/Firewall/経路 (:6443,:22)
症状:
* `kubectl`がタイムアウト
* SSHも不安定、または到達しない

確認:(例)
```bash
# TCP疏通(mac/linux)
nc -vz <k3s-server-ip> 6443
nc -vz <k3s-server-ip> 22
```
対処の方向性:
* 6443を送信元IPから許可しているか
* NAT/VPN/踏み台などで送信元IPが変化していないか

### D. k3s状態(ノードがReadyか)
症状:
* `kubectl get nodes`がNotReady
* PodがPending/CrashLoopを繰り返す

確認:
```bash
kubectl get nodes -o wide
sudo systemctl status k3s
sudo jounalctl -u k3s -n 200 --no-paper
```
対処:
* k3sが落ちているなら復旧(再起動、原因ログ確認)
* ディスク枯渇やメモリ不足がないかも併せて確認
