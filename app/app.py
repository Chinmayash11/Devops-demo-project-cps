"""
Flask application for a small cuisine discovery frontend.

The app keeps production-friendly health and metrics endpoints for Kubernetes,
while serving a visual frontend for Bengaluru and Odisha food at `/`.
"""

import json
import logging
import os
import signal
import sys
import time
from datetime import datetime

import prometheus_client
from flask import Flask, jsonify, render_template_string, request
from prometheus_client import Counter, Gauge, Histogram, generate_latest
from werkzeug.exceptions import HTTPException


class Config:
    """Application configuration from environment variables."""

    DEBUG = os.getenv("FLASK_DEBUG", "False").lower() == "true"
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    APP_NAME = os.getenv("APP_NAME", "cuisine-trails")
    ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
    VERSION = os.getenv("APP_VERSION", "1.0.0")
    PORT = int(os.getenv("PORT", 5000))


def setup_logging():
    """Configure structured JSON logging."""

    log_level = getattr(logging, Config.LOG_LEVEL, logging.INFO)

    class JSONFormatter(logging.Formatter):
        def format(self, record):
            payload = {
                "timestamp": datetime.utcnow().isoformat(),
                "level": record.levelname,
                "message": record.getMessage(),
                "logger": record.name,
                "environment": Config.ENVIRONMENT,
                "app_version": Config.VERSION,
            }
            if record.exc_info:
                payload["exception"] = self.formatException(record.exc_info)
            return json.dumps(payload)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    logging.basicConfig(level=log_level, handlers=[handler], format="%(message)s")
    return logging.getLogger(__name__)


logger = setup_logging()

http_request_duration_seconds = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint", "status_code"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

http_requests_total = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code"],
)

app_info = Gauge(
    "app_info",
    "Application metadata",
    ["app_name", "version", "environment"],
)

active_requests = Gauge("active_requests", "Number of active requests")

app_errors_total = Counter(
    "app_errors_total",
    "Total application errors",
    ["error_type"],
)

cuisine_views_total = Counter(
    "cuisine_views_total",
    "Cuisine frontend page views",
    ["page"],
)

app_info.labels(
    app_name=Config.APP_NAME,
    version=Config.VERSION,
    environment=Config.ENVIRONMENT,
).set(1)

app = Flask(__name__)
app.config.from_object(Config)


CUISINES = {
    "bengaluru": {
        "title": "Bengaluru Food",
        "tagline": "Tiffin counters, darshini speed, filter coffee, and late-night bites.",
        "accent": "#0f766e",
        "dishes": [
            {
                "name": "Benne Masala Dosa",
                "description": "Crisp dosa with a buttery center, potato palya, coconut chutney, and sambar.",
                "type": "Breakfast classic",
            },
            {
                "name": "Idli Vada Sambar",
                "description": "Soft idlis with a crunchy vada, served fast and hot at old-school darshinis.",
                "type": "Tiffin staple",
            },
            {
                "name": "Bisi Bele Bath",
                "description": "Rice, lentils, vegetables, tamarind, and spice powder finished with ghee.",
                "type": "Comfort bowl",
            },
            {
                "name": "Filter Coffee",
                "description": "Strong decoction, hot milk, and foam poured between steel tumbler and davara.",
                "type": "Signature sip",
            },
        ],
    },
    "odisha": {
        "title": "Odisha Food",
        "tagline": "Temple kitchens, river fish, rice plates, pithas, and gentle mustard warmth.",
        "accent": "#b45309",
        "dishes": [
            {
                "name": "Pakhala Bhata",
                "description": "Fermented rice water meal served cool with fried sides, greens, and curd.",
                "type": "Summer favorite",
            },
            {
                "name": "Dalma",
                "description": "Lentils and vegetables cooked together with cumin, ginger, and a light tempering.",
                "type": "Home-style staple",
            },
            {
                "name": "Chhena Poda",
                "description": "Baked cottage cheese dessert with caramelized edges and cardamom warmth.",
                "type": "Sweet icon",
            },
            {
                "name": "Machha Besara",
                "description": "Fish cooked in a mustard-based gravy, bright with turmeric and green chilli.",
                "type": "Coastal plate",
            },
        ],
    },
}


