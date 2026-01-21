#!/bin/bash
# need to be applied manually b/c helm + kubenix cannot handle them
# https://cert-manager.io/docs/installation/helm/#3-install-customresourcedefinitions
# VERSION MUST MATCH VERSION OF CERT-MANAGER CHARTS IN USE (v1.19.2)

kubectl apply --server-side --force-conflicts -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.crds.yaml
