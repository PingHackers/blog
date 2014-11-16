title: Web前后端分离开发思路
date: 2014-11-16 00:50:44
tags:
- web
- 流程
---

## 1. 问题的提出

开发一个Web应用的时候我们一般都会简单地分为前端工程师和后端工程师（注：在一些比较复杂的系统中，前端可以细分为外观和逻辑，后端可以分为CGI和Server）。前端工程师负责浏览器端用户交互界面和逻辑等，后端负责数据的处理和存储等。前后端的关系可以浅显地概括为：后端提供数据，前端负责显示数据。

在这种前后端的分工下，会经常有一些疑惑：**既然前端数据是由后端提供，那么后端数据接口还没有完成，前端是否就无法进行编码？怎么样才能做到前后端独立开发？**

<!-- more -->

考虑这么一个场景：Alex和Bob是一对好基友，他们有个可以颠覆世界的idea，准备把它实现出来，但是他们不需要程序员，因为他们就是程序员。说干就干，两个就干上了。Alex写前端，Bob写后端。

Alex和Bob都经过良好的训练，按部就班地把产品的主要功能设计，交互原型，视觉设计做好了，然后他们根据产品功能和交互制定了一堆叼炸天的前后端交互的API，这套API就类似于一套前后端开发的“协议”，Alex和Bob开发的时候都需要遵守。例如其中一个发表评论的功能：

    // API: Create New Comment v2
    // Ajax, JSON, RESTful
    url: /comments
    type: POST
    request: {content: "comment content.", userId: 123456}
    response: 
        - status: 200
            data: {result: "SUCCESS", msg: "The comment has been created."}
        - status: 404
            data: {result: "failed", msg: "User is not found."}

Alex的前端需要向`/comments`这个url以`POST`的方式发送类似于`{content: "comment content.", userId: 123456}`这样的JSON请求数据；Bob的服务端识别后以后，操作成功则返回200状态和上面的JSON的数据，不同的操作状态有不同的响应数据（为了简单起见只列出了两种，200和404）。

API制定完以后，Alex和Bob就开始编码了。Alex把评论都外观和交互写完了，但是写到发表评论功能就纳闷了：Alex现在需要发Ajax过去，但是只能把Ajax代码写好，因为是本地服务器，却无法获取到数据：

    // jQuery Ajax
    $.ajax({ // 这个ajax直接报错，因为这个是Alex的前端服务器，请求无法获取数据；
        url: "/comments",
        type: "POST",
        data: {content: content, userId: userId},
        success: funtion(data) {
            // 这里不会被执行
        }
    })


相比起来Bob就没有这个烦恼，因为后端是基于测试驱动开发，且后端可以轻易地模拟前端发送请求，可以对前端没有依赖地进行开发和测试。

Alex把这种情况和Bob说了，Bob就说，要不我们把代码弄到你本地前后端连接一下，这不就可以测试了吗。Alex觉得Bob简直是天才。

他们把前后端代码代码都部署到Alex的本地服务器以后，经过一系列的测试，调试，终于把这个API连接成功了。但是他们发现这个方法简直不科学：难道每写一个API都要把前后端链接测试一遍吗？而且，Alex的如果需要测试某个API，而Bob的这个API还没写好，Alex这个功能模块的进度就“阻塞”了。

后面还有168个API需要写，不能这么做。Alex和Bob就开始思考这个问题的解决方案。

## 2. 解决思路
在这个场景下，前后端是有比较强的数据依赖的关系，后端依赖前端的请求，前端依赖后端的响应。而后端可以轻松模拟前端请求（基本上能写后端的语言都可以直接发送HTTP请求），前端没有一个比较明显的方案来可以做到模拟响应，所以这里的需要解决的点就是：**如何给前端模拟的响应数据**。

先来一句非常形而上的话：如果两个对象具有强耦合的关系，我们一般只要引入第三个对象就可以打破这种强耦合的关系。

    +---------+              +---------+
    |         |              |         |
    | Object1 |  <-------->  | Object2 |
    |         |              |         |
    +---------+              +---------+
                                    
                   Before               
                                    
                                    
    +---------+              +---------+
    |         |              |         |
    | Object1 |  <-- ✕ --->  | Object2 |
    |         |              |         |
    +---+-----+              +-----+---+
        |                          |    
        |                          |    
        |                          |    
        |                          |    
        |                          |    
        |       +---------+        |    
        |       |         |        |    
        +-----> | Object3 | <------+    
                |         |             
                +---------+             
                                    
                   After                


      
在我们上述开发的过程中，前后端的耦合性太强了，我们需要借助额外的东西来打破它们的耦合性。所以，在前后端接口定下来以后，**我们根据接口构建另外一个Server，这个Server会一一响应前端的请求，并且根据接口返回数据**。当然这些数据都是假数据。我们把这个Server叫做*Mock Server*，而Bob真正在开发的Server叫做*Real Server*。

    +-------------------+                     +-------------------+
    |                   | +-------- ✕ ------> |                   |
    |     Browser       |                     |    Real Server    |
    |                   | <---+               |                   |
    +--------------+----+     |               +-------------------+
                   |          |                                    
                   |          |                                    
                   |          |                                    
                   |          |                                    
               Request      Response                               
                   |          |                                    
                   |          |                                    
                   |          |                                    
                   |     +----+--------------+                     
                   +---> |                   |                     
                         |    Mock Server    |                     
                         |                   |                     
                         +-------------------+                     


