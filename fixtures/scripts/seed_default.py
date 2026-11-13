#!/usr/bin/env python3
"""Populate an empty Bagisto demo database with reproducible synthetic history."""
import argparse
import datetime as dt
import random
import re
import subprocess
import sys

FIRST = [('Aisha','female'),('Amara','female'),('Ana','female'),('Chen','female'),('Fatima','female'),('Grace','female'),('Hana','female'),('Isabella','female'),('Leila','female'),('Maya','female'),('Mei','female'),('Nadia','female'),('Sofia','female'),('Yuna','female'),('Ahmed','male'),('Carlos','male'),('David','male'),('Emmanuel','male'),('Hiro','male'),('Ibrahim','male'),('James','male'),('Kenji','male'),('Liam','male'),('Mateo','male'),('Mohammed','male'),('Noah','male'),('Omar','male'),('Ravi','male')]
LAST = ['Silva','Garcia','Kim','Ali','Chen','Patel','Khan','Ivanov','Muller','Dubois','Sato','Okafor','Smith','Mensah','Hassan','Lopez','Costa','Singh','Rossi','Nguyen']
PLACES = [('DE','Berlin','10115'),('FR','Paris','75001'),('NL','Amsterdam','1012 AB'),('ES','Madrid','28001'),('GB','London','SW1A 1AA'),('US','New York','10001'),('CA','Toronto','M5V 2T6'),('BR','Sao Paulo','01000-000'),('MX','Mexico City','06000'),('NG','Lagos','100001'),('ZA','Cape Town','8001'),('EG','Cairo','11511'),('KE','Nairobi','00100'),('IN','Mumbai','400001'),('JP','Tokyo','100-0001'),('SG','Singapore','018956'),('AU','Sydney','2000'),('NZ','Auckland','1010'),('AE','Dubai','00000'),('KR','Seoul','04524')]

def sqlstr(value):
    if value is None: return 'NULL'
    return "'" + str(value).replace('\\', '\\\\').replace("'", "''").replace('\n', ' ').replace('\r', ' ') + "'"

