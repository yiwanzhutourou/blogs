# MySQL 中的各种 JOIN

本文主要介绍 SQL 标准中定义的各种连接的意义和区别，例如，交叉连接（`CROSS JOIN`）、内连接（`INNER JOIN`）、外连接（`OUTER JOIN`）、自然连接（`NATURAL JOIN`）等，并结合例子讲解这些连接在 MySQL 中的语法和表现。

**从网上的资料看， `JOIN` 更多翻译为连接，本文中凡是出现中文“连接”的地方都是指 `JOIN`。**

## 例子中用到的表

本文中用到的所有例子涉及两张表—— `customers` 用户表和 `orders` 订单表，其中订单表中的 `cust_id` 字段表示用户的唯一 ID，也就是用户表的主键 `cust_id`。两张表的数据如下：

```shell
mysql> select * from customers;
+---------+-----------+
| cust_id | cust_name |
+---------+-----------+
|   10001 | Paladin   |
|   10002 | Warlock   |
|   10003 | Priest    |
|   10004 | Mage      |
|   10005 | Warrior   |
+---------+-----------+
5 rows in set (0.00 sec)
```

```shell
mysql> select * from orders;
+----------+---------+
| order_id | cust_id |
+----------+---------+
|    20001 |   10001 |
|    20002 |   10005 |
|    20003 |   10004 |
|    20004 |   10005 |
|    20005 |   10001 |
|    20006 |   10005 |
+----------+---------+
6 rows in set (0.00 sec)
```

**注：两张表都经过了简化，实际业务中这两张表肯定还包括其他字段。**

## 连接的定义

[英文维基百科 `JOIN` 词条]()对连接的定义如下：

> A `JOIN` is a means for combining columns from one (self-join) or more tables by using values common to each. ANSI-standard SQL specifies five types of `JOIN`: `INNER`, `LEFT OUTER`, `RIGHT OUTER`, `FULL OUTER` and `CROSS`.

翻译过来就是，“连接可以根据一张（自连接）或多张表中的共同值将这些表的列数据合并为一个新的结果集，标准 SQL 定义了五种连接：内连接、左外连接、右外连接、全外连接和交叉连接。”

也就是说，连接是 SQL 标准中定义的一种组合多张表的方式，当然一张表自身也可以和自身组合，称为自连接。连接后得到的结果集的每一列其实都来自用于连接的多张表，不同的连接类型只是区分了这些列具体从哪张表里来，列里填充的是什么数据。

其实英文维基百科的 `JOIN` 词条已经把各种连接的类型解释地非常清楚了，非常值得去看一下。

## SQL 标准定义的连接

我们来看一下 SQL 标准中定义的各种连接类型，理解各种连接最好的方法就是把需要连接的表想象成集合，并画出可以反映集合的交与并的情况的图——韦恩图，例如下图就画出了 SQL 中定义的几种主要连接。

