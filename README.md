# K8s Test App

A basic Python Flask web application designed to run in Docker and Kubernetes.

## Features

- Simple Flask REST API
- Health check endpoint
- Environment-based configuration
- Docker and Docker Compose support

## Local Development

### Prerequisites
- Python 3.11+
- Docker (for containerized deployment)

### Running Locally

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the app:
```bash
python app.py
```

The app will be available at `http://localhost:5000`

## Docker

### Build the image:
```bash
docker build -t k8s-test-app .
```

### Run the container:
```bash
docker run -p 5000:5000 k8s-test-app
```

## Docker Compose

### Start the app:
```bash
docker-compose up
```

### Stop the app:
```bash
docker-compose down
```

## API Endpoints

- `GET /` - Main endpoint, returns app status
- `GET /health` - Health check endpoint
- `GET /api/test` - Test endpoint with sample data
- `GET /metrics` - Prometheus metrics endpoint

## Monitoring

- Prometheus metrics are exposed on `GET /metrics`.
- Kubernetes metrics scraping resources are in `k8s/service-metrics.yaml` and `k8s/servicemonitor.yaml`.
- See `PROMETHEUS.md` for setup and troubleshooting details.

## Environment Variables

- `ENVIRONMENT` - Application environment (default: development)
- `PORT` - Port to run on (default: 5000)
