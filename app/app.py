"""
Production-grade Flask application with comprehensive monitoring and health checks.
Features:
- Structured logging
- Prometheus metrics
- Health check endpoints
- Graceful shutdown
- Environment configuration
- Request tracing
"""

import os
import logging
import json
from datetime import datetime
from functools import wraps
import time
import sys

from flask import Flask, jsonify, request, render_template_string
from werkzeug.exceptions import HTTPException
import prometheus_client
from prometheus_client import Counter, Histogram, Gauge, generate_latest

# ============================================================================
# Configuration and Initialization
# ============================================================================

class Config:
    """Application configuration from environment variables."""
    DEBUG = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    APP_NAME = os.getenv('APP_NAME', 'production-app')
    ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
    VERSION = os.getenv('APP_VERSION', '1.0.0')
    PORT = int(os.getenv('PORT', 5000))


# ============================================================================
# Logging Configuration
# ============================================================================

def setup_logging():
    """Configure structured JSON logging for production."""
    log_level = getattr(logging, Config.LOG_LEVEL, logging.INFO)
    
    # Console handler with JSON formatting
    class JSONFormatter(logging.Formatter):
        def format(self, record):
            log_data = {
                'timestamp': datetime.utcnow().isoformat(),
                'level': record.levelname,
                'message': record.getMessage(),
                'logger': record.name,
                'environment': Config.ENVIRONMENT,
                'app_version': Config.VERSION,
            }
            if record.exc_info:
                log_data['exception'] = self.formatException(record.exc_info)
            return json.dumps(log_data)
    
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    
    logging.basicConfig(
        level=log_level,
        handlers=[handler],
        format='%(message)s'
    )
    
    return logging.getLogger(__name__)


logger = setup_logging()

# ============================================================================
# Prometheus Metrics
# ============================================================================

# HTTP metrics
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint', 'status_code'],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
)

http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

# Application metrics
app_info = Gauge(
    'app_info',
    'Application metadata',
    ['app_name', 'version', 'environment']
)

active_requests = Gauge(
    'active_requests',
    'Number of active requests'
)

app_errors_total = Counter(
    'app_errors_total',
    'Total application errors',
    ['error_type']
)

# Database/External service metrics (simulated)
external_api_calls_total = Counter(
    'external_api_calls_total',
    'Total external API calls',
    ['service', 'status']
)

external_api_duration_seconds = Histogram(
    'external_api_duration_seconds',
    'External API call duration in seconds',
    ['service'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 5.0)
)

# Set app info
app_info.labels(
    app_name=Config.APP_NAME,
    version=Config.VERSION,
    environment=Config.ENVIRONMENT
).set(1)

# ============================================================================
# Flask Application
# ============================================================================

app = Flask(__name__)
app.config.from_object(Config)

# ============================================================================
# Middleware for Metrics and Logging
# ============================================================================

@app.before_request
def before_request():
    """Track request start time and increment active requests."""
    request.start_time = time.time()
    active_requests.inc()
    logger.info(f"Request started: {request.method} {request.path}")


@app.after_request
def after_request(response):
    """Record request metrics and logs."""
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        
        # Record Prometheus metrics
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown',
            status_code=response.status_code
        ).observe(duration)
        
        http_requests_total.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown',
            status_code=response.status_code
        ).inc()
        
        active_requests.dec()
        
        # Log request completion
        logger.info(
            f"Request completed: {request.method} {request.path} "
            f"Status: {response.status_code} Duration: {duration:.3f}s"
        )
    
    response.headers['X-App-Name'] = Config.APP_NAME
    response.headers['X-App-Version'] = Config.VERSION
    return response


@app.errorhandler(Exception)
def handle_error(error):
    """Global error handler with metrics."""
    app_errors_total.labels(error_type=type(error).__name__).inc()
    
    if isinstance(error, HTTPException):
        response = {
            'status': 'error',
            'code': error.code,
            'message': error.description,
            'timestamp': datetime.utcnow().isoformat(),
            'app_version': Config.VERSION
        }
        return jsonify(response), error.code
    
    logger.error(f"Unhandled exception: {str(error)}", exc_info=True)
    response = {
        'status': 'error',
        'code': 500,
        'message': 'Internal Server Error',
        'timestamp': datetime.utcnow().isoformat(),
        'app_version': Config.VERSION
    }
    return jsonify(response), 500


