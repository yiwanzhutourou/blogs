# 如何用 RabbitMQ 实现延时队列

本人所在的公司在生产中使用 RabbitMQ 作为消息中间件，并在业务中用到了 RabbitMQ 的延时队列功能。RabbitMQ 原生并不直接支持消息的延时发送，但是通过安装插件就可以做到这一点。RabbitMQ 可以方便集成到 Spring 框架中，利用插件，也可以很方便地使用延时队列，实现延时处理某些业务逻辑的功能。因为配置和使用简单，在保证生产环境中不会有巨大量的消息积压的情况下，还是有一定的适用场景的。

当然，RabbitMQ 的这个插件虽然是官方插件，但是并不在团队的主要维护列表上，虽然官方说明这个插件有稳定运行的能力，但是仍有诸多缺点。例如，延时消息不能积压到百万级别以上，否则就会出现性能问题；另外，延时消息虽然会被持久化，但是数据库是单点的，在分布式系统中，单点总是不好的。

## 内容简介

本文首先介绍消息队列以及 RabbitMQ 中的一些基础概念，然后介绍两种可以通过 RabbitMQ 实现延时队列的方案。延时队列是指，消息在发布到队列后不立即被消费，而是经过一个固定的时间后再被发送给消费者消费。

需要特别指出的是，本文会特别注明这两种实现延时队列的方案的限制和不足，且本文中提供的方案应该作为一种思路被看待，类似“延时队列”的实现也可以通过其他中间件完成，例如 redis，或者甚至通过数据库加定时任务来实现，一切技术方案都有其适用场景、优势和劣势，需要根据实际情况做取舍。

## 基础知识

首先来复习一下消息队列以及 RabbitMQ 相关的基础知识，如果你对这部分内容已经很熟悉了，可以直接跳到“用 RabbitMQ 实现延迟队列的两种方案”一节继续阅读。

### 消息队列核心角色

