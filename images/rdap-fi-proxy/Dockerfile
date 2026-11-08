FROM golang:1.27.3-trixie AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/rdap-fi-proxy .

FROM gcr.io/distroless/static-debian13:nonroot@sha256:25ac8f0c3b2334a9eb05452266bd4697864a8c8ef0ef71e5e6480d7f92868329
COPY --from=build /out/rdap-fi-proxy /rdap-fi-proxy
EXPOSE 8080
ENTRYPOINT ["/rdap-fi-proxy"]
