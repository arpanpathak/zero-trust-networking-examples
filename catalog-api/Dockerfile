# 1. Build Stage
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o catalog-api main.go

# 2. Run Stage — Alpine so we can exec into it for debugging
FROM alpine:3.21
RUN apk add --no-cache ca-certificates curl
WORKDIR /
COPY --from=builder /app/catalog-api .
EXPOSE 8080
USER nobody:nobody
ENTRYPOINT ["/catalog-api"]
