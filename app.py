from flask import Flask, jsonify, render_template_string, request
from prometheus_client import Counter, Histogram, generate_latest, CollectorRegistry, CONTENT_TYPE_LATEST
import csv
import os
import random
import time

app = Flask(__name__)


def get_worldcup_csv_path():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), 'worldcup.csv')

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

@app.route('/worldcup')
def worldcup():
    csv_path = get_worldcup_csv_path()
    matches = []

    with open(csv_path, newline='', encoding='utf-8', errors='replace') as csv_file:
        reader = csv.reader(csv_file)
        for idx, row in enumerate(reader):
            if len(row) < 8:
                continue
            matches.append({
                'row_index': idx,
                'match': row[0],
                'date': row[1],
                'time': row[2],
                'team1': row[3],
                'score1': row[4],
                'score2': row[5],
                'team2': row[6],
                'group': row[7],
            })

    return render_template_string(
        """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>World Cup Fixtures</title>
    <style>
        :root {
            --bg: #f3f6fb;
            --card: #ffffff;
            --ink: #182235;
            --muted: #5a677f;
            --line: #d9e0ee;
            --accent: #0c7f5f;
            --accent-soft: #e8f8f3;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            color: var(--ink);
            background:
                radial-gradient(circle at 20% 15%, #d7efe7 0%, transparent 35%),
                radial-gradient(circle at 80% 85%, #d7e6ff 0%, transparent 40%),
                var(--bg);
            min-height: 100vh;
        }
        .wrap {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 1rem 2rem;
        }
        .card {
            background: var(--card);
            border: 1px solid var(--line);
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 12px 40px rgba(24, 34, 53, 0.08);
        }
        .header {
            padding: 1.25rem 1.5rem;
            border-bottom: 1px solid var(--line);
            background: linear-gradient(135deg, #f6fbf9 0%, #f2f6ff 100%);
        }
        h1 {
            margin: 0;
            font-size: 1.7rem;
            line-height: 1.1;
        }
        .sub {
            margin: 0.4rem 0 0;
            color: var(--muted);
            font-size: 0.95rem;
        }
        .toolbar {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            margin-top: 1rem;
        }
        .save-btn {
            border: 0;
            background: var(--accent);
            color: #fff;
            font-weight: 700;
            border-radius: 10px;
            padding: 0.6rem 1rem;
            cursor: pointer;
        }
        .save-btn:hover { filter: brightness(0.95); }
        .save-status {
            color: var(--muted);
            font-size: 0.9rem;
        }
        .table-wrap {
            width: 100%;
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            min-width: 900px;
        }
        th, td {
            border-bottom: 1px solid var(--line);
            padding: 0.7rem 0.8rem;
            text-align: left;
            font-size: 0.95rem;
            white-space: nowrap;
        }
        th {
            position: sticky;
            top: 0;
            z-index: 1;
            background: #f8fbff;
            color: #24324c;
            font-weight: 600;
        }
        tr:hover td { background: #fbfdff; }
        .score {
            background: var(--accent-soft);
            border: 1px solid #b6e9da;
            border-radius: 6px;
            min-width: 2.8rem;
            text-align: center;
            font-weight: 700;
            color: #145646;
            outline: none;
        }
        .score:focus {
            border-color: var(--accent);
            box-shadow: 0 0 0 2px rgba(12, 127, 95, 0.18);
            background: #f0fff8;
        }
        @media (max-width: 768px) {
            .wrap { margin: 1rem auto; }
            h1 { font-size: 1.35rem; }
            th, td { padding: 0.55rem 0.6rem; font-size: 0.88rem; }
        }
    </style>
</head>
<body>
    <div class="wrap">
        <div class="card">
            <div class="header">
                <h1>World Cup Matches</h1>
                <p class="sub">Only score fields are editable on this page.</p>
                <div class="toolbar">
                    <button id="saveScores" class="save-btn" type="button">Save Scores</button>
                    <span id="saveStatus" class="save-status">No changes saved yet.</span>
                </div>
            </div>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Match</th>
                            <th>Date</th>
                            <th>Time</th>
                            <th>Team 1</th>
                            <th>Score 1</th>
                            <th>Score 2</th>
                            <th>Team 2</th>
                            <th>Group</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for m in matches %}
                        <tr>
                            <td>{{ m.match }}</td>
                            <td>{{ m.date }}</td>
                            <td>{{ m.time }}</td>
                            <td>{{ m.team1 }}</td>
                            <td class="score" contenteditable="true" data-row-index="{{ m.row_index }}" data-field="score1">{{ m.score1 }}</td>
                            <td class="score" contenteditable="true" data-row-index="{{ m.row_index }}" data-field="score2">{{ m.score2 }}</td>
                            <td>{{ m.team2 }}</td>
                            <td>{{ m.group }}</td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <script>
        // Keep score edits numeric-only while allowing user editing.
        document.querySelectorAll('.score').forEach(function (cell) {
            cell.addEventListener('input', function () {
                cell.textContent = cell.textContent.replace(/[^0-9]/g, '');
            });
        });

        document.getElementById('saveScores').addEventListener('click', async function () {
            const status = document.getElementById('saveStatus');
            const updatesByRow = {};

            document.querySelectorAll('.score').forEach(function (cell) {
                const rowIndex = cell.getAttribute('data-row-index');
                const field = cell.getAttribute('data-field');
                const value = (cell.textContent || '').trim();

                if (!updatesByRow[rowIndex]) {
                    updatesByRow[rowIndex] = {};
                }
                updatesByRow[rowIndex][field] = value === '' ? '0' : value;
            });

            const updates = Object.keys(updatesByRow).map(function (rowIndex) {
                return {
                    row_index: Number(rowIndex),
                    score1: updatesByRow[rowIndex].score1 || '0',
                    score2: updatesByRow[rowIndex].score2 || '0'
                };
            });

            status.textContent = 'Saving...';
            try {
                const response = await fetch('/worldcup/save', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ updates: updates })
                });

                const result = await response.json();
                if (!response.ok) {
                    throw new Error(result.error || 'Failed to save scores');
                }
                status.textContent = 'Saved ' + result.updated_rows + ' matches to CSV.';
            } catch (error) {
                status.textContent = 'Save failed: ' + error.message;
            }
        });
    </script>
</body>
</html>""",
        matches=matches
    )


@app.route('/worldcup/save', methods=['POST'])
def save_worldcup_scores():
    data = request.get_json(silent=True) or {}
    updates = data.get('updates', [])

    if not isinstance(updates, list):
        return jsonify({'error': 'Invalid payload: updates must be a list'}), 400

    csv_path = get_worldcup_csv_path()
    with open(csv_path, newline='', encoding='utf-8', errors='replace') as csv_file:
        rows = list(csv.reader(csv_file))

    updated_rows = 0
    for item in updates:
        if not isinstance(item, dict):
            continue
        row_index = item.get('row_index')
        score1 = str(item.get('score1', '0')).strip()
        score2 = str(item.get('score2', '0')).strip()

        if not str(score1).isdigit() or not str(score2).isdigit():
            return jsonify({'error': 'Scores must be numeric values'}), 400

        if isinstance(row_index, int) and 0 <= row_index < len(rows) and len(rows[row_index]) >= 8:
            rows[row_index][4] = score1
            rows[row_index][5] = score2
            updated_rows += 1

    with open(csv_path, 'w', newline='', encoding='utf-8') as csv_file:
        writer = csv.writer(csv_file)
        writer.writerows(rows)

    return jsonify({'status': 'ok', 'updated_rows': updated_rows}), 200

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