# ============================================================================
# Routes
# ============================================================================

@app.route('/', methods=['GET'])
def index():
    """Root endpoint - returns application metadata."""
    return jsonify({
        'status': 'ok',
        'app_name': Config.APP_NAME,
        'version': Config.VERSION,
        'environment': Config.ENVIRONMENT,
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/api/v1/hello', methods=['GET'])
def hello():
    """Sample API endpoint."""
    name = request.args.get('name', 'World')
    return jsonify({
        'status': 'success',
        'message': f'Hello, {name}!',
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/api/v1/health', methods=['GET'])
def health():
    """Basic health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'app_name': Config.APP_NAME,
        'version': Config.VERSION,
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/health', methods=['GET'])
def health_simple():
    """Simple health check endpoint for load balancers."""
    return 'OK', 200


@app.route('/health/ready', methods=['GET'])
def readiness_probe():
    """Kubernetes readiness probe endpoint."""
    # Add application-specific readiness checks here
    # (e.g., database connectivity, external service availability)
    try:
        # Simulate checking dependencies
        return jsonify({
            'status': 'ready',
            'checks': {
                'app': 'ok',
                'dependencies': 'ok'
            }
        }), 200
    except Exception as e:
        logger.error(f"Readiness check failed: {str(e)}")
        return jsonify({
            'status': 'not_ready',
            'error': str(e)
        }), 503


@app.route('/health/live', methods=['GET'])
def liveness_probe():
    """Kubernetes liveness probe endpoint."""
    return jsonify({
        'status': 'alive',
        'app_name': Config.APP_NAME
    }), 200


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest(prometheus_client.REGISTRY), 200, {
        'Content-Type': 'text/plain; version=0.0.4; charset=utf-8'
    }


@app.route('/api/v1/data', methods=['GET'])
def get_data():
    """Sample data endpoint with metrics tracking."""
    try:
        # Simulate external API call
        start_time = time.time()
        # Simulate API call
        time.sleep(0.1)
        duration = time.time() - start_time
        
        external_api_calls_total.labels(service='sample_api', status='success').inc()
        external_api_duration_seconds.labels(service='sample_api').observe(duration)
        
        return jsonify({
            'status': 'success',
            'data': {
                'id': 1,
                'message': 'Sample data',
                'timestamp': datetime.utcnow().isoformat()
            }
        })
    except Exception as e:
        external_api_calls_total.labels(service='sample_api', status='error').inc()
        logger.error(f"Error in get_data: {str(e)}")
        raise


@app.route('/api/v1/config', methods=['GET'])
def get_config():
    """Return application configuration (non-sensitive)."""
    return jsonify({
        'status': 'success',
        'config': {
            'app_name': Config.APP_NAME,
            'environment': Config.ENVIRONMENT,
            'version': Config.VERSION,
            'debug': Config.DEBUG,
            'log_level': Config.LOG_LEVEL
        }
    })


@app.route('/api/v1/echo', methods=['POST'])
def echo():
    """Echo back the request data."""
    data = request.get_json() or {}
    return jsonify({
        'status': 'success',
        'echo': data,
        'timestamp': datetime.utcnow().isoformat()
    })


# ============================================================================
# Graceful Shutdown
# ============================================================================

import signal

shutdown_event = None

def signal_handler(signum, frame):
    """Handle graceful shutdown on SIGTERM and SIGINT."""
    logger.info(f"Received signal {signum}. Starting graceful shutdown...")
    # Set shutdown flag - in production this would trigger cleanup
    sys.exit(0)


signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


# ============================================================================
# Application Entry Point
# ============================================================================

if __name__ == '__main__':
    logger.info(f"Starting {Config.APP_NAME} v{Config.VERSION}")
    logger.info(f"Environment: {Config.ENVIRONMENT}")
    logger.info(f"Debug mode: {Config.DEBUG}")
    logger.info(f"Listening on port {Config.PORT}")
    
    # Use production WSGI server (gunicorn) in production
    # For development, Flask development server can be used
    if Config.DEBUG:
        app.run(
            host='0.0.0.0',
            port=Config.PORT,
            debug=Config.DEBUG,
            use_reloader=False
        )
    else:
        # In production, use: gunicorn --workers 4 --worker-class sync app:app
        app.run(host='0.0.0.0', port=Config.PORT, debug=False)
    
    response = {
        'status': 'error',
        'code': 500,
        'message': 'Internal Server Error',
        'timestamp': datetime.utcnow().isoformat(),
        'app_version': Config.VERSION
    }
    return jsonify(response), 500


# ============================================================================
# Health Check Endpoints
# ============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """
    Kubernetes liveness probe endpoint.
    Returns 200 if the application is running.
    """
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'app_name': Config.APP_NAME,
        'version': Config.VERSION,
        'environment': Config.ENVIRONMENT
    }), 200


@app.route('/health/ready', methods=['GET'])
def readiness_probe():
    """
    Kubernetes readiness probe endpoint.
    Returns 200 if the application is ready to serve traffic.
    """
    # Simulate dependency checks
    dependencies_healthy = True
    
    # In production, check actual dependencies here:
    # - Database connectivity
    # - Cache connectivity
    # - External service availability
    
    if not dependencies_healthy:
        return jsonify({
            'status': 'not_ready',
            'timestamp': datetime.utcnow().isoformat(),
            'reason': 'Dependency check failed'
        }), 503
    
    return jsonify({
        'status': 'ready',
        'timestamp': datetime.utcnow().isoformat(),
        'dependencies': {
            'database': 'connected',
            'cache': 'connected'
        }
    }), 200


@app.route('/health/startup', methods=['GET'])
def startup_probe():
    """
    Kubernetes startup probe endpoint.
    Returns 200 when the application has completed initialization.
    """
    return jsonify({
        'status': 'started',
        'timestamp': datetime.utcnow().isoformat(),
        'initialization_time_ms': 150
    }), 200


# ============================================================================
# Metrics Endpoint
# ============================================================================

@app.route('/metrics', methods=['GET'])
def metrics():
    """
    Prometheus metrics endpoint.
    Returns metrics in Prometheus text format.
    """
    return generate_latest(prometheus_client.REGISTRY), 200, {'Content-Type': 'text/plain; charset=utf-8'}


# ============================================================================
# API Endpoints
# ============================================================================

@app.route('/', methods=['GET'])
def index():
    """Home endpoint with application information."""
    return jsonify({
        'message': 'Welcome to Production-Grade DevOps Application',
        'app_name': Config.APP_NAME,
        'version': Config.VERSION,
        'environment': Config.ENVIRONMENT,
        'endpoints': {
            'health': '/health',
            'readiness': '/health/ready',
            'startup': '/health/startup',
            'metrics': '/metrics',
            'api': '/api/v1/data',
            'info': '/info'
        }
    }), 200


@app.route('/info', methods=['GET'])
def app_info_endpoint():
    """Application information endpoint."""
    return jsonify({
        'app_name': Config.APP_NAME,
        'version': Config.VERSION,
        'environment': Config.ENVIRONMENT,
        'debug_mode': Config.DEBUG,
        'log_level': Config.LOG_LEVEL,
        'timestamp': datetime.utcnow().isoformat(),
        'uptime': 'N/A',  # Would track actual uptime in production
    }), 200


@app.route('/api/v1/data', methods=['GET'])
def get_data():
    """
    Sample API endpoint with metrics tracking.
    Demonstrates external API call tracking.
    """
    try:
        # Simulate external API call
        start_time = time.time()
        
        # Sample data
        data = {
            'items': [
                {'id': 1, 'name': 'Item 1', 'status': 'active'},
                {'id': 2, 'name': 'Item 2', 'status': 'active'},
                {'id': 3, 'name': 'Item 3', 'status': 'inactive'},
            ],
            'count': 3,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Record external call metric
        duration = time.time() - start_time
        external_api_calls_total.labels(service='database', status='success').inc()
        external_api_duration_seconds.labels(service='database').observe(duration)
        
        logger.info(f"Data retrieved successfully, count: {len(data['items'])}")
        
        return jsonify({
            'status': 'success',
            'data': data
        }), 200
        
    except Exception as e:
        external_api_calls_total.labels(service='database', status='error').inc()
        app_errors_total.labels(error_type='data_retrieval_error').inc()
        logger.error(f"Error retrieving data: {str(e)}", exc_info=True)
        
        return jsonify({
            'status': 'error',
            'message': 'Failed to retrieve data',
            'timestamp': datetime.utcnow().isoformat()
        }), 500


@app.route('/api/v1/data/<int:item_id>', methods=['GET'])
def get_item(item_id):
    """Get a specific item by ID."""
    try:
        # Simulate database lookup
        item = {
            'id': item_id,
            'name': f'Item {item_id}',
            'description': f'This is item number {item_id}',
            'status': 'active',
            'created_at': datetime.utcnow().isoformat()
        }
        
        external_api_calls_total.labels(service='database', status='success').inc()
        
        return jsonify({
            'status': 'success',
            'data': item
        }), 200
        
    except Exception as e:
        external_api_calls_total.labels(service='database', status='error').inc()
        app_errors_total.labels(error_type='item_lookup_error').inc()
        logger.error(f"Error retrieving item {item_id}: {str(e)}", exc_info=True)
        
        return jsonify({
            'status': 'error',
            'message': f'Item {item_id} not found'
        }), 404


@app.route('/api/v1/data', methods=['POST'])
def create_item():
    """Create a new item."""
    try:
        data = request.get_json()
        
        if not data or 'name' not in data:
            return jsonify({
                'status': 'error',
                'message': 'Missing required field: name'
            }), 400
        
        # Simulate database insert
        new_item = {
            'id': 4,  # Would use actual ID from database
            'name': data.get('name'),
            'status': 'active',
            'created_at': datetime.utcnow().isoformat()
        }
        
        external_api_calls_total.labels(service='database', status='success').inc()
        logger.info(f"Item created: {new_item['id']} - {new_item['name']}")
        
        return jsonify({
            'status': 'success',
            'data': new_item,
            'message': 'Item created successfully'
        }), 201
        
    except Exception as e:
        external_api_calls_total.labels(service='database', status='error').inc()
        app_errors_total.labels(error_type='item_creation_error').inc()
        logger.error(f"Error creating item: {str(e)}", exc_info=True)
        
        return jsonify({
            'status': 'error',
            'message': 'Failed to create item'
        }), 500


# ============================================================================
# Version and Build Info
# ============================================================================

@app.route('/version', methods=['GET'])
def version():
    """Return application version information."""
    return jsonify({
        'app_name': Config.APP_NAME,
        'version': Config.VERSION,
        'environment': Config.ENVIRONMENT,
        'python_version': sys.version,
        'flask_version': __import__('flask').__version__,
        'timestamp': datetime.utcnow().isoformat()
    }), 200


# ============================================================================
# Graceful Shutdown
# ============================================================================

def shutdown_handler(signum, frame):
    """Handle graceful shutdown."""
    logger.info("Shutdown signal received, gracefully closing...")
    sys.exit(0)


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == '__main__':
    logger.info(f"Starting {Config.APP_NAME} v{Config.VERSION} in {Config.ENVIRONMENT} environment")
    logger.info(f"Debug mode: {Config.DEBUG}")
    logger.info(f"Log level: {Config.LOG_LEVEL}")
    
    # Run Flask application
    # In production, use gunicorn or uwsgi instead
    app.run(
        host='0.0.0.0',
        port=Config.PORT,
        debug=Config.DEBUG,
        threaded=True,
        use_reloader=False  # Disable reloader for production
    )
