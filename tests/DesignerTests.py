import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.request import Request, urlopen
from urllib.error import HTTPError

spec = importlib.util.spec_from_file_location('designer', Path(__file__).resolve().parents[1] / 'tools/designer.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)

class DesignerTests(unittest.TestCase):
    def test_validation(self):
        d.validate(copy.deepcopy(d.DEFAULT))
        for mutate in [lambda x:x['items'].pop(), lambda x:x['items'].append(x['items'][0]),
                       lambda x:x['items'][0].update(x=float('nan')),lambda x:x['items'][0].update(width=99999),
                       lambda x:x['items'][0].update(kind='script'),lambda x:x['items'][0].update(color='url(x)'),
                       lambda x:x['items'][0].update(text={}),lambda x:x['items'][0].update(x=True)]:
            data = copy.deepcopy(d.DEFAULT)
            mutate(data)
            with self.assertRaises(ValueError): d.validate(data)

    def test_save_conflict_and_file_boundary(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = d.LAYOUT
            d.LAYOUT = Path(tmp) / 'gui-layout.json'
            d.LAYOUT.write_text(json.dumps(d.DEFAULT))
            server = d.ThreadingHTTPServer(('127.0.0.1', 0), d.Handler)
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            base = 'http://127.0.0.1:' + str(server.server_port)
            try:
                response = urlopen(base + '/api/layout')
                tag = response.headers['ETag']
                data = json.loads(response.read())
                data['items'][0]['text'] = 'Changed title'
                payload = json.dumps(data).encode()
                headers = {'Content-Type':'application/json','X-Morning-Canvas-Editor':'1','If-Match':tag}
                result = urlopen(Request(base+'/api/layout',payload,headers,method='PUT'))
                self.assertNotEqual(tag, result.headers['ETag'])
                self.assertEqual(json.loads(d.LAYOUT.read_text())['items'][0]['text'],'Changed title')
                with self.assertRaises(HTTPError) as conflict:
                    urlopen(Request(base+'/api/layout',payload,headers,method='PUT'))
                self.assertEqual(conflict.exception.code,409)
                with self.assertRaises(HTTPError) as cross_site:
                    urlopen(Request(base+'/api/layout',payload,{'Content-Type':'application/json'},method='PUT'))
                self.assertEqual(cross_site.exception.code,403)
                for path in ['/MorningCanvas.m','/../Resources/gui-layout.json','/.env','/canvas-token']:
                    with self.assertRaises(HTTPError) as missing: urlopen(base+path)
                    self.assertEqual(missing.exception.code,404)
            finally:
                server.shutdown();server.server_close();worker.join();d.LAYOUT=original

if __name__ == '__main__': unittest.main()
