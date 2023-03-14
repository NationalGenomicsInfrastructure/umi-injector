FROM alpine:3.17
LABEL maintainer='Matthias Zepper, National Genomics Infrastructure Stockholm'

WORKDIR /bin
RUN apk add --no-cache bash file gawk pigz

COPY ./umi-injector.sh /bin/umi-injector.sh
RUN chmod +x /bin/umi-injector.sh
ENTRYPOINT ["/bin/umi-injector.sh"]

