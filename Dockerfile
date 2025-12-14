FROM rockylinux:9

ENV COBBLER_RPM=cobbler-3.4.0-1.el9.noarch.rpm

COPY ${COBBLER_RPM} /${COBBLER_RPM}

RUN set -eux; \
  dnf -y install epel-release; \
  dnf -y install /${COBBLER_RPM}; \
  dnf -y install \
      httpd dhcp-server tftp-server rsync-daemon \
      util-linux openssl \
      pykickstart yum-utils debmirror git \
      ipxe-bootimgs shim grub2-efi-x64-modules; \
  dnf clean all

EXPOSE 67/udp 69/udp 873 80 25151

VOLUME [ \
  "/var/lib/cobbler", "/var/www/cobbler", "/var/lib/dhcpd", \
  "/etc/cobbler", "/var/lib/tftpboot", \
  "/var/cobbler/iso" \
]

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
