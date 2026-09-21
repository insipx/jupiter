[![Hercules CI](https://hercules-ci.com/api/v1/site/github/account/insipx/project/jupiter/badge)](https://hercules-ci.com/github/insipx/jupiter/status)

# Jupiter Homelab

A few Raspberry Pi5s and thinkcentre minis all deployed with NixOS running k3s
in one flake :)

<img width="4032" height="3024" alt="IMG_3160" src="https://github.com/user-attachments/assets/21280979-292c-45b3-8fa2-9b3e6d52fd24" />

## Project structure

```text
.
├── hive/                 # Per-node deployment configurations for Colmena.
├── base/                 # Shared host configurations, including NixOS user config.
├── machine-specific/     # NixOS config specific to host machines (rpi5/rpi4/thinkcentre/etc.).
├── nixos/                # initial Raspberry Pi and x86 NixOS configurations.
├── deployments/          # where stuff deployed on the cluster goes.
├── apps/                 # app source if any, so far just kasa exporter for power metrics.
├── pkgs/                 # Any software that requires custom packaging (rathole).
├── images/               # Nix-built docker images.
├── modules/              # Extra modules/configs, so far just a quick and dirty hercules-ci agent config.
├── scripts/              # helper scripts, AWS build server script for aarch64-linux / freebsd.
└── .github/workflows/    # Github actions (mostly building docker images).
```

## Architecture

### Hosts

Everything is deployed with [colmena](https://github.com/zhaofengli/colmena)
from `hive/default.nix`. Node names are moons of Jupiter.

```mermaid
---
config:
  theme: dark
  layout: elk
---
flowchart TB
 subgraph internet["Internet"]
        fly["jupiter-gateway<br>:443 / :80 public · :2333 tunnel"]
  end
 subgraph standalone["Standalone NixOS hosts"]
        volos["volos · rpi5<br>Certificate Authority :443"]
        carme["carme · rpi5<br>Grafana Kiosk"]
  end
 subgraph control["control plane (embedded etcd)"]
        ganymede["ganymede · rpi5<br>leader"]
        io["io · rpi5"]
        europa["europa · rpi5"]
  end
 subgraph workers["workers"]
        callisto["callisto · rpi5"]
        elara["elara · rpi5"]
        sinope["sinope · rpi3"]
        amalthea["amalthea · thinkcentre x86"]
        lysithea["lysithea · thinkcentre x86"]
  end
 subgraph k3s["k3s cluster"]
        control
        workers
        lbs["MetalLB VIPs<br>10.10.68.1 traefik (lan / mTLS)<br>10.10.70.1 traefik-public<br>10.10.68.100 alloy syslog"]
  end
 subgraph lan["jupiter.lan · 10.10.68.0/22"]
        opnsense["Jupiter · Router/Firewall/DNS<br>10.10.69.1"]
        standalone
        k3s
  end
    fly -- noise tunnel :2333 --- k3s
    opnsense -- syslog :1514 --> lbs
    carme -- "https grafana.jupiter.lan" --> lbs
    k3s -- cert requests --> volos

    style lbs font-size:12px
```

### Cluster workloads

Everything in the cluster is declared with
[kubenix](https://github.com/hall/kubenix) under `deployments/kubenix`, grouped
by namespace.

```mermaid
---
config:
theme: dark
---
flowchart TB
 subgraph external["Outside the cluster"]
        fly["External VPS<br>*.insipx.xyz :443 / :80"]
        volos["volos step-ca"]
        opnsense["OPNsense"]
        s3[("AWS S3<br>loki-homelab-storage")]
        cw["AWS CloudWatch"]
        ghcr["GHCR<br>ghcr.io/insipx/*"]
  end
 subgraph rathole["rathole"]
        rclient["rathole-client"]
  end
 subgraph kubesystem["kube-system"]
        traefik["Traefik<br>10.10.68.1<br>10.10.70.1"]
  end
 subgraph certs["cert-manager"]
        certmgr["cert-manager + step-issuer<br>StepClusterIssuer"]
  end
 subgraph monitoring["monitoring"]
        kps["Prometheus · Grafana · Alertmanager"]
        loki["Loki"]
        alloy["Alloy (syslog ingest :1514)<br>alloy-logs DaemonSet"]
        exporters["metrics exporters (kasa/YACE/etc.)"]
  end
 subgraph personal["personal-apps"]
        budget["Actual Budget<br>budget.jupiter.lan"]
  end
 subgraph argocd["argocd"]
        argo["Argo CD<br>argocd.jupiter.lan"]
  end
 subgraph website["website"]
        site["personal website (ArgoCD)"]
  end
    fly -- noise tunnel :2333 --- rclient
    rclient -- forwards :8445 / :80 --> traefik
    traefik --> budget & site & argo & kps & longhorn["Longhorn<br>longhorn.jupiter.lan"] & alloy
    certmgr -- step provisioner --> volos
    certmgr -- "wildcard *.jupiter.lan" --> traefik
    kps --> loki
    alloy --> loki
    loki --> s3
    exporters -- scrape --> opnsense
    exporters -- aws api --> cw
    opnsense -- syslog --> alloy
    argo -- polls tags --> ghcr
    argo --> site
    metallb["MetalLB<br>pools: 10.10.68.0/24 default · 10.10.70.0/24 public"]
```
