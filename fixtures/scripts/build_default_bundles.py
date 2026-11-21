#!/usr/bin/env python3
"""Build both source and three destination bundles from a default Bagisto baseline."""
import argparse
import re
import subprocess
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context',required=True); p.add_argument('--namespace',required=True)
    p.add_argument('--baseline-sql',type=Path,required=True); p.add_argument('--baseline-media',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True); p.add_argument('--db-prefix',required=True)
    p.add_argument('--small-customers',type=int,default=8000); p.add_argument('--small-orders',type=int,default=50000)
    p.add_argument('--large-customers',type=int,default=100000); p.add_argument('--large-orders',type=int,default=1000000)
    a=p.parse_args()
    if a.context!='minikube': p.error('only minikube is supported by this local workflow')
    if not re.fullmatch(r'capstone_[A-Za-z0-9_]{1,27}',a.db_prefix): p.error('db-prefix must start with capstone_ and be at most 36 characters')
    if min(a.small_customers,a.small_orders,a.large_customers,a.large_orders)<0 or (a.small_orders and not a.small_customers) or (a.large_orders and not a.large_customers): p.error('invalid dataset sizes')
    if not a.baseline_sql.is_file() or not a.baseline_media.is_file(): p.error('baseline database and matching media must exist')
    if a.output.exists(): p.error('output must be a new directory')
    names={k:a.db_prefix+'_'+k for k in ('a_small','a_large','b_empty','b_small','b_large')}
    k=['kubectl','--context='+a.context,'-n',a.namespace]
    root=k+['exec','mariadb-0','--','sh','-c','MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h 127.0.0.1 -u root -e "$1"','sh']
    check='SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('+','.join("'"+n+"'" for n in names.values())+')'
    existing=subprocess.run(root+[check],capture_output=True,text=True,check=True).stdout.strip()
    if existing: p.error('one or more requested scratch databases already exist')
    sql="; ".join('CREATE DATABASE `'+db+'`; GRANT ALL ON `'+db+'`.* TO \'bagisto\'@\'%\'' for db in names.values())
    # CREATE DATABASE without IF NOT EXISTS fails closed on an existing target.
    subprocess.run(root+[sql],check=True)
    for db in names.values():
        print('Importing default baseline into',db,flush=True)
        with a.baseline_sql.open('rb') as stream:
            subprocess.run(k+['exec','-i','mariadb-0','--','sh','-c','MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" "$1"','sh',db],stdin=stream,check=True)
    common=['--context',a.context,'--namespace',a.namespace]
    def call(script,args): subprocess.run([sys.executable,str(HERE/script),*args],check=True)
    for kind,customers,orders in [('a_small',a.small_customers,a.small_orders),('a_large',a.large_customers,a.large_orders),('b_empty',0,0),('b_small',0,0),('b_large',0,0)]:
        call('seed_default.py',common+['--database',names[kind],'--customers',str(customers),'--orders',str(orders),'--apply'])
    for kind in ('a_small','a_large'):
        call('invoice_default.py',common+['--database',names[kind],'--percent','35','--apply'])
    for dest,src in [('b_small','a_small'),('b_large','a_large')]:
        call('copy_customers.py',common+['--source',names[src],'--destination',names[dest],'--apply'])
    for kind,db in names.items():
        call('package_default.py',common+['--database',db,'--media',str(a.baseline_media),'--output',str(a.output/kind),'--writes-paused','--compress','--pod-compress'])
    print('Bundles ready in',a.output)
if __name__=='__main__': main()
