#!/usr/bin/env python3
"""Restore a local store's database and public media from a verified demo bundle."""
import argparse
import base64
import datetime
import hashlib
import gzip
import json
import subprocess
import shutil
import sys
import tarfile
from pathlib import Path, PurePosixPath

ROOT=Path(__file__).resolve().parents[2]

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context',required=True); p.add_argument('--store',choices=('a','b'),required=True)
    p.add_argument('--bundle',type=Path,required=True); p.add_argument('--replace-existing',action='store_true')
    p.add_argument('--writers-paused',action='store_true')
    a=p.parse_args()
    if a.context!='minikube': p.error('this local runner only permits context minikube')
    if not a.replace_existing or not a.writers_paused: p.error('pass --replace-existing and --writers-paused after stopping all writers')
    if (a.bundle/'INCOMPLETE').exists(): raise RuntimeError('incomplete bundle')
    m=json.loads((a.bundle/'manifest.json').read_text())
    sqlname='bagisto.sql.gz' if 'bagisto.sql.gz' in m['sha256'] else 'bagisto.sql'
    for name in (sqlname,'media.tar.gz'):
        if digest(a.bundle/name)!=m['sha256'][name]: raise RuntimeError('checksum mismatch: '+name)
    with tarfile.open(a.bundle/'media.tar.gz','r:gz') as tar:
        for member in tar:
            path=PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0]!='public' or not(member.isfile() or member.isdir()): raise RuntimeError('unsafe media member '+member.name)
    ns='store-'+a.store; k=['kubectl','--context='+a.context,'-n',ns]; helper='capstone-bundle-restore'
    def run(args,**kwargs): return subprocess.run(args,check=True,**kwargs)
    run(['kubectl','--context='+a.context,'apply','--server-side','-k',str(ROOT/'k8s/overlays'/a.store/'bagisto_db')])
    run(k+['rollout','status','statefulset/mariadb','--timeout=180s'])
    key=run(k+['get','secret','app-secret','-o','jsonpath={.data.appkey}'],capture_output=True).stdout
    if hashlib.sha256(base64.b64decode(key)).hexdigest()!=m['app_key_sha256']: raise RuntimeError('APP_KEY mismatch')
    dbname=base64.b64decode(run(k+['get','secret','app-secret','-o','jsonpath={.data.database}'],capture_output=True).stdout).decode()
    if dbname!='bagisto': raise RuntimeError('expected database bagisto; refusing replacement')
    # Applying the app overlay creates the media PVC if this is a fresh deployment.
    run(['kubectl','--context='+a.context,'apply','--server-side','-k',str(ROOT/'k8s/overlays'/a.store/'bagisto_app')])
    if subprocess.run(k+['get','pod',helper],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0: raise RuntimeError('restore helper already exists; inspect before proceeding')
    run(k+['delete','deployment','bagisto','--ignore-not-found=true','--wait=true'])
    if run(k+['get','pods','-l','app=bagisto','-o','name'],capture_output=True,text=True).stdout.strip():
        run(k+['wait','--for=delete','pod','-l','app=bagisto','--timeout=180s'])
    spec={'apiVersion':'v1','kind':'Pod','metadata':{'name':helper,'namespace':ns},'spec':{'restartPolicy':'Never','containers':[{'name':'helper','image':'webkul/bagisto:2.4.13-nginx-mariadb','command':['sleep','7200'],'volumeMounts':[{'name':'media','mountPath':'/work/public'}]}],'volumes':[{'name':'media','persistentVolumeClaim':{'claimName':'bagisto-media'}}]}}
    run(k+['apply','-f','-'],input=json.dumps(spec),text=True)
    run(k+['wait','--for=condition=Ready','pod/'+helper,'--timeout=180s'])
    backup=ROOT/'artifacts'/'backups'/('before-default-'+ns+'-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    backup.mkdir(parents=True,exist_ok=False); (backup/'INCOMPLETE').touch()
    db=k+['exec','mariadb-0','--','sh','-c']
    with (backup/'bagisto.sql').open('wb') as out:
        run(db+['MYSQL_PWD="$MARIADB_PASSWORD" mariadb-dump -h 127.0.0.1 -u "$MARIADB_USER" --single-transaction --skip-lock-tables "$MARIADB_DATABASE"'],stdout=out)
    with (backup/'media.tar.gz').open('wb') as out:
        run(k+['exec',helper,'--','tar','-C','/work','-czf','-','public'],stdout=out)
    (backup/'INCOMPLETE').unlink()
    print('Saved rollback backup:',backup,flush=True)
    run(db+['MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h 127.0.0.1 -u root -e "DROP DATABASE bagisto; CREATE DATABASE bagisto CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"'])
    loader=k+['exec','-i','mariadb-0','--','sh','-c','MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" "$MARIADB_DATABASE"']
    if sqlname.endswith('.gz'):
        proc=subprocess.Popen(loader,stdin=subprocess.PIPE)
        with gzip.open(a.bundle/sqlname,'rb') as f: shutil.copyfileobj(f,proc.stdin,1024*1024)
        proc.stdin.close()
        if proc.wait(): raise RuntimeError('database import failed; target may be partial')
    else:
        with (a.bundle/sqlname).open('rb') as f: run(loader,stdin=f)
    run(k+['exec',helper,'--','sh','-c','find /work/public -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +'])
    with (a.bundle/'media.tar.gz').open('rb') as f:
        run(k+['exec','-i',helper,'--','tar','-C','/work/public','--strip-components=1','-xzf','-'],stdin=f)
    run(k+['exec',helper,'--','chown','-R','www-data:www-data','/work/public'])
    run(k+['delete','pod',helper,'--wait=true'])
    run(['kubectl','--context='+a.context,'apply','--server-side','-k',str(ROOT/'k8s/overlays'/a.store/'bagisto_app')])
    run(k+['rollout','status','deployment/bagisto','--timeout=300s'])
    print('Store',a.store,'restored; verify before routing traffic.')

if __name__=='__main__':
    try: main()
    except (RuntimeError,subprocess.CalledProcessError) as exc:
        print('Restore failed; inspect target and saved backup before retrying:',exc,file=sys.stderr); sys.exit(1)
