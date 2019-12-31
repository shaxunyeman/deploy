# Deploy 部署说明

## 目录结构

**bin** 目录包含 zebra 服务

**etc** 目录包含 zebra 服务配置

**scripts** 目录包含服务执行脚本

**peersafe_zebra_service.tar.gz** 压缩文件里直接包括 peersafe_server、peersafe_relay、peersafe_client 和 peersafe_push_service 服务

**config.json** 配置文件，包括各种服务启动参数配置，具体参考 **配置文件** 说明

**peersafe_zebra.sh** 负责在远程服务上执行特定的启动脚本

**deploy.sh** 部署脚本，只在本地执行，具体使用参考 **使用方法** 说明



## 配置文件

```json
{
    "work_path":"/home/peersafe/zebra",
    "peersafe_server": {
        "hosts":[
            {"user":"peersafe","ip":"192.168.29.145", "port":22,"key":"/home/dbliu/.ssh/id_rsa@jumperserver"}
        ],
        "port":37053,
        "ip_family":4,
        "log_level":"Info",
        "bootstraps":[
            "192.168.29.145:37053"
        ]
    },
    "peersafe_box": {
        "hosts":[
            {"user":"peersafe","ip":"192.168.29.145", "port":22,"key":"/home/dbliu/.ssh/id_rsa@jumperserver"}
        ],
        "port":47054,
        "ip_family":4,
        "log_level":"Info",
        "rest_api_port":8080,
        "rest_api_protocol":"http",
        "bootstraps":[
            "192.168.29.145:37053"
        ],
        "peersafe_relays":[
            "peersafe:peersafe@192.168.29.:34780"
        ]
    },
    "peersafe_relay": {
        "hosts":[
            {"user":"peersafe","ip":"192.168.29.145", "port":22,"key":"~/.ssh/id_rsa@jumperserver"}
        ],
        "port":34780,
        "ip_family":4,
        "user":"peersafe",
        "passwd":"peersafe"
    },
    "peersafe_push_service":{
        "hosts":[
            {"user":"peersafe","ip":"192.168.29.145", "port":22,"key":"~/.ssh/id_rsa@jumperserver"}
        ],
        "redis":"127.0.0.1:6379",
        "log_level":"Info",
        "bootstraps":[
            "127.0.0.1:37053"
        ]
    }
}
```

- .work_path 脚本远程工作目录

- .peersafe_server 部署 peersafe_server 服务参数配置

  - .peersafe_server.hosts 远程主机地址列表，目前仅支持登录秘钥
  - .peersafe_server.port peersafe_server 服务监听端口
  - .peersafe_server.ip_family 值为 4 代表 IPv4，6 代表 IPv6
  - .peersafe_server.log_level 日志登录，值可以为 Verbose(V), Info(I), Success(S), Warning(W), Error(E), Always(A)
  - .peersafe_server.bootstraps peersafe_server 服务启动时需要的引导节点

- .peersafe_box 部署盒子服务参数配置

  - .peersafe_box.hosts 远程主机地址列表，目前仅支持登录秘钥
  - .peersafe_box.port 盒子监听的服务端口
  - .peersafe_box.ip_family 值为 4 代表 IPv4，6 代表 IPv6
  - .peersafe_box.log_level 日志登录，值可以为 Verbose(V), Info(I), Success(S), Warning(W), Error(E), Always(A)
  - .peersafe_box.rest_api_port 盒子 http(s) 服务端口
  - .peersafe_box.rest_api_protocol 盒子 http 协议，值可以为 http 和 https
  - .peersafe_box.bootstraps 盒子启动时需要的引导节点
  - .peersafe_box.peersafe_relays 指定盒子启动时需要的 ICE 服务列表，如果不指定从网络中获取

- .peersafe_relay ICE 服务参数配置

  - .peersafe_relay.hosts 远程主机地址列表，目前仅支持登录秘钥
  - .peersafe_relay.port ICE 监听的服务端口
  - .peersafe_relay.ip_family 值为 4 代表 IPv4，6 代表 IPv6
  - .peersafe_relay.user 设置 ICE 凭证用户
  - .peersafe_relay.passwd 设置 ICE 凭证密码

- .peersafe_push_service 推送服务配置参数

  - .peersafe_push_service .hosts 远程主机地址列表，目前仅支持登录秘钥
  - .peersafe_push_service .redis redis-server 服务地址和端口
  - .peersafe_push_service .log_level 日志登录，值可以为 Verbose(V), Info(I), Success(S), Warning(W), Error(E), Always(A)
  - .peersafe_push_service .bootstraps peersafe_server 服务启动时需要的引导节点

  

## 使用方法

**查看帮助**

```bash
> deploy.sh -h
usage: 
 deploy command [service] [option]

 commands
  start       start a service
  update      update a service
  stop        stop a service
  show        show status of a service
  remove      remove zebra directory

 services
  peersafe_server
  peersafe_relay
  peersafe_box
  peersafe_push

 options
  -i|--which  where executes instructions
  --bootstrap hosts1[:hosts2]     specify a bootstrap nodes, only for peersafe_server

examples:
 peersafe_zebra start                         start all services
 peersafe_zebra start peersafe_server         start a peersafe_server
 peersafe_zebra start peersafe_server -i 0    start a peersafe_server on specified remote by i
 peersafe_zebra stop                          stop all services
 peersafe_zebra show                          show all status of running services
```

**启动配置文件所有程序**

```bash
>./deploy.sh start
```

**查看所有服务的运行状态**

```bash
>./deploy.sh show
name            pid        protocol listen            host
peersafe_serv   45389      udp    0.0.0.0:37053     192.168.29.145
peersafe_box    45646      udp    0.0.0.0:47054     192.168.29.145
peersafe_rela   45876      udp6   :::34780          192.168.29.145
```

**停止所有服务**

```bash
>./deploy.sh stop
```

**在某个远程节点上启动 peersafe_server zero 节点**

```bash
> ./deploy start peersafe_server -i 0
```

**在某个远程节点上启动 peersafe_server non-zero 节点**

```bash
> ./deploy start peersafe_server -i 1 --bootstrap 192.168.29.66:37053
```

**移除远程主机上的所有服务（注：必须先停止所有服务）**

```bash
> ./deploy remove
```

