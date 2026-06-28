FROM golang:1.26-trixie AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/rdap-fi-proxy .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /out/rdap-fi-proxy /rdap-fi-proxy
EXPOSE 8080
ENTRYPOINT ["/rdap-fi-proxy"]
