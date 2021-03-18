#!/bin/sh

set -eu

ETCD_VER=v3.4.15

if [ $# -gt 0 ]; then
    ETCD_VER=v$1
fi
echo "Setup etcd ${ETCD_VER}"

GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GOOGLE_URL}
DOWNLOAD_DIR=/tmp/etcd

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf ${DOWNLOAD_DIR} && mkdir -p ${DOWNLOAD_DIR}

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o ${DOWNLOAD_DIR}/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf ${DOWNLOAD_DIR}/etcd-${ETCD_VER}-linux-amd64.tar.gz -C ${DOWNLOAD_DIR} --strip-components=1
rm -f ${DOWNLOAD_DIR}/etcd-${ETCD_VER}-linux-amd64.tar.gz

${DOWNLOAD_DIR}/etcd --version
${DOWNLOAD_DIR}/etcdctl version
