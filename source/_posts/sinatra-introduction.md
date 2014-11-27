title: Sinatra - 简洁的 Ruby 开发框架
date: 2014-11-27 15:33:02
description: PingHackers | Sinatra - 简洁的 Ruby 开发框架 | 用惯了重型武器 Ruby on Rails，来看看轻量级框架 Sinatra 的特性和使用场景。
tags: 
- Ruby
---
**作者**：吴泽秋

**转载请注明出处，保留原文链接和作者信息**

* * *

本文希望通过搭建简单的 Sinatra 应用作为栗子，来展示 Sinatra 这个轻量级框架的特点和开发模式。
毕竟不是官方文档，不能面面俱到，有心学习的同学可以通过文后附录的资料进一步研究，对文章中出现的问题也请读者们指正。

<!-- more -->

## Prerequisites 预备条件

首先。你得。在机子上有 Ruby 环境。

如果是 Mac 用户请直接无视这一步。因为系统里已经有了。（不信 `ruby -v` 试试？）

如果是 Windows/Linux 用户，请在谷歌自行搜索教程，完成 **Ruby开发环境的搭建** 。当然如果有时间 ~~（还没有被毕业论文艹死）~~ 我也非常愿意来一发讲搭建开发环境的科普文。
（作为在 Windows/Linux/Mac 上都用过 Ruby 开发的人，表示如果要写，就写三个平台的，绝对业界良心）

## 一个栗子的开始总是 Hello world

{% codeblock lang:rb %}
# app.rb
require 'sinatra'

get '/hello' do
  'Hello world!' # return 'Hello world'
end
{% endcodeblock %}

接下来只需要在命令行里执行：

{% codeblock lang:shell %}
$ gem install sinatra
$ ruby app.rb
{% endcodeblock %}

看到：
{% codeblock lang:shell %}
== Sinatra has taken the stage ...
>> Listening on 0.0.0.0:4567
{% endcodeblock %}

打开`http://localhost:4567/hello`就能看到浏览器上的 Hello world 了。

**就这么简单？确定不是在逗我么？**