![SQL 标准定义的主要连接](https://youdu-markdown.oss-cn-shanghai.aliyuncs.com/20191113150203.jpg)

<center>SQL 标准定义的主要连接</center>

请先仔细查看一下图中的内容，你可以从中归纳出几种连接类型呢？

虽然图中画了 7 种集合的交并情况，但是总结起来，主要是两种连接类型在起作用——内连接（`INNER JOIN`）和外连接（`OUTER JOIN`），其中外连接又分为了左外连接（`LEFT OUTER JOIN`）、右外连接（`RIGHT OUTER JOIN`）和全外连接（`FULL OUTER JOIN`）。

下面先简单介绍一下 SQL 标准中各种连接的定义，然后在「MySQL 中的连接」一节再用例子来演示 MySQL 中支持的各种连接。

### 内连接（`INNER JOIN`）和外连接（`OUTER JOIN`）

连接既然是用来合并多张表的，那么要定义一个连接就必须指定需要连接的表，并指定可选的连接条件。例如，一个典型的 SQL 连接语句如下：

```sql
SELECT <select_list>
FROM TableA A INNER JOIN TableB B
ON A.Key = B.Key
```

我们用表 A 和表 B 指代需要连接的两张表，经过**内连接**后得到的结果集**仅**包含所有满足**连接条件**的数据；而经过**外连接**后得到的数据集**不仅**包含满足**连接条件**的数据，还包含其他数据，具体的差别是：

- 左外连接还包括表 A 中不满足连接条件的所有行，对应的表 B 中的列数据用 `NULL` 填充。
- 右外连接还包括表 B 中不满足连接条件的所有行，对应的表 A 中的列数据用 `NULL` 填充。
- 全外连接还包括表 A 和表 B 中不满足连接条件的所有行，对应的另一张表中的列数据用 `NULL` 填充。

### 交叉连接（`CROSS JOIN`）

在上面「SQL 标准定义的主要连接」一图中并没有列出交叉连接，交叉连接会对连接的两张表做笛卡尔积，也就是连接后的数据集中的行是由第一张表中的每一行与第二张表中的每一行配对而成的，而不管它们**逻辑上**是否可以搭配在一起。假设交叉连接的两张表分别有 m 和 n 行数据，那么交叉连接后的数据集就包含 m 乘以 n 行数据。

### 等值连接（Equi-Join）

连接根据连接的条件不同，又可以区分为等值连接和非等值连接，「SQL 标准定义的主要连接」图中画出的连接的连接条件都是比较两个字段是否相等，它们都是等值连接。

### 自然连接（`NATURAL JOIN`）

自然连接是等值连接的一种特殊形式，自然连接会自动选取需要连接的两张表中字段名相同的**所有**列做相等比较，而不需要再指定连接条件了。

## MySQL 中的连接

**注：以下内容全部基于 MySQL 5.7 版本，所有例子只保证在 MySQL 5.7 上是可以正确执行的。**

MySQL 中支持的连接类型和关键字如下：

- `[INNER|CROSS] JOIN`
- `{LEFT|RIGHT} [OUTER] JOIN`
- `NATURAL [{LEFT|RIGHT} [OUTER]] JOIN`
- `STRAIGHT_JOIN`

上面的表示方法摘自 MySQL 5.7 版本[官方文档](<https://dev.mysql.com/doc/refman/8.0/en/join.html>)，其中 `|` 表示两者皆可出现，`[]` 表示的是可选的，`{}` 表示的是必选的，例如 `NATURAL LEFT JOIN` 和 `NATURAL JOIN` 都是合法的。

可以看到，除了全外连接（`FULL OUTER JOIN`）以外， MySQL 基本支持了 SQL 标准中定义的各种连接。在 MySQL 中全外连接可以通过 `UNION` 合并的方式做到，当然前提是你知道自己为什么需要这么做，具体参见：[Full Out Join in MySQL](<http://www.it-iss.com/mysql/mysql-full-outer-join/>)。

MySQL 语法中还支持一个并不在 SQL 标准中的 `STRAIGHT_JOIN`，它在**表现上**和内连接或者交叉连接并无区别，只是一种给 MySQL 优化器的一个提示，`STRAIGHT_JOIN` 提示 MySQL 按照语句中表的顺序加载表，只有在你明确清楚 MySQL 服务器对你的 `JOIN` 语句做了负优化的时候才可能用到它。

还有一点需要说明的是，根据[官方文档](<https://dev.mysql.com/doc/refman/5.7/en/join.html>)，在 MySQL 中，`JOIN`、`CROSS JOIN` 和 `INNER JOIN` 实现的功能是一致的，它们在语法上是等价的。从语义上来说，`CROSS JOIN` 特指无条件的连接（没有指定 `ON` 条件的 `JOIN` 或者没有指定 `WHERE` 连接条件的多表 `SELECT`），`INNER JOIN` 特指有条件的连接（指定了 `ON` 条件的 `JOIN` 或者指定了 `WHERE` 连接条件的多表 `SELECT`）。当然，如果你非要写 `... CROSS JOIN ... ON ...` 这样的语法，也是可以执行的，虽然写着交叉连接，实际上执行的是内连接。

下面我们就用例子来看一看 MySQL 中支持的几种连接的例子。

**注：下面的例子都没有指定 `ORDER BY` 子句，返回结果的顺序可能会因为数据插入顺序的不同而略有不同。**

### `[INNER|CROSS] JOIN`

MySQL 的交叉连接或内连接有两种写法，一种是使用 `JOIN` 并用 `ON` 或者 `USING`子句指定连接条件的写法，一种是普通的 `SELECT` 多表，并且用 `WHERE` 子句指定连接的键的写法。

下面的例子是一个交叉连接：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers, orders;
```

上面的写法等价于：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers CROSS JOIN orders;
```

当然，第二种写法中如果将 `CROSS JOIN` 替换成 `JOIN` 或者 `INNER JOIN` 也是可以正确执行的。上面两条语句的执行结果如下：

```shell
mysql> SELECT customers.cust_id, customers.cust_name, orders.order_id
    -> FROM customers CROSS JOIN orders;
+---------+-----------+----------+
| cust_id | cust_name | order_id |
+---------+-----------+----------+
|   10001 | Paladin   |    20001 |
|   10002 | Warlock   |    20001 |
|   10003 | Priest    |    20001 |
|   10004 | Mage      |    20001 |
|   10005 | Warrior   |    20001 |
|   10001 | Paladin   |    20002 |
|   10002 | Warlock   |    20002 |
|   10003 | Priest    |    20002 |
|   10004 | Mage      |    20002 |
|   10005 | Warrior   |    20002 |
|   10001 | Paladin   |    20003 |
|   10002 | Warlock   |    20003 |
|   10003 | Priest    |    20003 |
|   10004 | Mage      |    20003 |
|   10005 | Warrior   |    20003 |
|   10001 | Paladin   |    20004 |
|   10002 | Warlock   |    20004 |
|   10003 | Priest    |    20004 |
|   10004 | Mage      |    20004 |
|   10005 | Warrior   |    20004 |
|   10001 | Paladin   |    20005 |
|   10002 | Warlock   |    20005 |
|   10003 | Priest    |    20005 |
|   10004 | Mage      |    20005 |
|   10005 | Warrior   |    20005 |
|   10001 | Paladin   |    20006 |
|   10002 | Warlock   |    20006 |
|   10003 | Priest    |    20006 |
|   10004 | Mage      |    20006 |
|   10005 | Warrior   |    20006 |
+---------+-----------+----------+
30 rows in set (0.00 sec)
```

可以看到共返回了 30 行结果，是两张表的笛卡尔积。

一个内连接的例子如下：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers, orders
WHERE customers.cust_id = orders.cust_id;
```

上面的写法等价于：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers CROSS JOIN orders
ON customers.cust_id = orders.cust_id;
```

在连接条件比较的字段相同的情况下，还可以改用 `USING` 关键字，上面的写法等价于：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers CROSS JOIN orders
USING(cust_id);
```

上面三条语句的返回结果如下：

```shell
mysql> SELECT customers.cust_id, customers.cust_name, orders.order_id
    -> FROM customers CROSS JOIN orders
    -> ON customers.cust_id = orders.cust_id;
+---------+-----------+----------+
| cust_id | cust_name | order_id |
+---------+-----------+----------+
|   10001 | Paladin   |    20001 |
|   10005 | Warrior   |    20002 |
|   10004 | Mage      |    20003 |
|   10005 | Warrior   |    20004 |
|   10001 | Paladin   |    20005 |
|   10005 | Warrior   |    20006 |
+---------+-----------+----------+
6 rows in set (0.00 sec)
```

可以看到只返回了符合连接条件 `customers.cust_id = orders.cust_id` 的 6 行结果，结果的含义是所有有订单的用户和他们的订单。

### `{LEFT|RIGHT} [OUTER] JOIN`

左外连接和右外连接的例子如下，其中的 `OUTER` 关键字可以省略：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers LEFT OUTER JOIN orders
ON customers.cust_id = orders.cust_id;
```

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers RIGHT OUTER JOIN orders
ON customers.cust_id = orders.cust_id;
```

其中右外连接的返回与内连接的返回是一致的（思考一下为什么），左外连接的返回结果如下：

```shell
mysql> SELECT customers.cust_id, customers.cust_name, orders.order_id
    -> FROM customers LEFT OUTER JOIN orders
    -> ON customers.cust_id = orders.cust_id;
+---------+-----------+----------+
| cust_id | cust_name | order_id |
+---------+-----------+----------+
|   10001 | Paladin   |    20001 |
|   10005 | Warrior   |    20002 |
|   10004 | Mage      |    20003 |
|   10005 | Warrior   |    20004 |
|   10001 | Paladin   |    20005 |
|   10005 | Warrior   |    20006 |
|   10002 | Warlock   |     NULL |
|   10003 | Priest    |     NULL |
+---------+-----------+----------+
8 rows in set (0.00 sec)
```

可以看到一共返回了 8 行数据，其中最后两行数据对应的 `order_id` 的值为 `NULL`，结果的含义是所有用户的订单，不管这些用户是否已经有订单存在了。

### `NATURAL [{LEFT|RIGHT} [OUTER]] JOIN`

根据前面介绍的自然连接的定义，自然连接会自动用参与连接的两张表中**字段名相同**的列做等值比较，由于例子中的 `customers` 和 `orders` 表只有一列名称相同，我们可以用自然连接的语法写一个与上面的内连接的例子表现行为一样的语句如下：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers NATURAL JOIN orders;
```

可以看到，使用自然连接就不能再用 `ON` 子句指定连接条件了，因为这完全是多余的。

当然，自然连接同样支持左外连接和右外连接。

下面用一个 `customers` 表自连接的例子再来说明一下自然连接，语句如下：

```sql
SELECT cust_id, cust_name
FROM customers AS c1 NATURAL JOIN customers AS c2;
```

因为是自连接，因此必须使用 `AS` 指定别名，否则 MySQL 无法区分“两个” `customers` 表，运行的结果如下：

```shell
mysql> SELECT cust_id, cust_name
    -> FROM customers AS c1 NATURAL JOIN customers AS c2;
+---------+-----------+
| cust_id | cust_name |
+---------+-----------+
|   10001 | Paladin   |
|   10002 | Warlock   |
|   10003 | Priest    |
|   10004 | Mage      |
|   10005 | Warrior   |
+---------+-----------+
5 rows in set (0.00 sec)
```

可以看到结果集和 `customers` 表完全一致，大家可以思考一下为什么结果是这样的。

### `STRAIGHT_JOIN`

文章之前也提到了，MySQL 还支持一种 SQL 标准中没有定义的“方言”，`STRAIGHT_JOIN`，`STRAIGHT_JOIN` 支持带 `ON` 子句的内连接和不带 `ON` 子句的交叉连接，我们来看一个 `STRAIGHT_JOIN` 版本的内连接的例子：

```sql
SELECT customers.cust_id, customers.cust_name, orders.order_id
FROM customers STRAIGHT_JOIN orders
ON customers.cust_id = orders.cust_id;
```

返回结果与前面内连接的例子是一致的，如下：

```shell
mysql> SELECT customers.cust_id, customers.cust_name, orders.order_id
    -> FROM customers STRAIGHT_JOIN orders
    -> ON customers.cust_id = orders.cust_id;
+---------+-----------+----------+
| cust_id | cust_name | order_id |
+---------+-----------+----------+
|   10001 | Paladin   |    20001 |
|   10005 | Warrior   |    20002 |
|   10004 | Mage      |    20003 |
|   10005 | Warrior   |    20004 |
|   10001 | Paladin   |    20005 |
|   10005 | Warrior   |    20006 |
+---------+-----------+----------+
6 rows in set (0.00 sec)
```

`STRAIGHT_JOIN` 的表现和 `JOIN` 是完全一致的，它只是一种给 MySQL 优化器的提示，使得 MySQL 始终按照语句中表的顺序读取表（上面的例子中，MySQL 在执行时一定会先读取 `customers` 表，再读取 `orders` 表），而不会做改变读取表的顺序的优化。关于 MySQL 优化器的话题这里不做展开，需要说明的是除非你非常清楚你在做什么，否则不推荐直接使用 `STRAIGHT_JOIN`。

### 一个奇怪的非等值连接的例子

```sql
SELECT customers.cust_id, customers.cust_name, orders.cust_id, orders.order_id
FROM customers JOIN orders
ON customers.cust_id < orders.cust_id;
```

你能理解上面的语句是在检索什么数据吗？

## 总结

本文主要介绍了 SQL 标准里定义的各种连接的概念，以及 MySQL 中的实现，并通过各种例子来介绍了这些连接的区别。这些连接不一定都能在实际开发中用到，但是做到心中有知识也还是很有必要的。

那么，现在再回忆一下，什么是内连接、外连接、自连接、等值连接和自然连接？他们的区别是什么？

最后，给大家留一个思考题，为什么 MySQL 中没有左外连接或者右外连接版本的 `STRAIGHT_JOIN`？

## 参考资料

1. 《MySQL 必知必会》，Ben Forta 著，人民邮电出版社 2009 年 1 月第 1 版
2. [MySQL 5.7 版本官方文档](<https://dev.mysql.com/doc/refman/5.7/en/>)
3. [图解 SQL 里的各种 JOIN](<https://zhuanlan.zhihu.com/p/29234064>)
4. stackoverflow [Full Out Join in MySQL](<http://www.it-iss.com/mysql/mysql-full-outer-join/>)
5. [维基百科 `JOIN` 词条]()