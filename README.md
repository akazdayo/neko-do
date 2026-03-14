# Neko on DigitalOcean with NixOS + Docker

`m1k1o/neko` を DigitalOcean Droplet 上の NixOS で動かすための構成です。
NixOS 自体は Terraform/OpenTofu + deploy-rs で管理し、`neko` 本体は Docker コンテナで起動します。

## このリポジトリが作るもの

- DigitalOcean カスタムイメージから NixOS Droplet を作成
- Droplet 上で Docker を有効化
- `ghcr.io/m1k1o/neko/firefox:latest` を systemd 管理で常駐起動
- 初回起動時に `neko` の user/admin パスワードを自動生成
- `8080/tcp` と `52000-52100/udp` を `neko` 用に公開

## 前提

- Nix (`flakes` 有効)
- DigitalOcean アカウント
- `default` という名前で DigitalOcean に登録済みの SSH キー
- 環境変数 `DIGITALOCEAN_TOKEN`

```bash
export DIGITALOCEAN_TOKEN="dop_v1_xxxxxxxxxxxxx"
```

## デフォルト構成

- Region: `sgp1`
- Droplet size: `s-2vcpu-4gb`
- Neko image: `ghcr.io/m1k1o/neko/firefox:latest`
- Web UI: `http://<droplet-ip>:8080`

必要なら [terraform/terraform.nix](/home/akazdayo/programs/neko-do/terraform/terraform.nix) を編集して region/size を変更してください。

## 1. DigitalOcean に Droplet を作成

```bash
nix run .#tf-plan
nix run .#tf-apply
```

IP アドレス確認:

```bash
tofu output droplet_ip
```

## 2. deploy-rs の接続先を設定

[deploy/deployment.nix](/home/akazdayo/programs/neko-do/deploy/deployment.nix) の `hostname = "HOSTIP HERE";` を、作成された Droplet の IP に置き換えます。

## 3. NixOS 設定をデプロイ

```bash
nix run .#deploy
```

デプロイ後、Droplet 上では `docker-neko.service` が起動し、Docker 経由で `neko` が立ち上がります。

## 4. 初回ログイン

生成された認証情報を確認:

```bash
ssh root@<droplet-ip> 'cat /var/lib/neko/neko.env'
```

表示された `NEKO_MEMBER_MULTIUSER_USER_PASSWORD` と `NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD` を使って、以下へアクセスします。

```text
http://<droplet-ip>:8080
```

## 運用

状態確認:

```bash
ssh root@<droplet-ip> 'systemctl status docker-neko'
ssh root@<droplet-ip> 'docker ps'
```

ログ確認:

```bash
ssh root@<droplet-ip> 'journalctl -u docker-neko -n 200 --no-pager'
```

認証情報を再生成したい場合:

```bash
ssh root@<droplet-ip> 'rm /var/lib/neko/neko.env && systemctl restart neko-secrets docker-neko'
```

## 調整ポイント

- `8080/tcp` を直接公開する構成です。HTTPS を使うなら別途リバースプロキシを追加してください。
- UDP `52000-52100` は WebRTC 用です。ここが閉じると接続品質が大きく落ちます。
- ブラウザ種類や画面サイズは [deploy/droplet-configuration.nix](/home/akazdayo/programs/neko-do/deploy/droplet-configuration.nix) で変えられます。

## 削除

```bash
nix run .#tf-destroy
```
