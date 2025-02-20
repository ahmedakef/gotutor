# Start from the official Go image for building
FROM golang:1.22 AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy the Go source code into the container
COPY . .

# Download dependencies
RUN go mod tidy

# Build the Go CLI application as a statically linked binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gotutor .

# Use a minimal base image for the final container
FROM alpine:latest

# Set the working directory inside the container
WORKDIR /root/

# Copy the Go binary from the builder stage
COPY --from=builder /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

# Copy the compiled binary from the builder stage
COPY --from=builder /app/gotutor .
# Make sure the binary is executable
RUN chmod +x gotutor

# Define the command to run when the container starts
ENTRYPOINT ["./gotutor"]
