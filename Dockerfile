# Postfix SMTP Relay

FROM debian:latest
MAINTAINER Andrew Cutler <andrew@panubo.io>

ENV S6_RELEASE=1.19.1 S6_VERSION=2.4.0.0 S6_SHA1=c3caccc531029c4993b3b66027559b15d5a10874

EXPOSE 25 587

VOLUME ["/var/spool/mail/"]

# Preselections for installation
RUN echo mail > /etc/hostname; \
    echo "postfix postfix/main_mailer_type string Internet site" >> preseed.txt; \
    echo "postfix postfix/mailname string mail.example.com" >> preseed.txt; \
    debconf-set-selections preseed.txt && rm preseed.txt

# Install packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends postfix mailutils busybox-syslogd curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install s6
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -s -L https://github.com/just-containers/skaware/releases/download/v${S6_RELEASE}/s6-${S6_VERSION}-linux-amd64-bin.tar.gz -o s6.tar.gz && \
    echo "${S6_SHA1} s6.tar.gz" | sha1sum -c - && \
    tar -xzf s6.tar.gz -C / && \
    rm -rf ${DIR}

# Configure
RUN postconf -e smtpd_banner="\$myhostname ESMTP" && \
    postconf -e mail_spool_directory="/var/spool/mail/" && \
    # Enable submission
    postconf -Me submission/inet="submission inet n - - - - smtpd" && \
    # Cache spool dir as template
    cp -a /var/spool/postfix /var/spool/postfix.cache && \
    # Remove snakeoil certs
    rm -f /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem

COPY s6 /etc/s6/

CMD ["/bin/s6-svscan","/etc/s6"]
