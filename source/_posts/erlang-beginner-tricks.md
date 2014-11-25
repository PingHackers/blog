title: Erlang初学者技巧及避免的陷阱
date: 2014-11-24 23:41:36
description: PingHackers |  Erlang 初学者技巧及避免的陷阱 | Erlang对于大多数同学来说都是相对较陌生的语言，因为其函数式特性以及语法内置并发，很多传统语言的经验无法应用到Erlang上。笔者便稍微小结一下部分初学者容易遇到的坑或疑惑。

tags:
- erlang
---
**作者**：吴文杰

**原文链接**：[http://pinghackers.com/2014/11/24/erlang-beginner-tricks/](http://pinghackers.com/2014/11/24/erlang-beginner-tricks/)

**本文同时也发布在**：[http://www.cnblogs.com/lhfcws/p/4116507.html](http://www.cnblogs.com/lhfcws/p/4116507.html)

**转载请注明出处，保留原文链接和作者信息**

* * *

### 目录
1. 传参或在匿名函数内慎用self()
2. Message Passing支持发送Socket、文件句柄等对象引用消息
3. 在不需追踪函数状态的时候，尽量使用尾递归
4. 动态创建原子要十分谨慎
5. 巧用原子作模式匹配
6. 特殊字符使用$开头，如$\n。
7. 大型数据慎用消息传递，有必要可考虑ETS表做进程共享
8. 跨机器间的进程消息发送要小心，小型消息频率过高TCP头部的发送代价也高。
9. 函数传参记得参数相对应
10. 列表操作要谨慎

### 前言
Erlang对于大多数同学来说都是相对较陌生的语言，因为其函数式特性以及语法内置并发，很多传统语言的经验无法应用到Erlang上。笔者便稍微小结一下部分初学者容易遇到的坑或疑惑。

#### 1. 传参或在匿名函数内慎用self()

通常在做消息传递或新建进程的时候我们需要将当前进程的Pid发给目标进程以便接收返回信息，但初学者不留意容易犯以下错误

{% codeblock lang:erlang %}
	spawn(fun() ->
    	loop(self(), gen_tcp:accpet(...))
	end).
{% endcodeblock %}	

fun这段代码在本进程内是不会预先执行的，代码会原封不动传给目标进程。当实际调用self()的时候，获取的实际不是本进程的Pid了。

所以建议当需要传递当前进程Pid或者其他当前进程类似函数的时候，先求值再传递。保持良好习惯就可以避免类似的坑。

{% codeblock lang:erlang %}
	Pid = self(),
	Socket = gen_tcp:accpet(...),
	spawn(fun() -> 
    	loop(Pid, Socket)
	end).
{% endcodeblock %}
 

<!-- more --> 

 

#### 2. Message Passing支持发送Socket、文件句柄等对象引用消息

稍微了解Erlang的同学都知道Erlang消息传递目标进程接收的实际是发送进程消息的一个拷贝副本，对于存储类数据这个没有问题。

当对于Socket，FileHandler这类对象的时候，事实上也是可以传递并能起到预期效果的。

（以下Demo代码来自Erlang的Mailing List）

 
{% codeblock lang:erlang %}
	%This is an example of how trivial writing a FTP-like client in Erlang.

	%On machine 1. 
	File = file:open(FileName, [read]).
	PidOfProcessOnMachine2 ! {remote_file, File}.

	%On machine 2.
	receive
	    {remote_file, File} ->
	       {ok, Data} = file:read(File, 1000000),
	       write_to_local_disk(Data)
	end.
{% endcodeblock %} 

#### 3. 在不需追踪函数状态的时候，尽量使用尾递归

众所周知，Erlang是没有循环结构的，我们要想实现循环基本是靠递归实现的。但又众所周知，函数递归是要不停压栈的，我们要想实现 while(true)怎么办？

答案就是尾递归，许多这类语言都已在编译器层面实现了尾递归优化，在编译器识别出尾递归后，编译器会直接丢掉当前函数状态信息变成做跳转，这里汇编层面其实就和循环结构很类似了。

但尾递归也有个缺点，就是函数状态没法保留了，所以有时候复杂情况需要追踪调试函数栈状态的时候就不能用尾递归。但其实在Erlang这类函数式语言里，尾递归大多数情况是用来实现循环，所以实际上也不需要留意函数栈。

 

 

#### 4. 动态创建原子要十分谨慎

Erlang里有一种特殊的结构叫做原子（atom），一般用来做类似传统语言里的常量作用或用来辅助模式匹配。

Erlang默认有几百万个内置原子，但是Erlang除非整个VM退出了，否则是不会对任何原子做GC的。

所以有时候我们为了匹配会使用 list_to_atom 函数去动态创建原子，但这是很危险的，甚至有可能导致内存泄露。

所以除非你自己很清醒自己的所作所为并且考虑到别人对你代码的调用情况，否则尽量不要动态创建原子。

但静态创建原子是没问题的，毕竟你手动打的数目总是极其有限，比如：

{% codeblock lang:erlang %}
	receive
    	{my_own_atom, Var} -> pass.
	end.
{% endcodeblock %}	
	
但谨慎出现以下代码：

{% codeblock lang:erlang %}
	% On machine 1

	Type = recv(),
	Msg = recv(),
	Machine2 ! {list_to_atom(Type), Msg}.



	% On machine 2

	receive
    	{type1, Msg} -> pass;
	    {type2, Msg} -> pass
	end.
{% endcodeblock %}	

这里的Type很容易成为受攻击的对象。

 

 

#### 5. 巧用原子作模式匹配

经常我们要解析协议或者匹配同等元素个数的元组列表，这时候可以用原子来进行区分实现模式匹配。

{% codeblock lang:erlang %}
	% Receiver
	Packet = recv(Socket),    % Get TCP Packet

	case Packet of
    	[new_user, "||", Username] ->
	        pass;
    	[new_board, "||"] ->
        	pass.
	end.

	% Sender

	send([new_user, "||", Username]).
{% endcodeblock %} 

 

#### 6. 特殊字符使用$开头，如$\n。

这个没什么好说，有需要去查看对应手册。

{% codeblock lang:erlang %}
	Line = io:get_line("Input: "),
	S = string:strip(Line, both, $\n).
{% endcodeblock %} 

 

#### 7. 大型数据慎用消息传递，有必要可考虑ETS表做进程共享

Erlang有个口号叫“小消息 大计算”，所以使用Erlang期望传递的消息本来就是小消息。但我们经常也不可避免需要进程间共享一些大消息，这时候我们可以考虑从借助进程字典或ETS表。但其实Erlang的这种进程间只能通过MP通信的机制也逼迫我们在设计程序时要求每个进程的角色分工很明确。

 

 

#### 8. 跨机器间的进程消息发送要小心，小型消息频率过高TCP头部的发送代价也高。

这个其实还是见仁见智，根据实际业务情况而定。如果真的是因为TCP消耗引起的性能问题，就要考虑本地开个进程做代理，缓存一定的消息，定时批量发送。其实就是做个缓存队列。

可参见此文：[Erlang中频繁发送远程消息要注意的问题](http://avindev.iteye.com/blog/76373)

 

 

#### 9. 函数传参记得参数相对应

这个没啥好说的，直接看代码。尽管fun匿名函数处理不需要参数，但for_内的F是个一元函数，所以也要至少用个_匹配符去代表那里有个参数。Erlang有另一种元调用方式apply（有点像JavaScript），apply传参是用个列表Args = [...]，适用于较灵活的一些调用，比如spawn，但这种反射式调用一般效率都会较低，Erlang的apply据说比本地直接调用F()要慢上6 - 10倍。

{% codeblock lang:erlang %}
	for_(I, Max, F) ->
	  	case I == Max of
    		false -> [F(I) | for_(I + 1, Max, F)];
		    true -> [F(Max)]
		end.


	for_(0, 5, fun(_) ->
    	io:write("Hello Erlang")
	end).
{% endcodeblock %} 

 

#### 10. 列表操作要谨慎

很多有其他类函数式语言（Python、Coffee等）经历的同学会很喜欢列表结构，但是Erlang的列表相对比较不同。

首先，Erlang的所有“变量”都是不可变也不可二次绑定的，所以想像Python那样自由操作list是不可能的，必须每次修改返回一个新变量。

 

列表右侧增长： 

{% codeblock lang:erlang %}
	[1,2,3] ++ [4,5] = [1,2,3,4,5],   
	"Hello" ++ " " ++ "Erlang" = "Hello Erlang"
{% endcodeblock %}

++其实是lists:append/2的syntax sugar，切记和动态创建原子一样，可偶尔为之，但不要放任列表动态右侧增长。++会复制左边的元素，会使复制多次，最后导致平方倍的复杂度。

 

列表左侧增长：

{% codeblock lang:erlang %}
	[1,2,3 | [4,5]] = [1,2,3,4,5]
{% endcodeblock %}

不要和 [[1,2,3] | [4,5]] = [[1,2,3],4,5] 搞混。

 

列表length方法是O(N)时间复杂度，慎用length(List)，很多需求可以用模式匹配实现。

{% codeblock lang:erlang %}
	case List of
    	[Elem | _] -> process(Elem);
	    [] -> processEmptyList() 
	end.
{% endcodeblock %}
	
但是元组和二进制串的size方法却是O(1)的，可放心使用。

