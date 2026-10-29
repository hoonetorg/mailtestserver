FROM registry.opensuse.org/opensuse/leap:16.1
RUN zypper -n in --no-recommends dovecot24 postfix Radicale openssl findutils && zypper -n clean -a
COPY files/ /opt/mailtest/
RUN chmod 0755 /opt/mailtest/*.sh && /opt/mailtest/setup.sh
EXPOSE 993 587 5232
ENTRYPOINT ["/opt/mailtest/entrypoint.sh"]
