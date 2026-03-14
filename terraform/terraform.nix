{...}: let
  imageName = "neko-nixos";
  dropletName = "neko";
  region = "sgp1";
  size = "s-2vcpu-4gb";
in {
  # DigitalOcean Provider
  terraform.required_providers.digitalocean = {
    source = "digitalocean/digitalocean";
    version = "~> 2.75";
  };

  # API Token (環境変数 DIGITALOCEAN_TOKEN から取得)
  provider.digitalocean = {};

  # SSH Key (既存のキーを参照)
  data.digitalocean_ssh_key.default = {
    name = "default";
  };

  # NixOS カスタムイメージ
  resource.digitalocean_custom_image.nixos = {
    name = imageName;
    url = "https://github.com/akazdayo/digitalocean-nix-tf/releases/download/latest/nixos-digitalocean-do.qcow2.gz";
    regions = [region];
  };

  # Neko を載せる最低限の余裕を持たせたサイズ
  resource.digitalocean_droplet.neko = {
    image = "\${digitalocean_custom_image.nixos.id}";
    name = dropletName;
    region = region;
    size = size;
    ssh_keys = ["\${data.digitalocean_ssh_key.default.id}"];
  };

  # Outputs
  output.droplet_ip = {
    value = "\${digitalocean_droplet.neko.ipv4_address}";
    description = "The public IPv4 address of the Droplet";
  };
}
