#!/usr/bin/env python3
"""Compare selected Bagisto tables by ordered full-row SHA-256 digests."""
import argparse
import hashlib
import subprocess

TABLES=('customers','orders','order_items','order_payment','addresses','product_inventories','product_inventory_indices','product_ordered_inventories')

def digest(context, namespace, table):
    query=f'SELECT * FROM {table} ORDER BY id'
    k=['kubectl','--context='+context,'-n',namespace,'exec','mariadb-0','--','sh','-c',
       'MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" "$MARIADB_DATABASE" --batch --raw --skip-column-names -e "$1"','sh',query]
    proc=subprocess.Popen(k,stdout=subprocess.PIPE)
    h=hashlib.sha256()
    for chunk in iter(lambda:proc.stdout.read(1024*1024),b''): h.update(chunk)
    proc.stdout.close()
    if proc.wait()!=0: raise RuntimeError(f'Query failed for {namespace}/{table}')
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context',default='minikube');p.add_argument('--source',default='store-a');p.add_argument('--target',default='store-b')
    a=p.parse_args(); failed=[]
    for table in TABLES:
        source=digest(a.context,a.source,table); target=digest(a.context,a.target,table)
        print(f'{table}: {"MATCH" if source==target else "DIFFER"} A={source} B={target}',flush=True)
        if source!=target: failed.append(table)
    if failed: raise SystemExit('Differences: '+', '.join(failed))
    print('Selected table digests match. This does not prove cutover, complete application state, or payment correctness.')
if __name__=='__main__': main()
