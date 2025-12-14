# Cobbler container image

A Cobbler container image. Up-to-date, easy to maintain, and easy to use.

## Version

3.4

## How to build

```
docker build -t cobbler:3.4 .
```

## How to use

```sh
docker run --rm -it \
  --privileged --net=host \
  -e SERVER=10.10.60.10 \
  -e SERVER_IP_V4=10.10.60.10 \
  -v /opt/cobbler/lib:/var/lib/cobbler \
  -v /opt/cobbler/www:/var/www/cobbler \
  -v /opt/cobbler/dhcpd:/var/lib/dhcpd \
  -v /opt/cobbler/etc:/etc/cobbler \
  -v /opt/cobbler/tftpboot:/var/lib/tftpboot \
  -v /opt/cobbler/iso:/var/cobbler/iso \
  cobbler:3.4
```

### Environments

- SERVER_IP_V4: Cobbler server v4 ip
- SERVER_IP_V6: Cobbler server v6 ip
- SERVER: Cobbler server ip or hostname, required, default $SERVER_IP_V4
- ROOT_PASSWORD: Installation (root) password, required

### Custom settings

```sh
-v path/to/settings.d:/etc/cobbler/settings.d:ro
```

### Custom dhcp template

```sh
-v path/to/dhcp.template:/etc/cobbler/dhcp.template:ro
```

### import iso
```
# 1) import（你可以先把 ISO 放进 /var/cobbler/iso，再 mount）
mkdir -p /mnt/iso
mount -o loop,ro /var/cobbler/iso/Rocky-9.4-x86_64-dvd.iso /mnt/iso
cobbler import --name=Rocky-9.4 --path=/mnt/iso --arch=x86_64
umount /mnt/iso

# 2) 你改 profile / ks
cobbler profile list
cobbler profile edit --name=Rocky-9.4-x86_64 --kickstart=/var/lib/cobbler/kickstarts/xxx.ks

# 3) sync 一次
cobbler sync
```
