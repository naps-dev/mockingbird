# Script requires Mockingbird_Sandbox.ova in the current directory

# Docker upload destination for containerDisk
IMAGE_UPLOAD_PATH="${IMAGE_UPLOAD_PATH:-10.1.25.34/voltron/mockingbird-sandbox:latest}"

virt-v2v \
    -i ova Mockingbird_Sandbox.ova \
    -o local -of qcow2 -os "$PWD" -on Mockingbird_Sandbox

# Cannot use --edit, VM doesn't have perl, use sed instead
# Weird timezone issues, setting Acquire::Max-FutureTime=86400 lets the time be out of sync by 24hr
# Need to delete Ubuntu installer provided cfg files to re-enable cloud-init
#  See: https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu
# Default to dhcp netplan, with low 00 priority
virt-customize \
  -a Mockingbird_Sandbox-sda \
  --run-command 'apt-get -o Acquire::Max-FutureTime=86400 update' \
  --run-command 'apt-get install -y cloud-init qemu-guest-agent' \
  --delete '/etc/cloud/cloud.cfg.d/99-installer.cfg' \
  --delete '/etc/cloud/cloud.cfg.d/curtin-preserve-sources.cfg' \
  --delete '/etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg' \
  --delete '/etc/netplan/*.yaml' \
  --delete '/etc/cloud/ds-identify.cfg'  \
  --run-command 'cloud-init clean --logs --seed'  \
  --delete '/var/lib/cloud/'  \
  --run-command 'sed -i '"'"'s/GRUB_CMDLINE_LINUX="\([^"]*\)"/GRUB_CMDLINE_LINUX="\1 console=tty0 console=ttyS0,115200n8"/'"'"' /etc/default/grub'  \
  --append-line '/etc/default/grub:GRUB_TERMINAL=serial' \
  --append-line '/etc/default/grub:GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' \
  --run-command 'update-grub' \
  --write '/etc/netplan/00-default-dhcp.yaml:
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: true
'

# virt-customize logs are inside the VM at /tmp/builder.log on disk:
#   guestfish --ro -a Mockingbird_Sandbox-sda -i cat /tmp/builder.log

# Push Kubevirt containerDisk
# https://github.com/kubevirt/kubevirt/blob/main/docs/container-register-disks.md
mkdir disk
mv Mockingbird_Sandbox-sda disk/
cat >Dockerfile <<EOF
FROM scratch
ADD disk/* /disk/
EOF
docker build -t "$IMAGE_UPLOAD_PATH" .
docker push "$IMAGE_UPLOAD_PATH"
