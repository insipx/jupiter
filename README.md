[![Hercules CI](https://hercules-ci.com/api/v1/site/github/account/insipx/project/jupiter/badge)](https://hercules-ci.com/github/insipx/jupiter/status)

# Jupiter Homelab

A few Raspberry Pi5s and thinkcentre minis all deployed with NixOS running k3s
in one flake :)

<img width="4032" height="3024" alt="IMG_3160" src="https://github.com/user-attachments/assets/21280979-292c-45b3-8fa2-9b3e6d52fd24" />

## Architecture

### Hosts

Everything is deployed with [colmena](https://github.com/zhaofengli/colmena)
from `hive/default.nix`. Node names are moons of Jupiter.

```mermaid
flowchart TB
  subgraph internet["Internet"]
    fly["jupiter-gateway (ewr)<br/>rathole-server<br/>:443 / :80 public · :2333 tunnel"]
  end

  subgraph lan["jupiter.lan · 10.10.68.0/22"]
    opnsense["Jupiter · Router/Firewall<br/>10.10.69.1 · gateway / DNS"]

    subgraph standalone["Standalone NixOS hosts"]
      volos["volos · rpi5 · 10.10.69.18<br/>Certificate Authority :443"]
      carme["carme · rpi5 · 10.10.69.17<br/>Grafana Kiosk"]
    end

    subgraph k3s["k3s cluster"]
      subgraph control["control plane (embedded etcd)"]
        ganymede["ganymede · rpi5 · 10.10.69.10<br/>leader"]
        io["io · rpi5 · 10.10.69.11"]
        europa["europa · rpi5 · 10.10.69.12"]
      end
      subgraph workers["workers"]
        callisto["callisto · rpi5 · 10.10.69.14"]
        elara["elara · rpi5 · 10.10.69.20"]
        sinope["sinope · rpi3 · 10.10.69.16<br/>lowpower, only SD storage"]
        amalthea["amalthea · thinkcentre x86 · 10.10.69.50"]
        lysithea["lysithea · thinkcentre x86 · 10.10.69.51"]
      end
      lbs["MetalLB VIPs<br/>10.10.68.1 traefik (lan / mTLS)<br/>10.10.70.1 traefik-public<br/>10.10.68.100 alloy syslog"]
    end
  end

  fly -- "noise tunnel :2333" --- k3s
  opnsense -- "syslog :1514" --> lbs
  carme -- "https grafana.jupiter.lan" --> lbs
  k3s -- "cert requests" --> volos
```

### Cluster workloads

Everything in the cluster is declared with
[kubenix](https://github.com/hall/kubenix) under `deployments/kubenix`, grouped
by namespace. The public gateway on Fly.io lives in `deployments/fly`.

```mermaid
flowchart TB
  subgraph external["Outside the cluster"]
    fly["External rathole-server VPS<br/>*.insipx.xyz :443 / :80"]
    volos["volos step-ca"]
    opnsense["OPNsense"]
    s3[("AWS S3<br/>loki-homelab-storage")]
    cw["AWS CloudWatch"]
    ghcr["GHCR<br/>ghcr.io/insipx/*"]
  end

  subgraph rathole["rathole"]
    rclient["rathole-client"]
  end

  subgraph kubesystem["kube-system"]
    traefik["Traefik<br/>10.10.68.1 · :443 lan · :8443 mTLS<br/>10.10.70.1 · :8445 / :80 public"]
  end

  metallb["MetalLB<br/>pools: 10.10.68.0/24 default · 10.10.70.0/24 public"]
  longhorn["Longhorn<br/>longhorn.jupiter.lan"]

  subgraph certs["cert-manager"]
    certmgr["cert-manager + step-issuer<br/>StepClusterIssuer"]
  end

  subgraph monitoring["monitoring"]
    kps["kube-prometheus-stack<br/>Prometheus · Grafana · Alertmanager · node-exporter"]
    loki["Loki"]
    alloy["Alloy (syslog ingest :1514)<br/>alloy-logs DaemonSet"]
    exporters["kasa-exporter · opnsense-exporter<br/>cloudwatch-exporter (YACE)"]
  end

  subgraph personal["personal-apps"]
    budget["Actual Budget<br/>budget.jupiter.lan / budget.insipx.xyz"]
  end

  subgraph argocd["argocd"]
    argo["Argo CD + image-updater<br/>argocd.jupiter.lan"]
  end

  subgraph website["website"]
    site["personal website<br/>(managed with Argo CD from insipx/website)"]
  end

  fly -- "noise tunnel :2333" --- rclient
  rclient -- "forwards :8445 / :80" --> traefik
  traefik --> budget &  site & argo & kps & longhorn & alloy
  certmgr -- "step provisioner" --> volos
  certmgr -- "wildcard *.jupiter.lan" --> traefik

  kps --> loki
  alloy --> loki
  loki --> s3
  exporters -- "scrape" --> opnsense
  exporters -- "aws api" --> cw
  opnsense -- "syslog" --> alloy

  argo -- "polls tags" --> ghcr
  argo --> site
```
