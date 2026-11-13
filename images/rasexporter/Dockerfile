FROM golang:1.27.4-trixie AS builder

# renovate: datasource=go depName=git.bofh.at/mla/rasexporter
ARG RASEXPORTER_VERSION=v0.0.0-20210602084929-8676061d8c03

RUN go install git.bofh.at/mla/rasexporter@${RASEXPORTER_VERSION}

FROM gcr.io/distroless/base-debian13:nonroot@sha256:a08d9054afbaf1af9b90fd02cdc7b32236319b5376d374505a41548d42b0c5db

COPY --from=builder /go/bin/rasexporter /usr/local/bin/rasexporter

USER nonroot:nonroot
EXPOSE 7010
ENTRYPOINT ["rasexporter"]
CMD ["--listen", "0.0.0.0:7010", "--db", "/rasdaemon.db"]
