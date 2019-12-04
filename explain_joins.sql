CREATE TABLE customers
(
  cust_id      int       NOT NULL AUTO_INCREMENT,
  cust_name    char(50)  NOT NULL DEFAULT '',
  PRIMARY KEY (cust_id)
) ENGINE=InnoDB;

CREATE TABLE orders
(
  order_id   int      NOT NULL AUTO_INCREMENT,
  cust_id    int      NOT NULL ,
  PRIMARY KEY (order_id)
) ENGINE=InnoDB;

INSERT INTO customers(cust_id, cust_name)
VALUES(10001, 'Paladin');
INSERT INTO customers(cust_id, cust_name)
VALUES(10002, 'Warlock');
INSERT INTO customers(cust_id, cust_name)
VALUES(10003, 'Priest');
INSERT INTO customers(cust_id, cust_name)
VALUES(10004, 'Mage');
INSERT INTO customers(cust_id, cust_name)
VALUES(10005, 'Warrior');

INSERT INTO orders(order_id, cust_id)
VALUES(20001, 10001);
INSERT INTO orders(order_id, cust_id)
VALUES(20002, 10005);
INSERT INTO orders(order_id, cust_id)
VALUES(20003, 10004);
INSERT INTO orders(order_id, cust_id)
VALUES(20004, 10005);
INSERT INTO orders(order_id, cust_id)
VALUES(20005, 10001);
INSERT INTO orders(order_id, cust_id)
VALUES(20006, 10005);
