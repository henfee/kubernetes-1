#!/bin/sh
# Kubelet outputs only to stderr, so arrange for everything we do to go there too
exec 1>&2

if [ ! -e /var/lib/cni/.opt.defaults-extracted ] ; then
    mkdir -p /var/lib/cni/opt/bin
    tar -xzf /root/cni.tgz -C /var/lib/cni/opt/bin
    touch /var/lib/cni/.opt.defaults-extracted
fi
if [ -e /etc/kubelet.conf ] ; then
    . /etc/kubelet.conf
fi
if [ -e /var/config/userdata ] ; then
    echo "kubelet.sh: joining cluster with metadata \"$(cat /var/config/userdata)\""
    kubeadm join --skip-preflight-checks $(cat /var/config/userdata)
fi

conf=/var/lib/kubeadm/kubelet.conf

echo "kubelet.sh: waiting for ${conf}"
# TODO(ijc) is there a race between kubeadm creating this file and
# finishing the write where we might be able to fall through and
# start kubelet with an incomplete configuration file? I've tried
# to provoke such a race without success. An explicit
# synchronisation barrier or changing kubeadm to write
# kubelet.conf atomically might be good in any case.
until [ -f "${conf}" ] ; do
    sleep 1
done

echo "kubelet.sh: ${conf} has arrived" 2>&1

exec kubelet --kubeconfig=${conf} \
	      --require-kubeconfig=true \
	      --pod-manifest-path=/var/lib/kubeadm/manifests \
	      --allow-privileged=true \
	      --cluster-dns=10.96.0.10 \
	      --cluster-domain=cluster.local \
	      --cgroups-per-qos=false \
	      --enforce-node-allocatable= \
	      --network-plugin=cni \
	      --cni-conf-dir=/var/lib/cni/etc/net.d \
	      --cni-bin-dir=/var/lib/cni/opt/bin \
	      $KUBELET_ARGS $@
