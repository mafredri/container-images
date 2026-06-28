FROM golang:1.26-trixie AS builder

# renovate: datasource=go depName=git.bofh.at/mla/rasexporter
ARG RASEXPORTER_VERSION=v0.0.0-20210602084929-8676061d8c03

RUN go install git.bofh.at/mla/rasexporter@${RASEXPORTER_VERSION}

FROM gcr.io/distroless/base-debian13:nonroot

COPY --from=builder /go/bin/rasexporter /usr/local/bin/rasexporter

USER nonroot:nonroot
EXPOSE 7010
ENTRYPOINT ["rasexporter"]
CMD ["--listen", "0.0.0.0:7010", "--db", "/rasdaemon.db"]