是的。Sinatra 是基于 Ruby 语言的 [DSL](http://en.wikipedia.org/wiki/Domain-specific_language)，可以快速的创建一个 web 应用。

如果你使用过 Express，你会发现它和上述的 Sinatra 的例子的语法表述非常接近。
事实上，有 [大量的框架][1] 受到了 Sinatra 的影响。

但一个 naive 的 hello world 是拿不出手的，接下来我们会逐步的加入功能。

### 添加路由

首先我们添加两个路由，分别接受 GET 和 POST 请求

{% codeblock lang:rb %}
# app.rb
# ... 省略之前的代码

get '/hello/:name' do
  "Hello #{params[:name]}"
end

post '/hello' do
  params[:name] ||= "Nobody" # 如果post的数据中没有name，则设为 "Nobody"
  "Hello #{params[:name]}"
end
{% endcodeblock %}

对应的结果：

{% codeblock %}
GET /hello/Bob => "Hello Bob"
POST /hello => "Hello Nobody"
POST /hello name=Allen "Hello Allen"
{% endcodeblock %}

顺带提一句，你们是如何来测试非 GET 的接口呢？有两个常用的方法：

1. 在命令行下使用 curl：

  {% codeblock lang:shell %}
  curl http://localhost:4567/hello # 默认使用GET请求
  curl -X POST http://localhost:4567/hello -d name=Allen # 指定POST请求，带有数据 name=Allen，默认使用 application/x-www-form-urlencoded 格式
  curl -X POST http://localhost:4567/hello -d name=Allen gender=male # 多个数据的POST请求
  {% endcodeblock %}

  curl 是一个很方便的工具，在 linux 和 Mac OS 下都很容易可以得到，但在我们需要复杂的 POST 数据请求，或者是 JSON 请求时，curl 就会显得很麻烦。
  以下推荐一个很好用的 Chrome App:
2. Advanced Rest Client
  具体安装就不说了，请自行谷歌。只上图，不说话：
  ![Advanced Rest Client](/imgs/advanced-rest-client.png)
  用了之后，感觉自己萌萌哒。

关于路由，再补充几点：

  1. 和 Express 一样，路由按照被定义的顺序进行匹配——第一个与请求匹配的路由会被调用。在路由和请求不匹配时，请求会被丢给下一个路由去匹配。
  最后没有匹配到任何路由的请求，会抛出异常并被 Sinatra 捕获，返回一个默认的 404 页面。
  2. 路由代码块的返回值（即最后一个表达式的值）决定了返回给 HTTP 客户端的响应体。大多数情况下是一个字符串，但也可以返回任何的对象。
  3. 路由的范式（即上文例子中的 `/hello`，`/hello/:name` 等）可以包含通配符参数，也可以使用正则表达式，这一点也和 Express 相同。
  4. 路由可以包括匹配条件，如 user agent；可以指定自定义的条件；可以指定返回的内容类型(html/rss/atom/xml)
  5. 在路由代码块中你可以用 `halt` 将请求挂起，也可以 `pass` 放弃处理请求，丢给后面的路由（和 Express 的 middleware 的 `next` 一样）；
  还可以用 `redirect` 跳转到其他 url 上。

更多关于路由的用法，请参考官方文档的[路由](https://github.com/sinatra/sinatra/blob/master/README.zh.md#%E8%B7%AF%E7%94%B1route)一节。

### 添加首页模板

虽然通常我自己只用 Sinatra 来做小型的 API 服务，但实际上 Sinatra 也是可以通过模板来返回 view 页面的。以下应用 slim 模板，给应用加一个首页：

{% codeblock lang:rb %}
# app.rb
# 省略前面代码...

require 'slim'
get '/' do
  slim :"home/index"
end
{% endcodeblock %}

在 Sinatra 中，模板文件默认是放置在 `views/` 文件夹下的。由于我们渲染的模板文件的路径是 `home/index`，所以模板文件为 `views/home/index.slim`：

{% codeblock lang:slim %}
h1 Homepage
p This is the homepage. Let's Rock!
{% endcodeblock %}

在浏览器中访问 `http://localhost:4567/` 就可以看到刚刚完成的模板文件渲染的 html 页面。
但作为一个网站，通常我们需要有一个固定的公用布局。在 Sinatra 中，如果存在名为 "layout" 的模板，该模板会被默认使用。

我们希望网站的布局如下所示：

{% codeblock %}
/------------------------------\
|           header             |
|------------------------------|
|         |                    |
|         |                    |
| sidebar |    main content    |
|         |                    |
|         |                    |
|------------------------------|
|           footer             |
\------------------------------/
{% endcodeblock %}

以下是 `views/layout.slim`：

{% codeblock lang:slim %}
doctype html
html
  head
    title = @title || "Sinatra Demo"
  body
    header
      = @title || "Sinatra Demo"
    main
      aside
        ul
          li
            a href="/about" ="about"
      section
        == yield
    footer
{% endcodeblock %}

这时刷新页面，发现首页的确出现了模板生成的 html 页面。需要解释的是 `views/layout.slim`  中的第4行，出现了一个 `@` 开头的变量 `@title`。
这个变量可以在路由中定义， 且不同的路由中可以对 `@title` 赋不同的值。

现在模板已经完成了，但从浏览器打开观看的效果很一般，需要添加一些样式，如果可能的话还需要添加一点 js。

### 添加 assets

在 Sinatra 中，静态文件是从 `./public_folder` 目录提供服务，可以通过设置 `:public_folder` 选项来指定一个不同的位置：

{% codeblock lang:rb %}
# app.rb
# 省略前面内容...

set :public_folder, File.dirname(__FILE__) + '/static'

# 省略路由...
{% endcodeblock %}

然后在 `views/layout.slim` 中加入一行，引用 CSS 文件：

{% codeblock lang:slim %}
... # 省略
   head
     title = @title || "Sinatra Demo"
     link rel="stylesheet" href="/css/style.css" # 添加 CSS
   ... # 省略
{% endcodeblock %}

最后新建 `static/css/sytle.css` 文件如下：

{% codeblock lang:css %}
header {
  height: 100px;
  line-height: 100px;
  text-align: center;
  width: 100%;
}
main aside {
  float: left;
  width: 15%;
}
main section {
  float: left;
  width: 15%;
}
footer {
  height: 50px;
  line-height: 50px;
  text-align: center;
  width: 100%;
}
{% endcodeblock %}

DONE. => 虽然有点丑，但意思表达出来就可以了。

插播一个问题。如果读者照着本文的流程做的话，会发现修改了 `app.rb` 之后的刷新有时会没有效果。解决的方法是将原来的 sinatra 应用关掉，重新开一次就可以了。
（话外音：这不科学啊老湿！艾伦：没错，其实有一个很好的解决方法，不过要留到以后再讲...）

### 数据-持久化-ORM：DIY

好了，路由有了，页面也有了，接下来就是数据了，如何储存数据呢？使用过 Rails 的同学深谙 [MVC](http://zh.wikipedia.org/zh/MVC) 之道，
会觉得 Model 是和 Controller, View 结合甚好的一部分，如果是默认使用关系型数据库的童鞋，甚至不需要去管 sql ，
通过 Rails 赋予的 generator 也可以很舒服的建起一个 Model 来。

但这就是 Sinatra 的一大特色：选用什么数据库，和什么 ORM，是开发者自己要关心的事情，再也没有 Rails 这样的全职管家来 take care of it.
甚至连加载 Model 文件的路径，也需要自己设定，并不遵循任何的 convention. 在本例中，我采用 MongoDB 作为数据库，
于是我选用 Mongoid 来作为对接数据库的 [ORM](http://zh.wikipedia.org/wiki/%E5%AF%B9%E8%B1%A1%E5%85%B3%E7%B3%BB%E6%98%A0%E5%B0%84) 工具。

具体的代码是这样的：

{% codeblock lang:rb %}
# models.rb
# 由于整个应用就只有一个 Model，所以把代码集中到这里
# 事实上，开发者可以按照自己的风格，建立 models/ 文件夹，再将各个 Model 独立成文件放在目录下

class Todo
  include Mongoid::Document

  field :title, type: String
  field :date, type: Date, default: Time.now
  field :permalink, type: String, default: -> { make_permalink }

  def make_permalink
    title.downcase.gsub(/\W/, '-').squeeze('-').chomp('-') if title
  end
end
{% endcodeblock %}

上述例子里的 Ruby 语法有点多，要完整解释有点麻烦。
看不懂的读者们（或者对 Mongoid 不了解的）可以先跳过，只要明白这个文件定义了 `Todo` Model就可以了。

接下来就要在主文件 `app.rb` 里引用 Model，然后在路由里操作之：

{% codeblock lang:rb %}
# app.rb
# 省略大量内容..

require './models'

get '/todos' do
  @todos = Todo.all
  @title = "Sinatra Demo || Todos"
  slim :"/todos/index"
end
{% endcodeblock %}

最后是来一个模板 `views/todos/index.slim`

{% codeblock lang:slim %}
h1 Todos
- if @totos.any?
  ul.pages
  - @todos.each do |todo|
    li
      a href="/#{url_for todo}" =todo.title
- else
  p No todos! Yeah!
{% endcodeblock %}

当然，为了完成这个 TODOLIST 的应用，你还需要写 create, delete, edit, ... 这里就不赘述了

## Why the fuck ?

至此为止，一个大致的应用初具雏形。读者们可以在此基础上继续发挥（主要是添加增删改的路由，修改样式）来完成这个应用。

当然，你会发现这样做是一件很操蛋的事情—— Rails 早就做了，而且在构建 **传统的增删查改** 的业务上完爆 Sinatra（以及其他各类框架），
那 Sinatra 的意义何在呢？

就在于当你需要做一些非传统应用（如 API 服务，后台服务，甚至微信公众号时）可以很快的上手，不需要用 Rails 如此庞大的工具。这是 Sinatra 的应用场景。
举个不恰当的例子是：Rails 好比一辆重型坦克，很安全，功能很齐备；而 Sinatra 就像辆小单车一样简陋但好骑。问题只是在于当你希望小单车有诸多功能时，
你需要给它加上大量的组件，还是自己装上去的。说白了就是应用场景不同嘛。~~哪来那么多废话~~

通常来说，在对 Rails 开发有一定了解之后再来学习 Sinatra 会比较好，
毕竟 Rails 的开发能够让开发者对构建 web 应用所需要的各个方面有一个全面的了解；
而且开发 Sinatra 需要的 Ruby 知识也更多，对于开发者个人能力的要求也更高——毕竟 Rails 的全面性和安全性是经过了社区的检验的，
单个开发者通过 Sinatra 写出的功能类似的应用未必能够考虑周全。

即使对于我本人来说，一开始学习 Sinatra 的目的也仅仅是为了学习而已。

## 变成"大"应用：extensions & Padrino

这是之后可能会讲的一个内容。如何控制自己的应用？如何让应用变得模块化？
有没有既能享受 Sinatra 的灵便，但功能上又相对完备（比如能够对接数据库）的框架呢？

前两个问题可以通过 Sinatra 扩展解决；最后一个问题的答案是 Padrino —— 它本身就是汇集了多个 Sinatra 扩展的一个框架。

## 参考资料

1. [Sinatra 中文文档](https://github.com/sinatra/sinatra/blob/master/README.zh.md)
2. [Sinatra 官网](http://www.sinatrarb.com/)
3. [简单介绍Sinatra](https://ruby-china.org/topics/18292)
4. 【深度】[How Sinatra Works](https://ruby-china.org/topics/7921) by Hooopo


  [1]: http://en.wikipedia.org/wiki/Sinatra_(software)#Frameworks_inspired_by_Sinatra
