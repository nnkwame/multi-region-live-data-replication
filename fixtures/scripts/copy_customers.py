#!/usr/bin/env python3
"""Copy customer accounts and saved addresses into an empty destination fixture DB."""
import argparse
import re
import subprocess

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context',required=True); p.add_argument('--namespace',required=True)
    p.add_argument('--source',required=True); p.add_argument('--destination',required=True); p.add_argument('--apply',action='store_true')
    a=p.parse_args()
    if not a.apply: p.error('pass --apply after checking the source and empty destination')
    if not all(re.fullmatch(r'[A-Za-z0-9_]+',v) for v in (a.source,a.destination)) or a.source==a.destination: p.error('use distinct valid database names')
    k=['kubectl','--context='+a.context,'-n',a.namespace,'exec','mariadb-0','--','sh','-c']
    command='MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" --batch --skip-column-names "$1" -e "$2"'
    def sql(db,q): return subprocess.run(k+[command,'sh',db,q],capture_output=True,text=True,check=True).stdout
    if sql(a.destination,'SELECT (SELECT COUNT(*) FROM customers)+(SELECT COUNT(*) FROM addresses)+(SELECT COUNT(*) FROM orders)').strip()!='0': raise RuntimeError('destination must have no customers, addresses or orders')
    sql(a.destination,f"INSERT INTO customers SELECT * FROM `{a.source}`.customers; INSERT INTO addresses SELECT * FROM `{a.source}`.addresses WHERE address_type='customer';")
    print('Copied customers and their saved addresses; no orders copied.')
if __name__=='__main__': main()
