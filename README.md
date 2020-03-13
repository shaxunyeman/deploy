# Deploy 部署说明

## 目录结构

**scripts** 目录包含服务执行脚本

**peersafe_zebra_service.tar.gz** 压缩文件里直接包括 peersafe_server、peersafe_relay、peersafe_client 和 peersafe_push_service 服务

**config.json** 配置文件，包括各种服务启动参数配置，具体参考 **配置文件** 说明

**peersafe_zebra.sh** 负责在远程服务上执行特定的启动脚本

**deploy.sh** 部署脚本，只在本地执行，具体使用参考 **使用方法** 说明



## 配置文件

```json
{
    "work_path":"~/zebra",
    "peersafe_server": {
        "hosts":[
            {"user":"dev","ip":"127.0.0.1", "port":22,"key":"~/.ssh/id_rsa"}
        ],
        "disable_zero":0,
        "port":37053,
        "ip_family":4,
        "log_level":"Info",
        "bootstraps":[
            "127.0.0.1:37053"
        ]
    },
    "peersafe_box": {
        "hosts":[
            {"user":"dev","ip":"127.0.0.1", "port":22,"key":"~/.ssh/id_rsa"}
        ],
        "port":47054,
        "ip_family":6,
        "log_level":"Info",
        "rest_api_port":8080,
        "rest_api_protocol":"http",
        "bootstraps":[
            "127.0.0.1:37053"
        ],
        "peersafe_relays":[
	    "peersafe:peersafe@::FFFF:127.0.0.1:34780"
        ]
    },
    "peersafe_relay": {
        "hosts":[
            {"user":"dev","ip":"127.0.0.1", "port":22,"key":"~/.ssh/id_rsa"}
        ],
        "port":34780,
        "ip_family":6,
        "user":"peersafe",
        "passwd":"peersafe"
    },
    "peersafe_push_service":{
        "hosts":[
            {"user":"dev","ip":"127.0.0.1", "port":22,"key":"~/.ssh/id_rsa"}
        ],
        "redis":"127.0.0.1:6379",
        "log_level":"Info",
        "bootstraps":[
            "127.0.0.1:37053"
        ]
    },
    "announce" : {
        "bootstraps": [
            "127.0.0.1:37053"
        ],
        "add":[
            {
                "user": "user",
                "pwd": "pwd",
                "ip": "127.0.0.1",
                "port": 34780
            }
        ],
        "remove": [
             {
                "ip": "127.0.0.1",
                "port": 34780
            }           
        ],
        "fetch": 1
    }
}
```

- .work_path 脚本远程工作目录

- .peersafe_server 部署 peersafe_server 服务参数配置

  - .peersafe_server.hosts 远程主机地址列表，目前仅支持登录秘钥
  - .peersafe_server.disable_zero 是否启动 zero 节点，默认启动
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

- .announce announce 服务配置参数
  - .announce.bootstraps 服务启动时需要的引导节点
  - .announce.add 需要 announce 的 peersafe_relay 服务参数
  - .announce.remove 需要从网络中移除的 peersafe_relay 服务参数
  - .announce.fetch 是否需要从网络中获取 announced peersafe_relay 服务列表

  

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
  install     install peersafe services
  uninstall   unstall peersafe services 
  upload      upload a executable service
  annouce     annouce/fetch/remove peersafe_relays to/from zebra network

 services
  peersafe_server
  peersafe_relay
  peersafe_box
  peersafe_push
  
options
  -c|--config specify config, defualt ${deploy_config}
  -i|--which  where execute instructions
  -w,c rewrite configuration
  -w,s rewrite executable scripts
  --bootstrap hosts1[;hosts2]     specify a bootstrap nodes

examples:
 peersafe_zebra start                         start all services
 peersafe_zebra start peersafe_server         start a peersafe_server
 peersafe_zebra start peersafe_server -i 0    start a peersafe_server on specified remote host by i
 peersafe_zebra stop                          stop all services
 peersafe_zebra show                          show all status of running services
```

**安装服务**
```json
> ./deploy.sh -c config.json install
```
> 注: 执行其他命令前，请先安装依赖包

**启动配置文件所有程序**

```bash
>./deploy.sh -c config.json start
```

**查看所有服务的运行状态**

```bash
>./deploy.sh -c config.json show
name            pid        protocol listen            host
peersafe_serv   45389      udp    0.0.0.0:37053     192.168.29.145
peersafe_box    45646      udp    0.0.0.0:47054     192.168.29.145
peersafe_rela   45876      udp6   :::34780          192.168.29.145
```

**停止所有服务**

```bash
>./deploy.sh -c config.json stop
```

**在某个远程节点上启动 peersafe_server zero 节点**

```bash
> ./deploy.sh -c config.json start peersafe_server -i 0
```

**在某个远程节点上启动 peersafe_server non-zero 节点**

```bash
> ./deploy.sh -c config.json start peersafe_server -i 1 --bootstrap 192.168.29.66:37053
```

**移除远程主机上的所有服务（注：必须先停止所有服务）**

```bash
> ./deploy.sh -c config.json uninstall
```
## 服务配置环境说明

1. peersafe_relay 服务必须同时部署支持 ipv4 和 ipv6 版本
2. announce 服务需要同时 announce 上述 peersafe_relay 服务的两个版本
3. peersafe_client 和 peeersafe_box 测试的时候，指定 cache 参数的时候需要同时指定 peersafe_relay 的 ipv4 和 ipv6 版本