Mock Server是根据API实现的，但是是没有数据逻辑的，只是非常简单地返回数据。例如上面Alex和Bob的发表评论的接口在Mock Server上是这样的：

    // Mock Server
    // Create New Comment API
    route.post("/comments", function(req, res) {
        res.send(200, {result: "Success"});
    })
    
Alex在开发的时候向Mock Server发出请求，而不是向Bob的服务器发出请求：


    // Sending Request to Mock Server
    // jQuery Ajax
    $.ajax({ 
        url: config.HOST + "/comments",
        type: "POST",
        data: {content: content, userId: userId},
        success: funtion(data) {
            // OK
        }
    })

注意上面的`config.HOST`，我们把服务器配置放在一个全局共用的模块当中：

    // Front-end Configuration Module
    var config = modules.exports;
    config.HOST = "http://192.169.10.20" // Mock Server IP

那么上面我们其实是向IP为`http://192.169.10.20`的Mock Server发出请求`http://192.169.10.20/comments`发出POST的请求。

当Alex和Bob都代码写好了以后，需要连接调试了，Alex只要简单地改一下配置文件即可把所有的请求都转向Bob所开发的Real Server：

    // Front-end Configuration Module
    var config = module.exports;
    // config.HOST = "http://192.169.10.20" // Mock Server IP
    config.HOST = "http://changing-world-app.com" // Real Server Domain

然后Alex和Bob就可以愉快地分离独立开发，而最后只需要联合调试就可以了。

总结一下基本上前后端分离开发包括下面几个步骤：

1. 根据功能制定前后端接口（API）。
2. 根据接口构建Mock Server工程及其部署。
3. 前后端独立开发，前端向Mock Server发送请求，获取模拟的数据进行开发和测试。
4. 前后端都完成后，前后端连接调试（前端修改配置向Real Server而不是Mock Server发送请求）。

当然要注意，如果接口修改了，Mock Server要同步修改。

## 3. 实现方案

Mock Server具体应该如何构建？应该存放在哪里？应该怎么维护？

前后端是不同的两个工程，它们各自占用一个仓库。Mock Server应该和它们分离出来，独立进行开发和维护，也就是说会有三个仓库，Mock Server是一个单独的工程。

Mock Server可以部署在本地，也可以部署到远程服务器，两者之间各有优劣。

* * *

### 3.1 远程Mock Server 

**做法**：把Mock Server工程部署到一个远程的always on的远程服务器上，前端开发的时候向该服务器发请求。

**优点**：

1. 没有给原有的前后端工程增加负担。
2. 每个前端开发人员向同一个Mock Server服务器发送请求，保持所有人获取响应请求的一致性。

**缺点**：

1. 有跨域问题（思考：locahost如何向192.169.10.20发请求？）。
2. 需要额外的远程服务器支持。

（在写这篇博客的时候，逛[Hacker News](https://news.ycombinator.com/)，刚好看到有人做了一个开发辅助工具（[http://reqr.es/](http://reqr.es/)），可以用于开发时响应前端请求，其实也就是这里所说的远程Mock Server。真是不能再巧更多。）

### 3.2 本地Mock Server

**做法**：前端把Mock Server克隆到本地，开发的时候，开启前端工程服务器和Mock Server，所有的请求都发向本地服务器，获取到Mock数据。

**优点**：

1. 节约资源，不需要依赖远程服务器。环保节能。
2. 没有跨域问题。

**缺点**：

1. 增加前端工程开发流程复杂程度。
2. 每个前端开发人员自己部署服务器在本地，可能会有仓库没有及时更新导致API不一致的情况。

* * * 

Mock Server工程一般可以由后端开发人员来维护。因为在开发的过程中，后端因为各种原因可能需要修改API，后端人员是最熟悉请求的响应数据和格式的人，可以同步维护Mock Server和Real Server，更好保证数据的一致。Mock Server维护起来并不复杂，对于比较大多工程来说，这样的前期准备和过程的维护是非常值得的。

## 最后

所以要点就是：**根据API构建可以模拟服务器响应的Mock Server，用于前端请求模拟数据进行测试**。

再重复总结一下前后端分离开发包括下面几个步骤：

1. 根据功能制定前后端接口。
2. 根据接口构建Mock Server工程及其部署。
3. 前后端独立开发，前端向Mock Server发送请求，获取模拟的数据进行开发和测试。
4. 前后端都完成后，前后端连接调试。

当开发只有我一个人的时候，我更喜欢后端独立开发，开发前端的时候开个Real Server来做响应。又爽又快。其实如果团队的人是full-stack的话，完全可以按照功能模块来划分任务，而不是分为前端工程师和后端工程师。

但一般来说还是会选择前后端职能划分，对于这种情况下的多人开发的工程来说，前后端分离开发的方式确实需要考虑和构建的，可以更好帮助我们构建一个高效，规范化，流程化的开发流程。

还是那句话，没有银弹，所有的东西都需要根据实际情况来构建独特的流程。

## References
 无
 
（全文完）