title: Erlang error handling
date: 2014-11-25 14:47:36
description: PingHackers |  Erlang error handling
tags:
- erlang
---
**作者**：吴文杰

**原文链接**：[http://pinghackers.com/2014/11/25/erlang-error-handling/](http://pinghackers.com/2014/11/25/erlang-error-handling/)

**本文同时也发布在**：[http://www.cnblogs.com/lhfcws/p/4120965.html](http://www.cnblogs.com/lhfcws/p/4120965.html)

**转载请注明出处，保留原文链接和作者信息**

* * *


## Contents
0. Preface
1. try-catch
2. Process link
3. Erlang-way error handling
4. OTP supervisor tree
5. Restart process

----

### 0. Preface
说到容错处理，大概大家都会想到 `try-catch` 类结构，对于绝大多数传统语言来说，确实是这样。但是对于Erlang来说，容错处理是其一个核心特性，真正涉及到的是整个系统的设计，与 `try-catch` 无关；其核心是Erlang进程本身的特性以及进程链接。

### 1. try-catch
> 本节纯粹为科普

不管怎么说，还是先介绍以下Erlang的 try-catch 结构（但请留意，try-catch 只作为引入，此小节以后的章节才是本文核心）。

Erlang 有三种错误类型：

+ error: 运行时异常，比如零除错误、匹配错误等。一旦Error使某个进程崩溃，Erlang错误日志管理器会进行记录。
+ exit: 进程停止异常，Exit会在迫使进程崩溃的同时将进程退出的原因告诉其他进程，一般不建议对Exit作捕获。同时Exit也可在进程正常终止时使用。Erlang错误日志管理器不会接收到Exit的异常汇报。
+ throw: 和Java的Throwable较类似，大多用于用户自己throw出异常到上层函数。如果没有catch的话就会变成原因为nocatch的error，迫使进程停止并记录异常。这里有个trap，如果你用了尾递归优化的函数，throw后是只有一层stack的。

关于尾递归的 throw，建议测试以下代码：

	tail_throw(I) ->
	  if
	    I =< 0 ->
    	  throw(erlang:get_stacktrace());
	    I > 0 ->
    	  io:format("tail~n"),
	      tail_throw(I - 1)
    	  ,io:write("~n")   % try delete this line to see the differences
	  end
	.

#### try_catch

	try
		do_stuff()
	catch
		throw: Other -> {get_throw, Other};
		error: Reason -> {get_error, Reason};
		exit: Reason -> {get_exit, Reason}
	end.
	
#### try_of_catch
try_of 可以对返回结果进行模式匹配，相当于`case func() of`的语法糖。


	try
		do_stuff_return()
	of
		0 -> pass;
		Result -> pass
	catch
		throw: Other -> {get_throw, Other};
		error: Reason -> {get_error, Reason};
		exit: Reason -> {get_exit, Reason}
	end.

#### after
after相当于Java的finally。

	try
		do_stuff()
	catch
		throw: Other -> {get_throw, Other};
		error: Reason -> {get_error, Reason};
		exit: Reason -> {get_exit, Reason}
	after
		clean()
	end.
	
### 2. Process link
> 本节为预备知识

Erlang process之间有个重要的关系叫link，请记住，这是一个双向的关系。有时开玩笑会说，不link则已，一link则挂。

当两个进程link起来后，其中一方进程崩溃了产生 exit 信号，这个 exit 会被另一方进程 trap 住，然后一同挂掉。当然，有的进程trap 到了 exit 信号不一定打算同归于尽，他可以去做其他事情比如汇报异常、重启挂掉的进程等，这种进程的角色叫做supervisor，后面会提到。



link 一般有两种方式：

	link(PidOrPort) -> true
	% Types: PidOrPort = pid() | port()

Creates a link between the calling process and another process (or port) PidOrPort, 	if there is not such a link already. If a process attempts to create 	a link to itself, nothing is done. Returns true.

或者：

	% Fun : function()
	% Node: node()
	% Module = module()
	% Args = [term()]
	spawn_link(Fun) -> pid(),
	spawn_link(Node, Fun) -> pid(),
	spawn_link(Module, Function, Args) -> pid(),
	spawn_link(Node, Module, Function, Args) -> pid().

	
### 3. Erlang-way error handling
> 本节及之后为核心内容

我们先来看一段来自 Erlang Mailing List 2014.11.24 的邮件原文：

> The try-catch syntax was deliberately chosen to be reminiscent of
Java, the idea being that if you understood this try-catch consequence
in Java you'd easily understand the Erlang code.

> The problem I see with this is that programmers with previous
experience in Java are tempted to blindly convert sequential try-catch
code in Java into sequential try-catch code in Erlang, but this is
almost always the wrong thing to do.

> Beginners should be forbidden to use try-catch - the Erlang "way" is
to spawn_link a regular process (ie a process that does not trap
exits) and just let that process die if anything goes wrong. There
should be no error trapping code in the spawned process. Call
exit(Why) in every place where the behaviour is unspecified.

> ---- By Joe Armstrong

Joe Armstrong何许人也，据说他的简历只需要三个词 —— I wrote Erlang。

Joe 极力劝告大家不要使用try-catch结构来做错误处理，其实文中forbidden一词稍有点极端，在某些譬如做socket或做io的时候可能需要一些失败后的收尾工作，这时还是要借助catch。但是catch后最后还是建议让进程fail掉，因为那才是Erlang-way的容错处理，也就是Actor模式中常讲的“Let it crash”。

crash后的进一步错误处理就依靠上节提到的进程链接。那么这种同归于尽式的link有什么好处呢？通过link我们实际可以构建出一组进程（其实就是构建了一颗双向连通的进程树型结构），该组进程里的任一进程挂掉都会使整组进程挂掉。实际上这就是控制了错误的传播。在很多时候，某个进程计算出错了，相关的进程的状态其实也是有问题的，与其在每一步都去思考出错的可能情况去catch做处理，还不如挂掉重启，反正你跑下去也是有问题的。再者，Erlang的设计本来就是不停地新建进程和销毁进程，每一个小型任务可以的话一般都会分出去新建进程去跑。Erlang进程不同于OS级别的进程线程，调度开销很低。因此，Erlang社区的开发者都会建议你通过link来传播进程的exit信号，从而实现容错处理。

Erlang 里还有个术语叫做 error kernel，指的是整个系统程序里决不能出错的核心部分（一出错整个系统就完蛋，没有挽救机会的那种）。error kernel的要求是规模尽可能小，并且发布后默认是可信任的；其他一些计算类任务都要尽可能从error kernel剥离。因此，error kernel占系统的比例大小是评估整个系统Erlang实现的鲁棒性的重要标准。

有一种形象化的比喻：把整个系统看做一个个方格拼成的广场，error kernel部分的方格是红色的。还有一些比如起顶端supervisor角色作用的模块，或一些可能出严重错误但还未严重到使系统崩溃的模块进程，它们也被标成红色的。其他允许挂掉的进程我们标为白色。Erlang系统的鲁棒性的一个形象体现就在于红色方块越少，系统越健壮。

### 4. OTP supervisor tree
上文我们反复提到一个词叫做supervisor，中文叫监管者/监督者。我们所创建的Erlang process一般有两种，supervisor和worker。worker很简单，就是实际执行任务的进程。supervisor的职责有：监控子进程状态并在其挂掉后做错误处理、exit信号隔离以及重启策略。

OTP给Erlang带来了很多特性，其中一个非常重要的是supervisor tree监管树。

![image](http://images.cnitblog.com/blog/527700/201411/251430414967138.png)

如图所示，在 Process link 一节中曾提到多个进程link成一个树形结构的进程组，便是图中的一棵子树。supervisor下的某个子树挂了，不会影响到其他无关的进程组，同时supervisor还可以帮助重启。supervisor也可以监管supervisor形成多级监管。总而言之有如下特性：

1. 子进程受父进程监管，其退出信号会传递给父进程。
2. 父进程收到子进程的退出信号时，可以决定是将信号继续传递还是自行处理。
3. 父进程若决定自行处理则会按照配置的重启策略去重启子进程。

OTP提供的默认 behaviour 中就有 supervisor，让用户很方便的去实现基本的 supervisor 进程。OTP允许监督者按预设的方式和次序来启动进程。用户还可以告知监督者如何在单个进程故障时重启其他进程、一段时间内尝试重启多少次后放弃重启等。

### 5. Restart process
我们一直在强调要重启进程，但是重启我们就不得不面对一个问题，旧进程的状态怎么办？正所谓一个计算过程或函数一般都需要输入才能有输出，重启后输入怎么办？

这里我们要将进程内的状态分为三种来考虑：

1. Internal State，又叫 Stack State。就是一些临时变量或存储在栈上的内容。这部分状态我们实际是不期望保留的，一般最多用来做点错误追踪，因为同样的栈再去跑还是同样的错误。
2. Static State，或 Global State。这里比较类似Java里的一些常量、静态变量等，比如像TCP的端口地址配置之类的。这部分状态应该是做好配置存储的，比如放到ETS里，一般全局存储后可以轻易拿回。
3. Dynamic State。比如说一些计算结果或用户输入。计算结果还好，只要可以重计算的问题都不大。比较麻烦的是像用户输入一类的没办法轻易取回的数据，总不能叫用户再输入一次吧。这部分数据状态就需要开发者自己比较小心。在识别出该进程可能挂掉会丢失该类数据后，如果有需要应该将其进行一定的缓存，这样重启时也可以去找回，等到计算结束后再清除缓存。