HOME_TEMPLATE = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bengaluru and Odisha Cuisine Trails</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #1f2933;
      --muted: #5f6c7b;
      --line: #d7dee8;
      --paper: #fffaf2;
      --panel: #ffffff;
      --teal: #0f766e;
      --saffron: #b45309;
      --leaf: #496b2d;
      --rose: #9f1239;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--ink);
      background:
        linear-gradient(135deg, rgba(15, 118, 110, 0.10), transparent 34%),
        linear-gradient(315deg, rgba(180, 83, 9, 0.12), transparent 38%),
        var(--paper);
    }

    .shell {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    header {
      padding: 28px clamp(18px, 4vw, 56px) 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      border-bottom: 1px solid rgba(31, 41, 51, 0.10);
      background: rgba(255, 250, 242, 0.86);
      backdrop-filter: blur(10px);
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 800;
      letter-spacing: 0;
    }

    .mark {
      width: 42px;
      height: 42px;
      border-radius: 8px;
      display: grid;
      place-items: center;
      color: white;
      background: linear-gradient(135deg, var(--teal), var(--saffron));
      font-weight: 900;
    }

    nav {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    nav a {
      color: var(--ink);
      text-decoration: none;
      font-weight: 700;
      padding: 9px 12px;
      border-radius: 8px;
      border: 1px solid transparent;
    }

    nav a:hover {
      border-color: var(--line);
      background: rgba(255, 255, 255, 0.6);
    }

    main {
      width: min(1180px, calc(100% - 32px));
      margin: 0 auto;
      padding: clamp(28px, 5vw, 58px) 0 54px;
    }

    .hero {
      display: grid;
      grid-template-columns: minmax(0, 1.1fr) minmax(280px, 0.9fr);
      gap: clamp(24px, 4vw, 48px);
      align-items: center;
      min-height: 430px;
    }

    h1 {
      font-size: clamp(2.4rem, 6vw, 5.8rem);
      line-height: 0.96;
      margin: 0 0 20px;
      letter-spacing: 0;
    }

    .lead {
      color: var(--muted);
      font-size: clamp(1.02rem, 2vw, 1.28rem);
      line-height: 1.65;
      max-width: 720px;
      margin: 0;
    }

    .hero-plate {
      min-height: 360px;
      border-radius: 8px;
      padding: 26px;
      background:
        radial-gradient(circle at 30% 30%, #fff7d6 0 14%, transparent 15%),
        radial-gradient(circle at 70% 28%, #b45309 0 11%, transparent 12%),
        radial-gradient(circle at 34% 72%, #0f766e 0 12%, transparent 13%),
        radial-gradient(circle at 72% 70%, #9f1239 0 10%, transparent 11%),
        #fff;
      border: 1px solid var(--line);
      box-shadow: 0 24px 60px rgba(31, 41, 51, 0.14);
      display: grid;
      align-content: end;
    }

    .hero-plate p {
      margin: 0;
      color: var(--muted);
      font-weight: 700;
      line-height: 1.5;
      background: rgba(255, 255, 255, 0.82);
      padding: 14px;
      border-radius: 8px;
      border: 1px solid rgba(215, 222, 232, 0.8);
    }

    .section-title {
      margin: 46px 0 18px;
      display: flex;
      align-items: end;
      justify-content: space-between;
      gap: 18px;
      flex-wrap: wrap;
    }

    .section-title h2 {
      margin: 0;
      font-size: clamp(1.8rem, 3vw, 2.7rem);
      letter-spacing: 0;
    }

    .section-title p {
      margin: 0;
      color: var(--muted);
      max-width: 520px;
      line-height: 1.6;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 18px;
    }

    .region {
      background: rgba(255, 255, 255, 0.78);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 20px;
    }

    .region h3 {
      margin: 0 0 8px;
      font-size: 1.5rem;
    }

    .region .tagline {
      color: var(--muted);
      line-height: 1.55;
      margin: 0 0 18px;
    }

    .dish-list {
      display: grid;
      gap: 12px;
    }

    .dish {
      border-top: 1px solid var(--line);
      padding-top: 12px;
    }

    .dish:first-child {
      border-top: 0;
      padding-top: 0;
    }

    .dish strong {
      display: block;
      font-size: 1.05rem;
      margin-bottom: 4px;
    }

    .dish span {
      display: inline-block;
      color: white;
      background: var(--accent);
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 0.78rem;
      font-weight: 800;
      margin-bottom: 8px;
    }

    .dish p {
      margin: 0;
      color: var(--muted);
      line-height: 1.5;
    }

    .routes {
      margin-top: 20px;
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }

    .routes a {
      text-decoration: none;
      color: var(--ink);
      background: #fff;
      border: 1px solid var(--line);
      padding: 10px 12px;
      border-radius: 8px;
      font-weight: 800;
    }

    footer {
      margin-top: auto;
      padding: 22px clamp(18px, 4vw, 56px);
      color: var(--muted);
      border-top: 1px solid rgba(31, 41, 51, 0.10);
      background: rgba(255, 250, 242, 0.84);
    }

    @media (max-width: 780px) {
      header { align-items: flex-start; flex-direction: column; }
      nav { justify-content: flex-start; }
      .hero { grid-template-columns: 1fr; }
      .hero-plate { min-height: 260px; }
      .grid { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <header>
      <div class="brand">
        <div class="mark">CT</div>
        <div>Cuisine Trails</div>
      </div>
      <nav aria-label="Primary navigation">
        <a href="#bengaluru">Bengaluru</a>
        <a href="#odisha">Odisha</a>
        <a href="/api/v1/cuisines">API</a>
        <a href="/health">Health</a>
      </nav>
    </header>

    <main>
      <section class="hero" aria-labelledby="page-title">
        <div>
          <h1 id="page-title">Bengaluru and Odisha on one plate.</h1>
          <p class="lead">
            A compact food guide celebrating Bengaluru tiffin culture and Odisha's
            rice-led, temple-influenced, coastal cuisine. Built as a simple Flask
            frontend that can run locally or inside your EKS deployment.
          </p>
        </div>
        <div class="hero-plate" aria-label="Abstract food plate illustration">
          <p>Benne dosa meets pakhala, filter coffee meets chhena poda, and the menu stays deployable.</p>
        </div>
      </section>

      <section class="section-title" aria-labelledby="regions-title">
        <h2 id="regions-title">Featured Cuisines</h2>
        <p>Two regional food moods: fast, fragrant Bengaluru counters and Odisha's soulful rice, lentil, fish, and sweet traditions.</p>
      </section>

      <section class="grid">
        {% for slug, cuisine in cuisines.items() %}
        <article class="region" id="{{ slug }}" style="--accent: {{ cuisine.accent }}">
          <h3>{{ cuisine.title }}</h3>
          <p class="tagline">{{ cuisine.tagline }}</p>
          <div class="dish-list">
            {% for dish in cuisine.dishes %}
            <div class="dish">
              <span>{{ dish.type }}</span>
              <strong>{{ dish.name }}</strong>
              <p>{{ dish.description }}</p>
            </div>
            {% endfor %}
          </div>
        </article>
        {% endfor %}
      </section>

      <div class="routes" aria-label="Application endpoints">
        <a href="/api/v1/cuisines">Cuisine JSON</a>
        <a href="/info">App info</a>
        <a href="/metrics">Metrics</a>
      </div>
    </main>

    <footer>
      {{ app_name }} v{{ version }} running in {{ environment }}
    </footer>
  </div>
</body>
</html>
"""


@app.before_request
def before_request():
    """Track request start time and active requests."""

    request.start_time = time.time()
    active_requests.inc()
    logger.info(f"Request started: {request.method} {request.path}")


@app.after_request
def after_request(response):
    """Record request metrics and response headers."""

    if hasattr(request, "start_time"):
        duration = time.time() - request.start_time
        endpoint = request.endpoint or "unknown"
        status_code = str(response.status_code)

        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=endpoint,
            status_code=status_code,
        ).observe(duration)

        http_requests_total.labels(
            method=request.method,
            endpoint=endpoint,
            status_code=status_code,
        ).inc()

        active_requests.dec()
        logger.info(
            f"Request completed: {request.method} {request.path} "
            f"Status: {status_code} Duration: {duration:.3f}s"
        )

    response.headers["X-App-Name"] = Config.APP_NAME
    response.headers["X-App-Version"] = Config.VERSION
    return response


@app.errorhandler(Exception)
def handle_error(error):
    """Global error handler with metrics."""

    app_errors_total.labels(error_type=type(error).__name__).inc()

    if isinstance(error, HTTPException):
        return jsonify(
            {
                "status": "error",
                "code": error.code,
                "message": error.description,
                "timestamp": datetime.utcnow().isoformat(),
                "app_version": Config.VERSION,
            }
        ), error.code

    logger.error(f"Unhandled exception: {str(error)}", exc_info=True)
    return jsonify(
        {
            "status": "error",
            "code": 500,
            "message": "Internal Server Error",
            "timestamp": datetime.utcnow().isoformat(),
            "app_version": Config.VERSION,
        }
    ), 500


@app.route("/", methods=["GET"])
def index():
    """Cuisine frontend."""

    cuisine_views_total.labels(page="home").inc()
    return render_template_string(
        HOME_TEMPLATE,
        cuisines=CUISINES,
        app_name=Config.APP_NAME,
        version=Config.VERSION,
        environment=Config.ENVIRONMENT,
    )


@app.route("/api/v1/cuisines", methods=["GET"])
def cuisines():
    """Return cuisine data used by the frontend."""

    return jsonify(
        {
            "status": "success",
            "cuisines": CUISINES,
            "timestamp": datetime.utcnow().isoformat(),
        }
    )


@app.route("/api/v1/hello", methods=["GET"])
def hello():
    """Sample API endpoint."""

    name = request.args.get("name", "World")
    return jsonify(
        {
            "status": "success",
            "message": f"Hello, {name}!",
            "timestamp": datetime.utcnow().isoformat(),
        }
    )


@app.route("/api/v1/data", methods=["GET"])
def get_data():
    """Sample API endpoint with cuisine themed data."""

    items = []
    for slug, cuisine in CUISINES.items():
        for dish in cuisine["dishes"]:
            items.append(
                {
                    "region": slug,
                    "name": dish["name"],
                    "type": dish["type"],
                    "description": dish["description"],
                }
            )

    return jsonify(
        {
            "status": "success",
            "data": {
                "items": items,
                "count": len(items),
                "timestamp": datetime.utcnow().isoformat(),
            },
        }
    )


@app.route("/api/v1/data/<int:item_id>", methods=["GET"])
def get_item(item_id):
    """Get a cuisine item by one-based list position."""

    items = []
    for slug, cuisine in CUISINES.items():
        for dish in cuisine["dishes"]:
            items.append(
                {
                    "region": slug,
                    "name": dish["name"],
                    "type": dish["type"],
                    "description": dish["description"],
                }
            )

    if item_id < 1 or item_id > len(items):
        return jsonify({"status": "error", "message": "Item not found"}), 404

    return jsonify({"status": "success", "data": items[item_id - 1]})


@app.route("/api/v1/data", methods=["POST"])
def create_item():
    """Echo a requested cuisine suggestion."""

    data = request.get_json() or {}
    if "name" not in data:
        return jsonify({"status": "error", "message": "Missing required field: name"}), 400

    return jsonify(
        {
            "status": "success",
            "message": "Cuisine suggestion received",
            "data": {
                "name": data.get("name"),
                "region": data.get("region", "unknown"),
                "created_at": datetime.utcnow().isoformat(),
            },
        }
    ), 201


@app.route("/api/v1/config", methods=["GET"])
def get_config():
    """Return non-sensitive application configuration."""

    return jsonify(
        {
            "status": "success",
            "config": {
                "app_name": Config.APP_NAME,
                "environment": Config.ENVIRONMENT,
                "version": Config.VERSION,
                "debug": Config.DEBUG,
                "log_level": Config.LOG_LEVEL,
            },
        }
    )


@app.route("/api/v1/echo", methods=["POST"])
def echo():
    """Echo back the request data."""

    return jsonify(
        {
            "status": "success",
            "echo": request.get_json() or {},
            "timestamp": datetime.utcnow().isoformat(),
        }
    )


@app.route("/health", methods=["GET"])
def health_check():
    """Kubernetes liveness endpoint."""

    return jsonify(
        {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "app_name": Config.APP_NAME,
            "version": Config.VERSION,
            "environment": Config.ENVIRONMENT,
        }
    ), 200


@app.route("/api/v1/health", methods=["GET"])
def api_health_check():
    """API health endpoint."""

    return health_check()


@app.route("/health/ready", methods=["GET"])
def readiness_probe():
    """Kubernetes readiness endpoint."""

    return jsonify(
        {
            "status": "ready",
            "timestamp": datetime.utcnow().isoformat(),
            "dependencies": {
                "app": "ok",
                "cuisine_data": "ok",
            },
        }
    ), 200


@app.route("/health/live", methods=["GET"])
def liveness_probe():
    """Kubernetes liveness detail endpoint."""

    return jsonify({"status": "alive", "app_name": Config.APP_NAME}), 200


@app.route("/health/startup", methods=["GET"])
def startup_probe():
    """Kubernetes startup endpoint."""

    return jsonify(
        {
            "status": "started",
            "timestamp": datetime.utcnow().isoformat(),
            "initialization_time_ms": 150,
        }
    ), 200


@app.route("/metrics", methods=["GET"])
def metrics():
    """Prometheus metrics endpoint."""

    return generate_latest(prometheus_client.REGISTRY), 200, {
        "Content-Type": "text/plain; version=0.0.4; charset=utf-8"
    }


@app.route("/info", methods=["GET"])
def app_info_endpoint():
    """Application information endpoint."""

    return jsonify(
        {
            "app_name": Config.APP_NAME,
            "version": Config.VERSION,
            "environment": Config.ENVIRONMENT,
            "debug_mode": Config.DEBUG,
            "log_level": Config.LOG_LEVEL,
            "timestamp": datetime.utcnow().isoformat(),
        }
    ), 200


@app.route("/version", methods=["GET"])
def version():
    """Return application version information."""

    return jsonify(
        {
            "app_name": Config.APP_NAME,
            "version": Config.VERSION,
            "environment": Config.ENVIRONMENT,
            "python_version": sys.version,
            "flask_version": __import__("flask").__version__,
            "timestamp": datetime.utcnow().isoformat(),
        }
    ), 200


def shutdown_handler(signum, frame):
    """Handle graceful shutdown."""

    logger.info(f"Received signal {signum}. Starting graceful shutdown.")
    sys.exit(0)


signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)


if __name__ == "__main__":
    logger.info(f"Starting {Config.APP_NAME} v{Config.VERSION}")
    logger.info(f"Environment: {Config.ENVIRONMENT}")
    logger.info(f"Listening on port {Config.PORT}")
    app.run(
        host="0.0.0.0",
        port=Config.PORT,
        debug=Config.DEBUG,
        threaded=True,
        use_reloader=False,
    )
