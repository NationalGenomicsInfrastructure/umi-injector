FROM alpine:3.17
LABEL maintainer='Matthias Zepper, National Genomics Infrastructure Stockholm'

WORKDIR /bin
RUN apk add --no-cache bash file gawk pigz

COPY ./src/umi-injector.sh /bin/umi-injector.sh
RUN chmod +x /bin/umi-injector.sh
RUN ln -s /bin/umi-injector.sh /bin/umi-injector
ENTRYPOINT ["/bin/umi-injector"]