![消息生产和消费流程](https://www.rabbitmq.com/img/tutorials/intro/hello-world-example-routing.png)

- publisher / producer：消息生产者
- broker：消息队列服务器实体
  - exchange：消息交换机，指定消息按什么规则路由到哪个队列（航空公司）
  - binding：exchange 和 queue 按照路由规则绑定起来（航线）
  - routing key：binding 的属性，某些 exchange 类型下的消息路由的规则
  - queue：队列是消息的载体，每条消息都会被投入到一个或多个队列（目的地）
- consumer：消息消费者

生产者不直接把消息发送给消费者，而是发送给 exchange，达到生产者和消费者的解耦。

### RabbitMQ 中主要的 exchange 类型

#### 1. fanout

忽略 routing key，消息会被发送到所有绑定到该 exchange 的所有队列。

![fanout exchange](https://www.rabbitmq.com/img/tutorials/python-three-overall.png)

#### 2. direct

消息会被发送到绑定到该 exchange 且 routing key 与其一致的队列。

![direct exchange](https://www.rabbitmq.com/img/tutorials/python-four.png)

#### 3. topic

消息会被发送到绑定到该 exchange 且 routing key 与其匹配的队列。

   - routing key 是一系列由点隔开的单词
   - \* 表示一个任意单词
   - \# 表示 0 个或多个单词

![topic exchange](https://www.rabbitmq.com/img/tutorials/python-five.png)

例如上图中，\*\.\*\.rabbit 表示任意种类的兔子，\*\.orange\.\* 表示任意橙色的东西。

### Dead Letter Exchange (DLX)

在某些异常情况下，例如一个消息不能被路由到任何一个队列，根据不同的策略，消息可以被返还给 publisher、丢弃或者加入 DLX。DLX 也是一个普通的 exchange，在以下几种情况下，一条消息会被重新发布到 DLX：

- 消息被 consumer 拒收，并且 requeue 被设置为 false
- 消息已经超时了（TTL）
- 队列满了，无法接收新的消息

绑定到 DLX 的队列（死信队列）可用于存储死信，这样对于一些重要的消息即使消费失败也不会丢失。

DLX 还可以提供延时重试的机制，因为有的时候消息消费失败了（可能是业务系统网络延时等原因造成的），但并不想马上重试（例如将 requeue 设置为 true），而是隔一段时间后再重试。

结合消息的 TTL，利用 DLX 还可以实现消息的延时消费。

**注：队列可以设置其上消息的超时时间（message-ttl），也可以设置队列自身的超时时间（expires），只有消息本身超时才会变为死信，队列超时后，不会导致其上的消息变为死信。**

## 用 RabbitMQ 实现延迟队列的两种方案

### 1. 队列或者消息的 TTL 配合 DLX

实现流程如下图所示：

![DLX 实现延迟队列](https://youdu-markdown.oss-cn-shanghai.aliyuncs.com/20191029094439.png)

生产者将消息发布到“缓冲队列”（消息先发送到 exchange，这个 exchange 绑定了一个设置了 message-ttl 的队列，该队列没有任何消费者，因此消息会在一定时间后超时）。

消息超时后会被发布到“缓冲队列”绑定的 DLX，并被路由到对应的“实际消费队列”，最终被消费者消费。

队列中消息的 TTL 可以设置在队列上，有以下两种方法：

- 设置队列的 policy（message-ttl）。如果需要修改，可以直接在服务上用命令修改，无需改动业务代码，无需删除原有队列。官方文档推荐用这种方法设置 TTL。具体命令如下：

```shell
rabbitmqctl set_policy expiry ".*" '{"expires":1800000}' --apply-to queues
```

- 设置 optional queue arguments 的 x-message-ttl 值，由于属性是声明队列时设置的，因此如果需要修改，则必须删除原来的队列而建新的队列，并且修改相应的业务代码。这种方法可能适用于声明 auto-delete 为 true 的队列，由业务代码声明，可以灵活设置想要的 TTL。示例代码如下：

```java
// 声明队列时设置 x-message-ttl 属性为 60000 毫秒
Map<String, Object> args = new HashMap<String, Object>();
args.put("x-message-ttl", 60000);
channel.queueDeclare("myqueue", false, false, false, args);
```

消息在发布时也可以单独设置 TTL。如果此时队列也设置了 TTL，则取两者较小的值起作用。示例代码如下：

```java
byte[] messageBodyBytes = "Hello, world!".getBytes();
AMQP.BasicProperties properties = new AMQP.BasicProperties.Builder()
    .expiration("60000")
    .build();
channel.basicPublish("my-exchange", "routing-key", properties, messageBodyBytes);
```

然而，根据官网文档的描述：

> Only when expired messages reach the head of a queue will they actually be discarded (or dead-lettered).
>
> 超时的消息只有到达了队列的头部才会真正被移除或变为死信。

举例来说，如果队列设置了消息的超时时间为 10 秒，一个自身设置了超时时间为 5 秒的消息并不一定能保证其被加入队列 5 秒后被移除。因为这条消息之前可能已经有很多消息插入队列了，这些消息的超时时间都是 10 秒，那么这条消息就必须等前面的消息都被移除后才能被移除。因此，即使单独设置消息的超时时间，其行为也非常不可控，无法实现所谓任意时长的延时效果。

消息超时变为死信后，会被发布到队列配置的 DLX，DLX 也是一个再普通不过的 exchange，发布到 DLX 的消息同样会被路由到绑定到 DLX 的符合路由条件的队列，这样就实现了消息的延时消费。配置队列的 DLX 同样有两种方式：

- 设置队列的 policy（dead-letter-exchange）。具体命令如下：

```shell
rabbitmqctl set_policy DLX ".*" '{"dead-letter-exchange":"my-dlx"}' --apply-to queues
```

- 设置 optional queue arguments 的 x-dead-letter-exchange 值。示例代码如下：

```java
// 声明一个 direct exchange
channel.exchangeDeclare("some.exchange.name", "direct");
// 声明一个队列，将前面声明的 exchange 设置为其 DLX
Map<String, Object> args = new HashMap<String, Object>();
args.put("x-dead-letter-exchange", "some.exchange.name");
channel.queueDeclare("myqueue", false, false, false, args);
```

缓冲队列可以设置 x-dead-letter-routing-key 属性，如果不设置，消息进入 DLX 后，将仍用消息自身的 routing key 路由。

限制：

- 由于延时消息实际存放在队列中，因此延时不易设置过大，否则可能会导致大量消息积压在队列中，占用 broker 资源。
- 不支持发送任意 TTL 的消息，TTL 必须与延时队列绑定。

### 2. 使用 rabbitmq-delayed-message-exchange 插件

RabbitMQ v3.5.8 及以后版本支持该插件，首先来看一下官方文档上的一句话：

> This plugin is considered to be **experimental yet fairly stable and potential suitable for production use as long as the user is aware of its limitations**.
>
> 该插件是实验性质的，然而其也相当稳定并具有在生产中使用的潜质，前提是使用者清楚它的局限性。

rabbitmq-delayed-message-exchange 插件会将消息持久化到数据库（Mnesia），再利用调度器调度消息的发布。因此延迟消息并不直接发布到任何 exchange，因此也不会直接保存到任何队列里，而是先保存在磁盘上，到了具体的需要发布的时间再发布，因此消息在发布时会对于实际的发布时间有一定的延迟。

限制：
- 持久化的消息数据库是单点的，一旦某个节点的丢失或者禁用该节点上的 rabbitmq-delayed-message-exchange 插件会导致这个节点上的所有延迟消息都丢失掉。
- 消息只会被尝试发布一次，如果发布消息时没有可以消费的队列存在，消息也不会被退回原发布者，因为不能保证此时原发布者还“活着”。
- 同时存在的延迟消息总数不能超过百万级。具体参见 [issue 72](<https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/issues/72>)。其实说白了，我们不应该期待把 RabbitMQ 当做数据库来使用，每一个技术都有其适用条件，如果有大量延迟消息需要持久化，完全可以考虑用其他方法解决问题。

插件的安装和使用方法参见官方文档：[RabbitMQ plugins](<https://www.rabbitmq.com/plugins.html>)。

那么我们该如何使用这个插件实现延迟队列呢？具体步骤如下：

- 使用 exchange 的扩展属性，将 exchange 设置为”延迟“的，代码如下：

```java
Map<String, Object> args = new HashMap<String, Object>();
args.put("x-delayed-type", "direct");
channel.exchangeDeclare("my-exchange", "x-delayed-message", true, false, args);
```

- 发布消息时设置消息 header 的 x-delayed 属性，可以看到插件支持任意时长的消息延时。代码如下：

```java
byte[] messageBodyBytes = "delayed payload".getBytes("UTF-8");
Map<String, Object> headers = new HashMap<String, Object>();
headers.put("x-delay", 5000);
AMQP.BasicProperties.Builder props = new AMQP.BasicProperties.Builder().headers(headers);
channel.basicPublish("my-exchange", "", props.build(), messageBodyBytes);
```

## 参考资料

1. [RabbitMQ 官方文档](https://www.rabbitmq.com/documentation.html)
2. [rabbitmq-delayed-message-exchange](<https://github.com/rabbitmq/rabbitmq-delayed-message-exchange>)

## 实验代码

所有实验代码参见：[github 源码](https://github.com/yiwanzhutourou/learning/tree/master/learning-rabbitmq)，**注意**，不同框架有不同的集成 RabbitMQ 的方案，请参阅相关文档，请不要在生产环境中直接使用实验代码。