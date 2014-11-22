title: C++学习之RAII编程思想
date: 2014-11-16 23:27:39
description: PingHackers | C++学习之RAII编程思想 | 在C++程序运行的过程中免不了要进行资源的分配——尤其是在游戏中！资源可以有很多种，从纹理、声音、着色器代码到句柄、字符串这些东西都可以被称为资源。资源的管理是项目中很重要的一轮，做得不好的话轻则内存泄漏、重则内存崩溃。RAII则是在C++项目中用于资源管理的一种重要的编程思想。
tags:
- C++
- game
- RAII
---
**作者**：左君博

**转载请注明出处，保留原文链接和作者信息**

* * *

## 目录
- 背景介绍
- 先说一点C++
- 总体概念
    - 举个RAII栗子
    - 实际操作之反栗 
    - 实际操作之正栗

## 背景介绍
在C++程序运行的过程中免不了要进行资源的分配——尤其是在游戏中！资源可以有很多种，从纹理、声音、着色器代码到句柄、字符串这些东西都可以被称为资源。资源的管理是项目中很重要的一轮，做得不好的话轻则内存泄漏、重则内存崩溃。RAII则是在C++项目中用于资源管理的一种重要的编程思想。

<!-- more -->

## 先说一点C++
C++中不可或缺的东西就是class，而每个class不可或缺的就是构造函数和析构函数。前者用于对象被构造时进行的一系列操作，后者用于对象被析构时所执行的函数。

而值得一提的是，在C++中，如果一个类被声明在栈空间，则在该函数执行完毕从栈空间弹出之后，类会自动调用析构函数。可是如果被显示声明在堆空间（使用new方法或者malloc方法），则需要显式调用析构函数才能进行析构。

以上就是要读懂本篇博客所需要的C++知识，应该不难吧……

## 总体概念
C++有很多很奇葩的名字，比如yacc，raii等，这算是一种悠久而自豪的传统吧2333333。

RAII是一个很典型的例子，它表示的是“资源获取即初始化”(Resource Aquisition Is Initialization)，而不是某些人认为的“初始化即资源获取”(Initialization is resource acquisition)。BTW，如果想搞怪，就怪到底吧，不然达不到效果。

RAII的技术很简单，利用C++对象生命周期的概念来控制程序的资源。它的技术原理很简单，如果希望对某个重要资源进行跟踪，那么创建一个对象，并将资源的生命周期和对象的生命周期相关联。这样一来C++自带的对象管理设施就可以来管理资源了。

### 举个RAII栗子

最简单的形式：创建一个对象，让她的构造函数获取一份资源，而析构函数则释放这个资源：

{% codeblock lang:cpp %}
    class Resource{...};
    class ResourceHandle{
        public:
             // get resource
             explicit ResourceHandle(ResourceHandle *aResource ): r_(aResource){}
            
             // release resource
             ~ResourceHandle()
             {
                 delete r_;
             }
            
             // get access to resource
            Resource *get()
             {
                 return r_;
             }
            
        private:
             // make sure it can not be copied by others
            ResourceHandle (const ResourceHandle &);
            ResourceHandle & operator = (const ResourceHandle &);
            Resource *r_;
    };
{% endcodeblock %}

ResourceHandle对象的最好的地方就是：如果它被声明为一个函数的局部变量，或者作为一个参数，或者静态变量，我们都可以保证析构函数得到调用了。这样一来就可以释放对象所引用的资源。

### 实际操作之反栗

我们看看一个没有使用RAII的简单代码：

{% codeblock lang:cpp %}
    void f() {
    
        Resource *rh = new Resource;
    
    
        //...
        if (blahblah())
             return ;
            
        //...
        g();         //catch the exceptions
        
        // Can we make sure that it can be processed here?
        delete rh ;
    }
{% endcodeblock %}

就如同我在注释中的一样，可能一开始的时候上面那段代码是安全的，rh的资源总是可以被释放。

但是如果经历了一些维护呢？比如说上面的g()函数，有可能会造成函数的提前返回，所以就有可能运行不到最后一句释放资源的代码了，因此这段代码是危险的。

### 实际操作之正栗

那么如果使用RAII的话呢？代码如下：

{% codeblock lang:cpp %}
    void f() {
    
        ResourceHandle rh (new Resource );
        
        //Definitely ok
        if (blahblah())
             return ;
        
        //catch an exception? Go ahead!
        g();
        
        //finally the resource would be released by c++ itself.
    }
{% endcodeblock %}

这样一来RAII就使得代码就更加健壮了，因为只要是函数返回了，无论是通过何种途径，那么在返回的时候析构函数就会自动释放资源。

使用RAII只有一种情况无法保证析构函数得到调用，就是当ResourceHandle被动态分配到堆空间上了，这样一来就只能显示得调用delete ResourceHandle对象才能保证资源释放了，比如下面的代码：

{% codeblock lang:cpp %}
    ResourceHandle *rhp = new ResourceHandle(new Resource);    
{% endcodeblock %}

那么此时就蛋疼了，因为动态分配的东西需要显示调用delete才能释放，所以上面的做法通常是危险的做法。安全的做法是将RAII的handle分配到栈空间去，此时就能够确保安全。

（全文完）
