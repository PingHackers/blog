title: PingHackers投稿方式
date: 2014-11-27 19:16:01
---

[PingHackers](http://pinghackers.com/)是一个简单的技术博客。专注于高质量的原创技术博文分享。不定时更新，鼓励原创，鼓励翻译，不转载。欢迎各位大神，大牛，中牛，小牛，不是牛撰写博客投稿，分享技术学习心得和经验。总结自己，帮助他人。

## 文章要求：

1. **软件技术相关，而不仅限于技术**。设计，交互，运营，管理等软件相关领域均欢迎。
2. **使用Markdown格式撰写博文**。严格遵循[Markdown语法](http://daringfireball.net/projects/markdown/syntax)。
3. **文章开头具有描述性段落**。你可以把它叫前言，Preface，介绍等，让读者简单阅读这段文字就可以知道博文描述的概要内容和主要目的。
2. **分节编写，每节具有鲜明突出的重点**。每节内容描述逻辑清晰，节与节之间关系条理分明。
5. **开头有目录，结尾有总结**最佳。

语言风格不限，只要能描述清楚内容，你甚至可以萌萌哒。◕‿◕。 


## 投稿方式：
有两种投稿方式，以发送邮件方式进行投稿，或者使用github项目协作流程。建议对git和github了解的同学使用方式二。

#### 方式一：
用Markdown格式写好文章以后，发送至邮箱 [submit@pinghackers.com](submit@pinghackers.com) 即可。


***


#### 方式二：

**Step 1**：安装NodeJS和Hexo工具依赖

在[NodeJS](http://nodejs.org/)官网上找到适合自己系统的安装方式安装NodeJS开发环境。

PingHackers使用Hexo工具构建，需要安装Hexo依赖，进入终端以后：

    npm install -g hexo

**Step 2**： fork & clone

fork这个仓库：https://github.com/PingHackers/blog  ，并且clone到本地。

**Step 3**：初始化开发环境

在终端中进入clone下来的工程目录以后，按照以下指引执行命令。

windows用户：

    init

Linux/Unix用户：

    make init

**Step 4**：新建博文

在终端进入工程目录后，采用以下命令新建markdown文件： 

    hexo n post <post-name>
    
上面的`<post-name>`为你的新的博客文件的命名（不是博客题目，而是文件名），使用英文。该命令`会在source/_posts`目录下新建一个命名为`<post-name>.md`的markdown，这就是你需要编写的文章的地方。

**Step 5**：开启本地服务器，编写、预览博文


开启本地服务器：

windows用户：

    dev
    
Linux/Unix用户：
    
    make dev

修改上一步创建的文件进行文章撰写，在浏览器中打开`localhost:4000`进行预览。

**Step 6**：提交文章到github

    git add -A 
    git commit -m "add new post: <post-name>"
    git push origin master

**Step 7**：给原仓库发送Pull Request

在github上给原仓库发送Pull Reqest。管理员会对文章进行Review，给出修改意见。没有问题管理员会对Pull Request进行Merge，然后发布到PingHackers博客上。


***

### 方式二的简化方式：

 ( 感谢[@allenfantasy](https://github.com/allenfantasy)提供的简化方式）

1. fork博客仓库（ https://github.com/PingHackers/blog ）到自己github上。
2. 在github页面进入自己仓库的source/_posts，按`+`新建一个文件，并命名。
3. 在github网页markdown编辑器编辑新建的文件，撰写博文。
4. 保存、提交。
5. 给原仓库发送Pull Request。
