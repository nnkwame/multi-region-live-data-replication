#!/usr/bin/env python3
"""Package a quiescent demo database with its matching default public media."""
import argparse
import hashlib
import gzip
import json
import shutil
import subprocess
import time
from pathlib import Path


def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context',required=True); p.add_argument('--namespace',required=True)
    p.add_argument('--database',required=True); p.add_argument('--media',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True); p.add_argument('--writes-paused',action='store_true')
    p.add_argument('--compress',action='store_true',help='gzip the SQL dump to save space')
    p.add_argument('--pod-compress',action='store_true',help='compress in the pod before transfer to avoid long exec streams')
    a=p.parse_args()
    import re,base64
    if not re.fullmatch(r'[A-Za-z0-9_]+',a.database): p.error('invalid database')
    if a.pod_compress and not a.compress: p.error('--pod-compress requires --compress')
    if not a.writes_paused: p.error('stop all writers and pass --writes-paused')
    a.output.mkdir(parents=True,exist_ok=False)
    marker=a.output/'INCOMPLETE'; marker.touch()
    k=['kubectl','--context='+a.context,'-n',a.namespace]
    sqlname='bagisto.sql.gz' if a.compress else 'bagisto.sql'
    dump=k+['exec','mariadb-0','--','sh','-c','MYSQL_PWD="$MARIADB_PASSWORD" mariadb-dump -h 127.0.0.1 -u "$MARIADB_USER" --single-transaction --skip-lock-tables "$1"','sh',a.database]
    with (a.output/sqlname).open('wb') as out:
        if a.pod_compress:
            pod=k+['exec','mariadb-0','--']
            temp=subprocess.run(pod+['mktemp','-d','/tmp/capstone-bundle.XXXXXXXX'],capture_output=True,text=True,check=True).stdout.strip()
            command='''nohup bash -c 'set -o pipefail; MYSQL_PWD="$MARIADB_PASSWORD" mariadb-dump -h 127.0.0.1 -u "$MARIADB_USER" --single-transaction --skip-lock-tables "$1" | gzip -n > "$2/dump.gz"; echo "$?" > "$2/status"' sh "$1" "$2" </dev/null >"$2/log" 2>&1 &'''
            subprocess.run(pod+['sh','-c',command,'sh',a.database,temp],check=True)
            for _ in range(1800):
                result=subprocess.run(pod+['sh','-c','test ! -f "$1/status" || cat "$1/status"','sh',temp],capture_output=True,text=True,check=True).stdout.strip()
                if result:
                    if result != '0': raise RuntimeError(f'pod database dump failed; inspect {temp}/log')
                    break
                time.sleep(2)
            else: raise RuntimeError(f'pod database dump timed out; inspect {temp}')
            subprocess.run(pod+['cat',temp+'/dump.gz'],stdout=out,check=True)
            print(f'Compressed database copied; pod temporary files remain in {temp}')
        elif a.compress:
            proc=subprocess.Popen(dump,stdout=subprocess.PIPE)
            with gzip.GzipFile(filename='',mode='wb',fileobj=out,mtime=0) as zipped:
                shutil.copyfileobj(proc.stdout,zipped,1024*1024)
            proc.stdout.close()
            if proc.wait(): raise RuntimeError('database dump failed')
        else:
            subprocess.run(dump,stdout=out,check=True)
    shutil.copyfile(a.media,a.output/'media.tar.gz')
    secret=subprocess.run(k+['get','secret','app-secret','-o','jsonpath={.data.appkey}'],capture_output=True,check=True).stdout
    m={'format_version':1,'bagisto_version':'2.4.13','api_version':'2.4.4','database':'MariaDB 10.11.19','app_key_sha256':hashlib.sha256(base64.b64decode(secret)).hexdigest(),'source_database':a.database,'sha256':{n:digest(a.output/n) for n in (sqlname,'media.tar.gz')}}
    (a.output/'manifest.json').write_text(json.dumps(m,indent=2)+'\n'); marker.unlink()
    print(f'Created bundle {a.output}')
if __name__=='__main__': main()