def nonnegative(s):
    n = int(s)
    if n < 0: raise argparse.ArgumentTypeError('must be non-negative')
    return n

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context', required=True); p.add_argument('--namespace', required=True)
    p.add_argument('--database', required=True); p.add_argument('--customers', type=nonnegative, required=True)
    p.add_argument('--orders', type=nonnegative, required=True); p.add_argument('--seed', type=int, default=42)
    p.add_argument('--apply', action='store_true'); a = p.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_]+', a.database): p.error('invalid database name')
    if a.orders and not a.customers: p.error('orders require customers')
    if not a.apply: p.error('pass --apply after selecting an empty demo database')
    k=['kubectl','--context='+a.context,'-n',a.namespace,'exec','mariadb-0','--']
    shell='MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" --batch --raw --skip-column-names "$1"'
    def read(q):
        return subprocess.run(k+['sh','-c',shell+' -e "$2"','sh',a.database,q],capture_output=True,text=True,check=True).stdout
    if read('SELECT (SELECT COUNT(*) FROM customers)+(SELECT COUNT(*) FROM orders)+(SELECT COUNT(*) FROM addresses)').strip() != '0':
        raise RuntimeError('target customer, order and address tables must be empty')
    products=[]
    for line in read("SELECT p.id,p.sku,f.name,f.price FROM products p JOIN product_flat f ON p.id=f.product_id WHERE p.type='simple' AND p.parent_id IS NULL AND f.status=1 AND f.price>0 AND f.visible_individually=1 AND f.channel='default' AND f.locale='en' ORDER BY p.id").splitlines():
        fields=line.split('\t')
        if len(fields)!=4: raise RuntimeError('unexpected product data')
        products.append((int(fields[0]),fields[1],fields[2],fields[3]))
    if not products: raise RuntimeError('no compatible default simple products')
    password=subprocess.run(['kubectl','--context='+a.context,'-n',a.namespace,'exec','deploy/bagisto','-c','bagisto','--','php','-r','echo password_hash("admin123", PASSWORD_BCRYPT);'],capture_output=True,text=True,check=True).stdout
    rng=random.Random(a.seed); ts=dt.datetime(2026,1,1); seconds=300*86400
    proc=subprocess.Popen(['kubectl','--context='+a.context,'-n',a.namespace,'exec','-i','mariadb-0','--','sh','-c',shell,'sh',a.database],stdin=subprocess.PIPE,text=True)
    def batches(table,columns,rows):
        batch=[]; done=0
        for row in rows:
            batch.append('('+','.join(sqlstr(v) for v in row)+')')
            if len(batch)==500:
                proc.stdin.write('INSERT INTO `'+table+'` ('+','.join('`'+c+'`' for c in columns)+') VALUES '+','.join(batch)+';\n'); done+=len(batch); batch=[]
                if done%100000==0: print(f'{table}: {done}',file=sys.stderr,flush=True)
        if batch: proc.stdin.write('INSERT INTO `'+table+'` ('+','.join('`'+c+'`' for c in columns)+') VALUES '+','.join(batch)+';\n')
    def customer(i):
        first,gender=FIRST[(i*17+a.seed)%len(FIRST)]; last=LAST[(i*13+a.seed)%len(LAST)]
        country,city,postcode=PLACES[(i*7+a.seed)%len(PLACES)]
        return first,last,gender,country,city,postcode,f'customer-{i:07d}@example.com'
    try:
        proc.stdin.write('SET NAMES utf8mb4; SET time_zone=\'+00:00\';\n')
        # EUR was chosen for the demo. Default catalog prices are interpreted as EUR, not exchanged.
        proc.stdin.write("INSERT INTO currencies (code,name,symbol,`decimal`,group_separator,decimal_separator,currency_position) SELECT 'EUR','Euro','€',2,',','.','left' WHERE NOT EXISTS (SELECT 1 FROM currencies WHERE code='EUR'); SET @eur=(SELECT id FROM currencies WHERE code='EUR' LIMIT 1); INSERT IGNORE INTO channel_currencies(channel_id,currency_id) VALUES(1,@eur); UPDATE channels SET base_currency_id=@eur WHERE id=1;\n")
        ids=','.join(str(x[0]) for x in products)
        proc.stdin.write(f'UPDATE product_inventories SET qty=10000000 WHERE inventory_source_id=1 AND vendor_id=0 AND product_id IN ({ids});\n')
        proc.stdin.write(f'UPDATE product_inventory_indices SET qty=10000000 WHERE channel_id=1 AND product_id IN ({ids});\n')
        batches('customers',['id','first_name','last_name','gender','email','password','customer_group_id','channel_id','is_verified','created_at','updated_at'],
            ((i,*customer(i)[:3],customer(i)[6],password,2,1,1,'2025-01-01 00:00:00','2025-01-01 00:00:00') for i in range(1,a.customers+1)))
        batches('addresses',['id','address_type','customer_id','first_name','last_name','gender','address','city','country','postcode','email','default_address','created_at','updated_at'],
            ((i,'customer',i,customer(i)[0],customer(i)[1],customer(i)[2],f'{i} Example Street',customer(i)[4],customer(i)[3],customer(i)[5],customer(i)[6],1,'2025-01-01 00:00:00','2025-01-01 00:00:00') for i in range(1,a.customers+1)))
        # A seeded pseudorandom sequence is regenerated independently per table.
        def order_data():
            r=random.Random(a.seed)
            for i in range(1,a.orders+1):
                cid=r.randrange(1,a.customers+1); product=products[r.randrange(len(products))]; qty=r.randrange(1,4)
                date=(ts+dt.timedelta(seconds=r.randrange(seconds))).strftime('%Y-%m-%d %H:%M:%S')
                yield i,cid,product,qty,date
        from decimal import Decimal
        def total(product,qty): return str(Decimal(product[3])*qty)
        def orderrows():
            for i,c,pd,q,d in order_data():
                cdata=customer(c); amt=total(pd,q)
                yield (i,str(i),'pending','Default',0,cdata[6],cdata[0],cdata[1],'free_free','Free Shipping - Free Shipping',1,q,'EUR','EUR','EUR',amt,amt,amt,amt,amt,amt,c,'Webkul\\Customer\\Models\\Customer',1,'Webkul\\Core\\Models\\Channel',d,d)
        batches('orders',['id','increment_id','status','channel_name','is_guest','customer_email','customer_first_name','customer_last_name','shipping_method','shipping_title','total_item_count','total_qty_ordered','base_currency_code','channel_currency_code','order_currency_code','grand_total','base_grand_total','sub_total','base_sub_total','sub_total_incl_tax','base_sub_total_incl_tax','customer_id','customer_type','channel_id','channel_type','created_at','updated_at'],orderrows())
        def itemrows():
            for i,c,pd,q,d in order_data():
                amt=total(pd,q); yield (i,pd[1],'simple',pd[2],q,pd[3],pd[3],amt,amt,pd[3],pd[3],amt,amt,pd[0],'Webkul\\Product\\Models\\Product',i,'{}',d,d)
        batches('order_items',['id','sku','type','name','qty_ordered','price','base_price','total','base_total','price_incl_tax','base_price_incl_tax','total_incl_tax','base_total_incl_tax','product_id','product_type','order_id','additional','created_at','updated_at'],itemrows())
        batches('order_payment',['id','order_id','method','method_title','created_at','updated_at'],((i,i,'moneytransfer','Money Transfer',d,d) for i,c,pd,q,d in order_data()))
        def addresses():
            for i,c,pd,q,d in order_data():
                first,last,gender,country,city,postcode,email=customer(c)
                for j,kind in enumerate(('order_shipping','order_billing')):
                    yield (a.customers+2*(i-1)+j+1,kind,i,first,last,gender,f'{c} Example Street',city,country,postcode,email,d,d)
        batches('addresses',['id','address_type','order_id','first_name','last_name','gender','address','city','country','postcode','email','created_at','updated_at'],addresses())
        proc.stdin.write('INSERT INTO product_ordered_inventories(qty,product_id,channel_id) SELECT SUM(qty_ordered),product_id,1 FROM order_items GROUP BY product_id;\n')
        proc.stdin.write('UPDATE product_inventory_indices i JOIN product_ordered_inventories o ON o.product_id=i.product_id AND o.channel_id=i.channel_id SET i.qty=i.qty-o.qty;\n')
        proc.stdin.close(); rc=proc.wait()
        if rc: raise RuntimeError(f'database import failed with exit code {rc}; target may be partial')
    except BaseException:
        if proc.stdin and not proc.stdin.closed: proc.stdin.close()
        proc.wait(); raise
    print(f'Seeded {a.customers} customers and {a.orders} pending orders using {len(products)} default products. Demo customer password: admin123')

if __name__=='__main__': main()
