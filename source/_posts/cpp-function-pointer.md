title: C++学习之函数指针的使用及注意事项
date: 2014-11-18 23:41:36
description: PingHackers | C++学习之函数指针的使用及注意事项 | 在小型的工程代码中，函数指针的出镜率往往是非常小甚至是没有的。然而如果工程的规模比较大，则会发现函数指针会在多处使用。因此掌握函数指针对于每一个C++开发者来说都是一项必须的技能。
tags:
- C++
---
**作者**：左君博

**转载请注明出处，保留原文链接和作者信息**

* * *

##目录

- 背景介绍
- 函数指针基本知识
- 函数指针的注意事项
- 函数指针的用途
- 标准库与函数指针

##背景介绍
和老板聊天中，偶然谈到函数指针，惊觉自己在这方面的能力不足，偶尔以前也听潘炎教授谈到过函数指针的重要性，因此写下这篇博客。

在小型的工程代码中，函数指针的出镜率往往是非常小甚至是没有的。然而如果工程的规模比较大，则会发现函数指针会在多处使用。因此掌握函数指针对于每一个C++开发者来说都是一项必须的技能。

<!-- more -->

##函数指针基本知识

我们通过如下方法声明一个指向特定类型函数的指针：

{% codeblock lang:cpp %}
    void (* fp)(int);                         // pointer to a function
{% endcodeblock %}

要注意的是**括号是不可缺少的**，它表明fp是一个指向返回值为void的函数的指针，而不是返回值为void * 的函数。

函数指针既然是指针，就意味着它可以为空，否则它应该指向一个具有适当类型的函数，下面一段代码揭示了函数指针的使用方法：

{% codeblock lang:cpp %}
    extern int f ( int );

    extern void g ( long );
    
    extern void h (int );

    fp = f ;               //  Wrong! int (*)(int) instead of void (*)(int)
    fp = g ;               //  Wrong! void (*)(long) instead of void (*)(int)
    fp = 0 ;              //  OK
    fp = h ;               //  OK
    fp = &h;              //  OK, assign the address of the function explicitly to fp
{% endcodeblock %}

##函数指针的注意事项

在上面的代码中，前面的三个函数声明很好理解，紧随其后的两行赋值代码会出错——由于类型的不匹配，而接下来的两行代码是简单的赋值，不会出问题。

需要注意的是最后一行代码……**在函数指针中，把一个函数的地址初始化或者赋值给一个指向函数的指针的时候，不需要显式使用&符号取得函数的地址**——编译器是知道隐式获得函数地址的。因此在这种情况下，&操作符是可有可无的，一般来说是省略不用。

同样的，为了调用函数指针所指向的函数，我们也不需要对指针进行解引用，看下面两行代码：

{% codeblock lang:cpp %}
    (* fp)( 12 );           //  explicit dereference
    fp(12 );                //  OK, implicit dereference
{% endcodeblock %}

上面两种都是正确的操作。

对于数据来说，void\* 指针可以指向任何类型的数据。可是对于函数来说，**不存在可以指向任何类型函数的通用指针**。此外值得一提的是，**在一个类中的非静态成员函数的地址并不是一个指针**，因此不可以把一个函数指针指向一个非静态成员函数。这也就是为什么回调函数一般不会写在类里面的原因。

什么？你问我指向成员函数的指针是个什么东西？其实指向类中的指针应该是一个需要深入讨论的问题，这个今天不讨论，改天我找到女朋友了心情好了再写一篇博客^o^。不过大致的来讲可以把指向类中成员的指针视作一个偏移量，指向类中函数成员的指针通常可以被是视为一个包含了信息的结构。解引用又是一个蛋疼的问题，在这里就不讨论了……

##函数指针的用途

函数指针的一种传统的用途是实现回调，也就是我们所说的callback函数（有兴趣的童鞋可以阅读设计模式中的command命令模式来深入了解回调技术）。所谓的一个回调函数就是一个可能的动作，而这个动作在初始化的时候就被设置好来应对将来可能发生的事情。

举个栗子，如果你饿了，那么我们如果希望对自己饿了这个情况作出反应，那么我们可以预先设定好我们的应对情况：

{% codeblock lang:cpp %}
    extern void eatApple ();
    
    inline void eatDumpling ();
    
    void (* HungryAction )() = 0 ;
    
    if ( Hungry ){
         if ( gotKnife )
            HungryAction = eatApple ;
         else
            HungryAction = eatDumpling ;
    }
{% endcodeblock %}

如果我们决定了要执行的动作，那么我们就可以在代码中的另一个部分专注于是否去执行操作以及何时去执行操作了，我们无需关心这个动作到底是吃苹果还是吃饺子：

{% codeblock lang:cpp %}
    if (Hungry ){
         if ( HungryAction )
            HungryAction ();
    }
{% endcodeblock %}

我在上面的函数中特意声明了一个内联函数，这是为了告诉大家，讲一个函数指针指向内联函数是完全合法的。但是，如果通过函数指针调用内联函数不会导致内联调用。这个原理其实很简单，因为编译器是无法在编译期就精确的确定将会调用什么函数的。在上面的例子中，HungryAction可能指向两个函数的任意一个，当然也可能是空的，因此在调用点，编译器只能生成间接非内联的函数调用机器代码。

还有要注意的地方（卧槽你有完没完！）……函数指针可以指向一个重载函数的地址：

{% codeblock lang:cpp %}
    void eatApple ();
    void eatApple (Knife knife );
    HungryAction = eatApple ;
{% endcodeblock %}

那么在不同的候选函数中，函数指针将在被使用的时候挑一个最匹配的。由于我们上面的函数类型是void (*)()，因此选择的是第一个eatApple()函数。

## 标准库与函数指针
曾经看侯捷教授的《STL源码剖析》中看到，在STL标准库中，使用了函数指针用于回调机制的地方不能算少——最突出的就是被set_new_handler用于设置回调。

当new函数无法履行一个内存分配的请求（大部分原因是由于内存不足）时，就会调用到一个回调函数，用于报告此时的错误：

{% codeblock lang:cpp %}
    void begForgiveness ()
    {
        logError ( "I'm Sorry! " );
         throw std :: bad_alloc ();
    }
    
    std ::new_handler oldHandler = std:: set_new_handler ( begForgiveness );
    
    myHouse.add( new girlFriend ( 1000000000 ));
{% endcodeblock %}

吐槽代码你就输了……

BTW，标准类型的名称中的new\_handler实际上就是一个typedef：

{% codeblock lang:cpp %}
    typedef void (*new_handler )();
{% endcodeblock %}

因此，回调函数必须是一个不带参数并且返回void的函数。set\_new\_handler函数会将回调设置为参数，并且返回前一个回调，这也就是所谓的获得当前回调的“回旋式手法”：

{% codeblock lang:cpp %}
    std ::new_handler current = std:: set_new_handler (0 );      //   获取
    std ::set_new_handler ( current );                           //   恢复
{% endcodeblock %}

扯一句题外话，set\_terminate和set\_unexpected也是使用了这种回旋手法……不过还是等到找到第二个女朋友再扯这个话题吧……







