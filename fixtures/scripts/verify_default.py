#!/usr/bin/env python3
"""Check synthetic Bagisto fixture counts, relationships and inventory."""
import argparse
import re
import subprocess


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--context',required=True); p.add_argument('--namespace',required=True); p.add_argument('--database',default='bagisto')
    p.add_argument('--customers',required=True,type=int); p.add_argument('--orders',required=True,type=int)
    a=p.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_]+',a.database) or min(a.customers,a.orders)<0: p.error('invalid arguments')
    q="""SELECT
      (SELECT COUNT(*) FROM customers),
      (SELECT COUNT(*) FROM orders),
      (SELECT COUNT(*) FROM order_items),
      (SELECT COUNT(*) FROM order_payment),
      (SELECT COUNT(*) FROM addresses WHERE address_type='customer'),
      (SELECT COUNT(*) FROM addresses WHERE address_type='order_billing'),
      (SELECT COUNT(*) FROM addresses WHERE address_type='order_shipping'),
      (SELECT COUNT(*) FROM orders o LEFT JOIN customers c ON c.id=o.customer_id WHERE c.id IS NULL),
      (SELECT COUNT(*) FROM order_items i LEFT JOIN orders o ON o.id=i.order_id LEFT JOIN products p ON p.id=i.product_id AND p.sku=i.sku WHERE o.id IS NULL OR p.id IS NULL OR i.total<>o.grand_total OR i.qty_ordered<>o.total_qty_ordered),
      (SELECT COUNT(*) FROM order_items WHERE LEFT(sku,3)=CHAR(69,78,45)),
      (SELECT COUNT(*) FROM products WHERE LEFT(sku,3)=CHAR(69,78,45)),
      (SELECT COUNT(*) FROM product_ordered_inventories r LEFT JOIN product_inventory_indices i ON i.product_id=r.product_id AND i.channel_id=r.channel_id LEFT JOIN product_inventories s ON s.product_id=r.product_id AND s.inventory_source_id=1 AND s.vendor_id=0 WHERE i.qty<>s.qty-r.qty OR i.id IS NULL OR s.id IS NULL)
    """
    cmd=['kubectl','--context='+a.context,'-n',a.namespace,'exec','mariadb-0','--','sh','-c','MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" --batch --skip-column-names "$1" -e "$2"','sh',a.database,q]
    values=[int(v) for v in subprocess.run(cmd,capture_output=True,text=True,check=True).stdout.split()]
    expected=[a.customers,a.orders,a.orders,a.orders,a.customers,a.orders,a.orders,0,0,0,0,0]
    names=['customers','orders','order_items','payments','customer_addresses','billing_addresses','shipping_addresses','missing_customers','bad_order_items','custom_order_items','custom_products','bad_inventory_indices']
    for name,value,want in zip(names,values,expected): print(f'{name}: {value} (expected {want})')
    if values!=expected: raise SystemExit('Fixture verification failed')
    print('Fixture checks passed. They do not prove CDC, exactly-once processing or live checkout.')
if __name__=='__main__': main()
