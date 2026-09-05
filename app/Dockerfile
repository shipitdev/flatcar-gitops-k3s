FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod ./
COPY main.go ./

RUN go build -o /app/server main.go

FROM alpine:latest

WORKDIR /
COPY --from=builder /app/server /server
EXPOSE 8080

ENTRYPOINT ["/server"]
