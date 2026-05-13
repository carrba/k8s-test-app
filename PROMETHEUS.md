# Prometheus Metrics

The app now exports Prometheus metrics on the `/metrics` endpoint.

## Metrics

The app tracks the following metrics:

- **app_requests_total** - Total number of requests (counter)
  - Labels: `method`, `endpoint`, `status`
  
- **app_request_duration_seconds** - Request duration in seconds (histogram)
  - Labels: `method`, `endpoint`

## Accessing Metrics

### Direct Access

```bash
curl http://localhost:5000/metrics
```

### From Kubernetes

Port-forward to the service:
```bash
kubectl port-forward -n k8s-test-app svc/k8s-test-app 5000:5000
curl http://localhost:5000/metrics
```

## Prometheus Configuration

Add to your Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'k8s-test-app'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - k8s-test-app
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: k8s-test-app
      - source_labels: [__meta_kubernetes_pod_ip]
        action: replace
        target_label: __address__
        replacement: $1:5000
      - action: replace
        target_label: __scheme__
        replacement: http
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod
```

## Prometheus Operator (Optional)

If you have Prometheus Operator installed, deploy the ServiceMonitor:

```bash
kubectl apply -f k8s/service-metrics.yaml
kubectl apply -f k8s/servicemonitor.yaml
```

The ServiceMonitor will automatically configure Prometheus to scrape metrics every 30 seconds.

## Example Queries

### Request Rate (requests per second)
```
rate(app_requests_total[5m])
```

### Request Duration (95th percentile)
```
histogram_quantile(0.95, app_request_duration_seconds_bucket)
```

### Error Rate (5xx responses)
```
rate(app_requests_total{status=~"5.."}[5m])
```

### Requests by Endpoint
```
sum by (endpoint) (rate(app_requests_total[5m]))
```
