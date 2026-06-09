from flask import Flask, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CollectorRegistry, CONTENT_TYPE_LATEST
import os
import random
import time

app = Flask(__name__)

# Prometheus metrics
registry = CollectorRegistry()
request_count = Counter(
    'app_requests_total',
    'Total requests',
    ['method', 'endpoint', 'status'],
    registry=registry
)
request_duration = Histogram(
    'app_request_duration_seconds',
    'Request duration in seconds',
    ['method', 'endpoint'],
    registry=registry
)

@app.before_request
def start_timer():
    import flask
    flask.g.start_time = time.time()

@app.after_request
def record_metrics(response):
    import flask
    if hasattr(flask.g, 'start_time'):
        duration = time.time() - flask.g.start_time
        request_duration.labels(
            method=flask.request.method,
            endpoint=flask.request.endpoint or 'unknown'
        ).observe(duration)
    
    request_count.labels(
        method=flask.request.method,
        endpoint=flask.request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    
    return response

@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to the Test App',
        'status': 'running',
        'environment': os.getenv('ENVIRONMENT', 'development')
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

@app.route('/api/test')
def test():
    return jsonify({
        'test': 'endpoint',
        'data': 'This is a test response'
    })

@app.route('/metrics')
def metrics():
    return generate_latest(registry), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/colour/default.html')
def colour_default():
        colours = [
                'red',
                'blue',
                'green',
                'orange',
                'teal',
                'magenta',
                'goldenrod'
        ]
        selected_colour = random.choice(colours)
        return f"""<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Hello Colour</title>
</head>
<body style=\"display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;font-family:sans-serif;background:#f8f9fb;\">
    <h1 style=\"font-size:4rem;color:{selected_colour};\">Hello</h1>
</body>
</html>"""

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
