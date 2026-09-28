#!/usr/bin/env python3
"""Local visual editor. Serves only editor assets and the validated layout file."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / 'Resources/gui-layout.json'
DEFAULT = json.loads((ROOT / 'Designer/default-layout.json').read_text())
SPECS = {item['id']: item for item in DEFAULT['items']}
LOCK = threading.Lock()
ASSETS = {'/': ('index.html', 'text/html'), '/studio.css': ('studio.css', 'text/css'), '/studio.js': ('studio.js', 'text/javascript'), '/default-layout.json': ('default-layout.json', 'application/json')}


def validate(layout):
    if not isinstance(layout, dict) or set(layout) != {'version', 'width', 'height', 'items'}:
        raise ValueError('Unrecognized layout format.')
    if layout['version'] != 1 or layout['width'] != 1040 or layout['height'] != 660:
        raise ValueError('Use the 1040 × 660 dashboard canvas.')
    items = layout['items']
    if not isinstance(items, list) or not len(SPECS) <= len(items) <= 100:
        raise ValueError('The layout must retain its dashboard controls, with at most 100 objects.')
    seen = set()
    for item in items:
        if not isinstance(item, dict) or set(item) != set(DEFAULT['items'][0]):
            raise ValueError('Invalid object properties.')
        key = item['id']
        if not isinstance(key, str) or key in seen:
            raise ValueError('Object IDs must be unique.')
        seen.add(key)
        spec = SPECS.get(key)
        if spec:
            if item['kind'] != spec['kind']:
                raise ValueError('The type of an app control cannot be changed.')
        elif not re.fullmatch(r'custom_[a-zA-Z0-9_-]{1,64}', key) or item['kind'] != 'text':
            raise ValueError('Only extra text labels can be inserted.')
        for name, limit in [('name', 80), ('text', 500), ('color', 7)]:
            if not isinstance(item[name], str) or len(item[name]) > limit:
                raise ValueError('An object contains invalid text.')
        if item['color'] and not re.fullmatch(r'#[a-fA-F0-9]{6}', item['color']):
            raise ValueError('Use a six-digit color.')
        if type(item['visible']) is not bool:
            raise ValueError('Visibility must be true or false.')
        for key in ['x', 'y', 'width', 'height', 'fontSize']:
            if type(item[key]) not in (float, int) or not math.isfinite(item[key]):
                raise ValueError('Size and position must be finite numbers.')
        if not (0 <= item['x'] <= 1039 and 0 <= item['y'] <= 659 and
                1 <= item['width'] <= 1040 - item['x'] and 1 <= item['height'] <= 660 - item['y'] and
                8 <= item['fontSize'] <= 72):
            raise ValueError('Keep objects inside the canvas; font size is 8–72.')
    if not set(SPECS) <= seen:
        raise ValueError('App controls cannot be removed. Hide them instead.')
    return layout


def revision(data):
    return hashlib.sha256(data).hexdigest()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # Never log request content or authentication headers.

    def respond(self, status, data, content_type='application/json', extra=None):
        self.send_response(status)
        self.send_header('Content-Type', content_type + '; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'self'; object-src 'none'; base-uri 'none'")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def error(self, code, message):
        self.respond(code, json.dumps({'error': message}).encode())

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == '/api/layout':
            with LOCK:
                data = LAYOUT.read_bytes()
            self.respond(200, data, extra={'ETag': revision(data)})
        elif path in ASSETS:
            filename, mime = ASSETS[path]
            self.respond(200, (ROOT / 'Designer' / filename).read_bytes(), mime)
        else:
            self.error(404, 'Not found.')

    def do_PUT(self):
        if self.path != '/api/layout':
            return self.error(404, 'Not found.')
        # A cross-site form cannot set this header; no CORS is enabled.
        # Codespaces/Live Share supply their own authentication outside loopback.
        if self.headers.get('X-Morning-Canvas-Editor') != '1' or self.headers.get('Sec-Fetch-Site') == 'cross-site':
            return self.error(403, 'Save from the visual editor.')
        if self.headers.get('Content-Type') != 'application/json':
            return self.error(415, 'Expected a JSON layout.')
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 128000:
                return self.error(413, 'Layout is too large.')
            data = (json.dumps(validate(json.loads(self.rfile.read(size))), indent=2, ensure_ascii=False) + '\n').encode()
        except (ValueError, TypeError, KeyError):
            return self.error(400, 'Invalid layout. Keep objects within the canvas and retain all app controls.')
        with LOCK:
            if self.headers.get('If-Match') != revision(LAYOUT.read_bytes()):
                return self.error(409, 'Someone saved a newer layout. Export your draft, then Reload saved to get their changes.')
            fd, temporary = tempfile.mkstemp(dir=LAYOUT.parent, prefix='.gui-layout-')
            try:
                with os.fdopen(fd, 'wb') as f:
                    f.write(data)
                os.replace(temporary, LAYOUT)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        self.respond(200, data, extra={'ETag': revision(data)})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8001)
    args = parser.parse_args()
    validate(json.loads(LAYOUT.read_text()))
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Morning Canvas Studio: http://127.0.0.1:{args.port}', flush=True)
    server.serve_forever()
