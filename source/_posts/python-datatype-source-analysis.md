title: Python2 基本数据结构源码解析
date: 2014-12-11 00:05:00
description: PingHackers |  Python2 基本数据结构源码解析 | 一切皆对象，这是Python很重要的一个思想之一，虽然在语法解析上有些细节还是不够完全对象化，但在底层源码里，这个思想还是贯穿全系统的。（举个例子，`dir(2)` Python 可以识别出这是一个整型对象并打印出操作方法，但实际你却没办法 `2.real` 去调用，但 Ruby 却支持 `3.step(1, 2)`。）
tags:
- python
---
**作者**：吴文杰

**原文链接**：[http://pinghackers.com/2014/12/11/python-datatype-source-analysis/](http://pinghackers.com/2014/12/12/python-datatype-source-analysis/)

**本文同时也发布在**：[http://www.cnblogs.com/lhfcws/p/4156635.html](http://www.cnblogs.com/lhfcws/p/4156635.html)

**转载请注明出处，保留原文链接和作者信息**

* * *

### Contents
+ 0x00. Preface
+ 0x01. PyObject
+ 0x01. PyIntObject
+ 0x02. PyFloatObject
+ 0x04. PyStringObject
+ 0x05. PyListObject
+ 0x06. PyDictObject
+ 0x07. PyLongObject


### 0x00. Preface
一切皆对象，这是Python很重要的一个思想之一，虽然在语法解析上有些细节还是不够完全对象化，但在底层源码里，这个思想还是贯穿全系统的。（举个例子，`dir(2)` Python 可以识别出这是一个整型对象并打印出操作方法，但实际你却没办法 `2.real` 去调用，但 Ruby 却支持 `3.step(1, 2)`。）

**Version: 本文中所展示的源码及研究对象均来源自Python2最新版本（截止2014.12.01） Python 2.7.8。**

**Reference：《Python 源码剖析》 （陈儒），基于 Python2.5。在此基础上添补了一些内容和个人总结拓展，并结合Python 2.7.8的源码检查一遍，确认核心并未有较大变动。**

**本文假定读者至少能看懂C语言利用内存对齐技巧来模拟的结构体继承和多态，C语言的define和typedef的使用。**

### 0x01. PyObject

Python 源码里有个基本的随处可见的核心对象 PyObject，在源码里的地位和作用基本相当于 Java 里的所有类的超类 Object ，其定义如下：

```cpp
    /* PyObject_HEAD defines the initial segment of every PyObject. */
    #define PyObject_HEAD                   \
        Py_ssize_t ob_refcnt;               \
        struct _typeobject *ob_type;
        
    typedef struct _object {
        PyObject_HEAD
    } PyObject;
```     

（其实还有一行 _PyObject_HEAD_EXTRA 用于调试，但release版本中通常为空）

可见 PyObject 就两个成员，ob_refcnt 用于引用计数，ob_type用于指定当前 PyObject 的实际类型。引用计数是很多有自动垃圾回收机制的高级语言的GC的基础，这里不多赘述；_typeobject 结构体内容也比较复杂，暂时只需要知道用来描述对象类型即可。PyObject实际就这么多内容了。

Python里的对象主要分两种，定长对象和变长对象。**这里强烈建议留意定长和变长的定义，网上有很多误导的错误解释。**  

定长对象指对象在构造时便可知道长度的对象，包括int，float，bool，complex和dict等。其中比较特殊的是dict，dict的头部虽然是定长对象，但实际整个对象所占的大小也是会变的，不然新元素怎么办~dict采取的是类似数据库中可拓展哈希的方法进行增长，下文再细说。定长对象不需要特殊代码，PyObject 默认就是定长。

变长对象则在构造前是不知道长度的，包括long，str，list，tuple。long 这里和cpp里的长整型不一样，Python的long是用来支持大数运算的，上限取决于你的内存有多大，在你构造之前你怎么知道用户输入的那个数有多大，因此是个变长对象。变长对象的头部定义如下

```cpp
    #define PyObject_VAR_HEAD               \
        PyObject_HEAD                       \
        Py_ssize_t ob_size;

    typedef struct {
        PyObject_VAR_HEAD
    } PyVarObject;
```

其实就是多了个 ob_size 来表示对象的大小。

<!--more-->

### 0x02. PyIntObject

```cpp
    typedef struct {
        PyObject_HEAD
        long ob_ival;
    } PyIntObject;
```

非常简单，Python的int就相当于C里的long，维护的时候大多数实际就是在维护long的值，除了类型转换的情况，比如相加相乘溢出的时候会自动转成PyLongObject。PyIntObject是不可变对象，即不可修改，只能创建删除读取。不可变对象的好处其实不用多说，共享并发时不需考虑锁冲突等开销，如今很多语言都在支持这种从函数式来的特性。

PyIntObject最特别的一点是区分大小整数，小整数全部事先创建好放在一个小整数对象池中，大整数则轮流共享一块内存。大小整数的判断是配置决定的，也就是说用户实际可以通过修改该值来进行调整。小整数对象池存在的原因是Python设计者认为像0 1 100 等这些小整数我们经常会几乎不可避免在各种地方用到，比如for、做flag值、计数器等，因此重复去创建销毁这些对象累积起来的开销实在没必要。

```cpp
    #ifndef NSMALLPOSINTS
    #define NSMALLPOSINTS           257
    #endif
    
    #ifndef NSMALLNEGINTS
    #define NSMALLNEGINTS           5
    #endif
    
    #if NSMALLNEGINTS + NSMALLPOSINTS > 0
    /* References to small integers are saved in this array so that they
       can be shared.
       The integers that are saved are those in the range
       -NSMALLNEGINTS (inclusive) to NSMALLPOSINTS (not inclusive).
    */
    static PyIntObject *small_ints[NSMALLNEGINTS + NSMALLPOSINTS];
    #endif
```
    
上述代码便是小整数池的声明，small_ints数组便是存放小整数的地方，小整数的范围默认是 [-5, 257) 。至于大整数，请看以下代码（留意我加的//注释）：

```cpp
    // Linklist member incapsulation
    struct _intblock {
        struct _intblock *next;
        PyIntObject objects[N_INTOBJECTS];
    };

    typedef struct _intblock PyIntBlock;

    static PyIntBlock *block_list = NULL;
    static PyIntObject *free_list = NULL;

    static PyIntObject *
    fill_free_list(void)
    {
        PyIntObject *p, *q;
        /* Python's object allocator isn't appropriate for large blocks. */
        // Initialize a PyIntBlock
        p = (PyIntObject *) PyMem_MALLOC(sizeof(PyIntBlock));
        
        // Init failed due to not enough memory
        if (p == NULL)
            return (PyIntObject *) PyErr_NoMemory();
            
        // Add p to the head of block_list
        ((PyIntBlock *)p)->next = block_list;
        // Set block_list head to p
        block_list = (PyIntBlock *)p;
        
        /* Link the int objects together, from rear to front, then return
           the address of the last int object in the block. */
        // use ob_type to link the objects aray
        p = &((PyIntBlock *)p)->objects[0];
        q = p + N_INTOBJECTS;
        while (--q > p)
            Py_TYPE(q) = (struct _typeobject *)(q-1);
        Py_TYPE(q) = NULL;
        return p + N_INTOBJECTS - 1;
    }
```
    
上面代码中可以看到有一个比较丑陋的地方是用说好要当做类型描述的ob_type来充当next指针。最后fill_free_list返回的结果其实就是传递给了free_list变量，这时候free_list指向了objects链表的头部（即数组的尾部）。block_list是负责维护实际的对象池，和free_list则负责维护block_list中空闲的对象。换句话说，只要block_list当前的objects内有空闲的对象，则free_list不会为NULL，必然会指向某个空闲的对象（一般是最近被释放的对象）；当free_list为NULL，说明目前没有空对象了，则要调用fill_free_list方法。

free_list维护的实际是所有空闲的block，假如没有销毁，free_list默认指向新申请的连续空闲block的头部，通过fill_free_list中构建好的链表关系可以轻易地（O(1)）找到下一个空闲block；当有之前使用的block被销毁的时候，python会将该block加到free_list头部并使之成为新的链表头部，该block的ob_type（此处充当next指针）自然也就改成了旧的free_list。因此销毁代码如下：

```cpp
    static void
    int_dealloc(PyIntObject *v)
    {
        if (PyInt_CheckExact(v)) {
            Py_TYPE(v) = (struct _typeobject *)free_list;
            free_list = v;
        }
        else
            Py_TYPE(v)->tp_free((PyObject *)v);
    }

    static void
    int_free(PyIntObject *v)
    {
        Py_TYPE(v) = (struct _typeobject *)free_list;
        free_list = v;
    }
```

### 0x02. PyFloatObject

```cpp
    typedef struct {
        PyObject_HEAD
        double ob_fval;
    } PyFloatObject;
```

和 PyIntObject 很类似，实际维护的是一个C里的double值。它的机制和PyIntObject的大整数机制也基本一致，但没有小整数池，因为浮点数毕竟没有小整数那么常用，也很难界定哪些浮点数是较常用的。基本fill_free_list函数和销毁等实现都差不多，就不再重复列举代码。

总之底层实现核心区别就是一个没有小整数池，另一个没有溢出类型转换。因此你即使输一个很大的小数，她也会丢弃部分数位或使用e表达方式使之适应成一个double类型。

### 0x03. PyStringObject

```cpp
    typedef struct {
        PyObject_VAR_HEAD
        long ob_shash;
        int ob_sstate;
        char ob_sval[1];

        /* Invariants:
         *     ob_sval contains space for 'ob_size+1' elements.
         *     ob_sval[ob_size] == 0.
         *     ob_shash is the hash of the string or -1 if not computed yet.
         *     ob_sstate != 0 iff the string object is in stringobject.c's
         *       'interned' dictionary; in this case the two references
         *       from 'interned' to this object are *not counted* in ob_refcnt.
         */
    } PyStringObject;
```
    
PyStringObject是个变长对象但是也是个不可变对象。字段解释如下：

+ ob_shash : 长整型哈希值，就是字符串通过位运算算出来的哈希值，有兴趣的同学可以去了解字符串哈希相关知识。
+ ob_sstate : 实际是个enum值，用来判断当前字符传对象是否intern共享（intern机制下文会描述）。
+ ob_sval : 字符串实际内容存放处，字符串第一位的头指针；其中长度并不是C中的\0决定，而是由PyObject_VAR_HEAD 中的 ob_size决定的；但其同样必须满足 ob_sval[ob_size] == '\0'。

Intern 是一个共享机制，对象是size <= 1 的短字符串，主要是为了节省字符串所占的空间。比如我有N个对象的值都是"Python"，对象自然是需要N个，但其实没必要将"Python"也复制N个。以下是intern的核心函数代码（为方便阅读，省略去了一些检查代码）：

```cpp
    void
    PyString_InternInPlace(PyObject **p)
    {
        register PyStringObject *s = (PyStringObject *)(*p);
        PyObject *t;
        
        // interned表（dict对象）不存在则新建
        if (interned == NULL) {
            interned = PyDict_New();
            if (interned == NULL) {
                PyErr_Clear(); /* Don't leave an exception */
                return;
            }
        }
        
        // 查看该字符串的内容是否已被interned
        t = PyDict_GetItem(interned, (PyObject *)s);
        // 若已interned则修改其引用计数，并将p指向t
        if (t) {
            Py_INCREF(t);
            Py_DECREF(*p);
            *p = t;
            return;
        }

        // intern操作，将字符串尝试存入interned表中
        if (PyDict_SetItem(interned, (PyObject *)s, (PyObject *)s) < 0) {
            PyErr_Clear();
            return;
        }
        
        /* The two references in interned are not counted by refcnt.
            The string deallocator will take care of this */
        Py_REFCNT(s) -= 2;
        PyString_CHECK_INTERNED(s) = SSTATE_INTERNED_MORTAL;
    }
```

首先，很容易看出，interned变量其实是一个`dict<PyObject *, PyObject *>`对象。dict会将key转换为PyStringObject* 并使用其ob_shash值来做哈希，上文虽然没有将计算ob_shash的函数string_hash展示出来，但大家也很容易猜到，ob_shash计算仅与字符串实际内容有关，和PyObject无关，因此同样字符串即使对象不同它们的哈希值也是一样的。

这里还有一个trick可能比较绕的是引用计数，尤其是后面`Py_REFCNT(s) -= 2`有些莫名其妙。先看if (t)那块代码，若找到已经被interned过，t是之前第一个interned同样字符串的对象，p是当前想要intern的对象，那么p的当前引用计数减一，而interned的t对象引用计数加一。再结合倒数三四行的作者注释，很容易明白如果PyStringObject被interned了，那么这个时候与intern有关的引用计数不看refcnt了，而是要结合intern去计算实际引用值。`Py_REFCNT(s) -= 2`的原因是在PyDict set操作中作为key和value会导致其引用加2，因为在其他地方使用该对象时依然要遵循普通的引用计数机制。

最后一行代码设置状态为 SSTATE_INTERNED_MORTAL ，实际被interned了的字符串基本都不会被自动GC。

另一个特性是字符缓冲池，这个和小整数缓冲池很类似。

```cpp
    static PyStringObject *characters[UCHAR_MAX + 1];
    
    PyObject *
    PyString_FromStringAndSize(const char *str, Py_ssize_t size)
    {
        register PyStringObject *op;
        
        // ...
        
        if (size == 1 && str != NULL &&
            (op = characters[*str & UCHAR_MAX]) != NULL)
        {
        #ifdef COUNT_ALLOCS
            one_strings++;
        #endif
            Py_INCREF(op);
            return (PyObject *)op;
        }

        // ...
        
        /* Inline PyObject_NewVar */
        op = (PyStringObject *)PyObject_MALLOC(PyStringObject_SIZE + size);
        if (op == NULL)
            return PyErr_NoMemory();
        PyObject_INIT_VAR(op, &PyString_Type, size);
        op->ob_shash = -1;
        op->ob_sstate = SSTATE_NOT_INTERNED;
        if (str != NULL)
            Py_MEMCPY(op->ob_sval, str, size);
        op->ob_sval[size] = '\0';
        
        /* share short strings */
        if (size == 0) {
            PyObject *t = (PyObject *)op;
            PyString_InternInPlace(&t);
            op = (PyStringObject *)t;
            nullstring = op;
            Py_INCREF(op);
        } else if (size == 1 && str != NULL) {
            PyObject *t = (PyObject *)op;
            PyString_InternInPlace(&t);
            op = (PyStringObject *)t;
            characters[*str & UCHAR_MAX] = op;
            Py_INCREF(op);
        }
        return (PyObject *) op;
    }
```

以上是根据字符串内容和长度构建新字符串的函数，核心主要看 size == 1 的那两个if对应的块代码。第一个很明显是判断如果构建的新对象是已经被缓冲了的，那么直接获取缓冲池里的对象并引用计数加一即可。第二个就是在缓冲池中新建字符串的情况，逻辑也很简单，构建好了op对象，将其intern，设为对应位置的缓冲对象并引用计数加一防止被回收。

### 0x04. PyListObject

```cpp
    typedef struct {
        PyObject_VAR_HEAD
        PyObject **ob_item;
        Py_ssize_t allocated;
    } PyListObject;
```

对象本身也很简单：

+ ob_item ：存放列表实际元素的地方
+ allocated ： 预先申请的长度大小
+ ob_size ：列表实际元素的个数或列表实际长度，即len(list)

ob_size和allocated可以简单直接理解成C++ STL里的size和capacity的关系，毕竟每次删改都去调整申请内存太浪费，当ob_size即将大于allocated时对象会自动去申请新的内存并调整allocated值，也就是说 `0 <= ob_size <= allocated` 永远成立。

说起来其实PyListObject也有个缓冲池机制：

```cpp
    /* Empty list reuse scheme to save calls to malloc and free */
    #ifndef PyList_MAXFREELIST
    #define PyList_MAXFREELIST 80
    #endif
    static PyListObject *free_list[PyList_MAXFREELIST];
    static int numfree = 0;
```

可以看到，默认有个80大小的缓冲池数组。一开始缓冲池里是什么都没有的，每销毁一个PyListObject的时候才会往缓冲池里添加新对象用于之后的缓冲，参看 list_dealloc 函数。而创建PyListObject则会先看看缓冲池有无可用的对象（numfree > 0），优先从缓冲池里取对象。

```cpp
    static void
    list_dealloc(PyListObject *op)
    {
        Py_ssize_t i;
        PyObject_GC_UnTrack(op);
        Py_TRASHCAN_SAFE_BEGIN(op)
        if (op->ob_item != NULL) {
            i = Py_SIZE(op);
            while (--i >= 0) {
                Py_XDECREF(op->ob_item[i]);
            }
            PyMem_FREE(op->ob_item);
        }
        if (numfree < PyList_MAXFREELIST && PyList_CheckExact(op))
            free_list[numfree++] = op;
        else
            Py_TYPE(op)->tp_free((PyObject *)op);
        Py_TRASHCAN_SAFE_END(op)
    }
```

列表的其他增删操作没有太多的难点，唯一的问题就是大家留意回 ob_item。ob_item是PyObject**类型，也就是说其实类似数组，数组元素类型为 PyObject * 。那么问题来了，PyObject并没有next指针（回想PyIntObject中还拿ob_type临时充当next指针了），因此ob_item实际是一段连续的内存，而且不是静态一次申请的（我多次添加元素，它会不断申请内存并调整allocated值）。这里就有个问题了，我的list可能会元素很多，虽然在ob_item里存的每一项仅是一个指针类型，但会不会和别的内存冲突了呢？有allocated值和C语言内置的realloc()函数，请不用担心。list_resize函数出场：

```cpp
    static int
    list_resize(PyListObject *self, Py_ssize_t newsize)
    {
        PyObject **items;
        size_t new_allocated;
        Py_ssize_t allocated = self->allocated;

        
        // 如果 allocated >= newsize >= allocated/2，则不调整内存
        if (allocated >= newsize && newsize >= (allocated >> 1)) {
            assert(self->ob_item != NULL || newsize == 0);
            Py_SIZE(self) = newsize;
            return 0;
        }

        /* This over-allocates proportional to the list size, making room
         * for additional growth.  The over-allocation is mild, but is
         * enough to give linear-time amortized behavior over a long
         * sequence of appends() in the presence of a poorly-performing
         * system realloc().
         * The growth pattern is:  0, 4, 8, 16, 25, 35, 46, 58, 72, 88, ...
         */
        // 内存申请增长策略，比传统可拓展哈希的直接乘2要温和得多 :)
        new_allocated = (newsize >> 3) + (newsize < 9 ? 3 : 6);

        /* check for integer overflow */
        if (new_allocated > PY_SIZE_MAX - newsize) {
            PyErr_NoMemory();
            return -1;
        } else {
            // 算上原有的内存，此处计算出总共需要的内存
            new_allocated += newsize;
        }

        if (newsize == 0)
            new_allocated = 0;
            
        items = self->ob_item;
        if (new_allocated <= (PY_SIZE_MAX / sizeof(PyObject *)))
            PyMem_RESIZE(items, PyObject *, new_allocated);
        else
            items = NULL;
            
        if (items == NULL) {
            PyErr_NoMemory();
            return -1;
        }
        
        // 内存调整成功！
        self->ob_item = items;
        Py_SIZE(self) = newsize;
        self->allocated = new_allocated;
        return 0;
    }
```

顾名思义 list_resize 就是调整列表申请内存的大小，当不够大的时候会去将其调大，当 `allocated/2 > newsize`的时候，不需要那么大了又可以将其收缩。我们可以看到有个PY_SIZE_MAX上限，那么PY_SIZE_MAX到底多大呢？

```cpp
    /* Largest possible value of size_t. 
       SIZE_MAX is part of C99, so it might be defined on some 
       platforms. If it is not defined, (size_t)-1 is a portable 
       definition for C89, due to the way signed->unsigned 
       conversion is defined. */
    #ifdef SIZE_MAX
    #define PY_SIZE_MAX SIZE_MAX
    #else
    #define PY_SIZE_MAX ((size_t)-1)
    #endif
```

可见列表元素上限和你的机器位数有关 :) （size_t在64位机器为8字节，在32位机器为4字节）。其实这里存在着一个tradeoff，我们看到按照上述机制的话realloc()必然会被调用很多次。我们之前搞那么多缓冲池机制不就是为了避免malloc()这样的内存操作吗？现在居然毫不客气地反复调用更耗时的realloc()。但是如果不用realloc的话就要把ob_item拉成一个真正的链表，而链表不能随机访问，势必降低了很多查询方面的效率，同时众所周知很多修改也是基于查询的。因此Python设计者依然选择了连续内存的方式，接着就是通过经验和测试选择一个合适的内存增长策略。这里给我们使用者的一个很大的提醒就是，尽可能提前在构造list的时候先告诉Python去申请一个合适的长度，不要总是偷懒写个 l = [] 就算了。

而tuple不存在会改变长度的问题，因此不需要反复去检查和调用resize函数。所以我们经常会建议可以的话使用tuple便是这样的原因。

### 0x05. PyDictObject

先引入Python dict的哈希机制，Python采用的是开放地址法来解决冲突，即会多次使用一个探测函数f去探寻新的可用地址。因此实际上这就构成了一个探测地址链，[f0, f1, f2, f3 ...]。当其中f1突然被删掉的话，后面的f2 f3很可能就会陷入不可查询状态，这是PyDictObject里会解决的一个问题。

（感觉PyDictObject的定义风格和之前的不太一样。。。）


```cpp

    #define PyDict_MINSIZE 8
    
    typedef struct {
        Py_ssize_t me_hash;
        PyObject *me_key;
        PyObject *me_value;
    } PyDictEntry;

    typedef struct _dictobject PyDictObject;
    struct _dictobject {
        PyObject_HEAD
        Py_ssize_t ma_fill;  /* # Active + # Dummy */
        Py_ssize_t ma_used;  /* # Active */

        Py_ssize_t ma_mask;

        PyDictEntry *ma_table;
        PyDictEntry *(*ma_lookup)(PyDictObject *mp, PyObject *key, long hash);
        PyDictEntry ma_smalltable[PyDict_MINSIZE];
    };
```

PyDictObject的定义终于没有之前那几个对象那么简单了，估计有同学带着疑问看到这里，为什么Dict是个定长对象？！这里暂先按下，先介绍PyDictEntry。PyDictEntry 顾名思义就是dict中的实际的一条Entry，包含一个key的哈希值和其K-V。它可以在三种状态之间转换：Active、Unused、Dummy。

+ Unused： me_key == me_value == NULL
+ Active： me_key != NULL && me_value != NULL
+ Dummy：  一个伪删除状态，Active态的Entry被删除后会被设为Dummy态，为了防止探测链的断裂而设置的一种机制。此时 me_key == dummy（一个特定对象），me_value == NULL。

PyDictEntry的状态转换机制如下：

+ `Unused` --insert--> `Active`
+ `Active` --delete--> `Dummy`
+ `Dummy`  --insert--> `Active`

此时介绍PyDictObject的成员就相对易懂了：

+ ma_fill ：Active + Dummy 的PyDictEntry总个数，其实就是从创建开始至今曾经为或正在为Active的PyDictEntry个数。
+ ma_used ：当前Active的个数
+ ma_mask ：当前PyDictObject所拥有的entry的数量
+ ma_table：指向一片PyDictEntry的首元素，类似PyListObject中的ob_item
+ ma_smalltable ：当dict元素小于PyDict_MINSIZE的时候就使用该数组存放entry。
+ ma_lookup ：指向一个探测函数

按照惯例，先来看看new函数（依然是省去了一些检查和track的代码）：

```cpp
    #define INIT_NONZERO_DICT_SLOTS(mp) do {                                \
        (mp)->ma_table = (mp)->ma_smalltable;                               \
        (mp)->ma_mask = PyDict_MINSIZE - 1;                                 \
    } while(0)

    #define EMPTY_TO_MINSIZE(mp) do {                                       \
        memset((mp)->ma_smalltable, 0, sizeof((mp)->ma_smalltable));        \
        (mp)->ma_used = (mp)->ma_fill = 0;                                  \
        INIT_NONZERO_DICT_SLOTS(mp);                                        \
    } while(0)

    PyObject *
    PyDict_New(void)
    {
        register PyDictObject *mp;
        // 构建dummy对象
        if (dummy == NULL) { /* Auto-initialize dummy */
            dummy = PyString_FromString("<dummy key>");
            if (dummy == NULL)
                return NULL;
        }
    
        // numfree和free_list是不是很熟悉？
        if (numfree) {
            mp = free_list[--numfree];
            
            assert (mp != NULL);
            assert (Py_TYPE(mp) == &PyDict_Type);
            
            _Py_NewReference((PyObject *)mp);
            if (mp->ma_fill) {
                // 清空之前对象的内容
                EMPTY_TO_MINSIZE(mp);
            } else {
                /* At least set ma_table and ma_mask; these are wrong
                    if an empty but presized dict is added to freelist */
                // 初始化
                INIT_NONZERO_DICT_SLOTS(mp);
            }
            
            assert (mp->ma_used == 0);
            assert (mp->ma_table == mp->ma_smalltable);
            assert (mp->ma_mask == PyDict_MINSIZE - 1);
        } else {
            mp = PyObject_GC_New(PyDictObject, &PyDict_Type);
            if (mp == NULL)
                return NULL;
            EMPTY_TO_MINSIZE(mp);
        }
        
        mp->ma_lookup = lookdict_string;
        return (PyObject *)mp;
    }
```

PyDictObject也有一个类似PyListObject中的缓冲池技术，默认值也是80，原理参看PyListObject一节，不赘述。

新建初始化一个PyDictObject做了什么事呢？首先拿对象，要么从缓冲池里拿并做一个clear操作（EMPTY_TO_MINSIZE），要么就从内存里新申请；然后init，可以看到init里ma_table指向了ma_smalltable，这里有个小数组机制，即size小于PyDict_MINSIZE（默认为8）时，数据是存放在ma_smalltable的，ma_table自然指向ma_smalltable；当大于PyDict_MINSIZE时，Python会将smalltable的内容拷贝到一段新的内存里并使ma_table指向新内存头部。相关重要函数是  
`static int dictresize(PyDictObject *mp, Py_ssize_t minused)`。

dictresize函数稍微有点长，此处不便贴太长代码 ，就说明一下。首先函数找到一个刚好大于二的幂值的newsize（最小为PyDict_MINSIZE），然后判断newsize如果为PyDict_MINSIZE，则使用ma_smalltable，将ma_table指向ma_smalltable；否则则在堆上申请新的大小为 newsize * sizeof(PyDictEntry) 的内存，并将ma_table指向该片内存。接着数据迁移，将active态的entry调用insertdict方法插入进dict中（由于内存要么是新申请的，要么是数组，所以可以默认此时的PyDictObject为空），将dummy态的减去引用计数并抛弃。可以看出dictresize也是一个大工程，但幸好的是每次增长是以二的幂增长，因此大部分时候调用resize的次数还是可接受的。

那么这时候也可以回答一开始的问题，PyDictObject是定长对象因为初始构建(`PyDict_New()`)的时候，我们知道dict长度一定是PyDict_MINSIZE，这符合定长对象的定义。至于`PyDict_NewPresized(Py_ssize_t minused)`该函数其实也只是个封装，先调用了new再resize，所以本质没有变。

其他主要的点就是插入、删除过程中调用到的ma_lookup指向的探测函数的使用，这里实际是哈希方面的算法内容，基本了解哈希的同学细心看代码都能明白，所以不赘述。
    
### 0x06. PyLongObject

```cpp
    // digit是个数值类型，根据不同可能为short，可能为uint32
    struct _longobject {
        PyObject_VAR_HEAD
        digit ob_digit[1];
    };
```

PyLongObject相对比较特殊，因为引入的比其他类型要晚。先看创建。

```cpp
    #define MAX_LONG_DIGITS \
    ((PY_SSIZE_T_MAX - offsetof(PyLongObject, ob_digit))/sizeof(digit))

    PyLongObject *
    _PyLong_New(Py_ssize_t size)
    {
        if (size > (Py_ssize_t)MAX_LONG_DIGITS) 
        {
            PyErr_SetString(PyExc_OverflowError,
                            "too many digits in integer");
            return NULL;
        }
        /* coverity[ampersand_in_size] */
        /* XXX(nnorwitz): PyObject_NEW_VAR / _PyObject_VAR_SIZE 
            need to detect overflow */
        return PyObject_NEW_VAR(PyLongObject, &PyLong_Type, size);
    }
    
    // 该段函数不需要细读，扫一下就行 :)
    PyObject *
    PyLong_FromLong(long ival)
    {
        PyLongObject *v;
        unsigned long abs_ival;
        unsigned long t;  /* unsigned so >> doesn't propagate sign bit */
        int ndigits = 0;
        int negative = 0;

        if (ival < 0) {
      
            abs_ival = (unsigned long)(-1-ival) + 1;
            negative = 1;
        }
        else {
            abs_ival = (unsigned long)ival;
        }

   
        t = abs_ival;
        while (t) {
            ++ndigits;
            t >>= PyLong_SHIFT;
        }
        v = _PyLong_New(ndigits);
        if (v != NULL) {
            digit *p = v->ob_digit;
            v->ob_size = negative ? -ndigits : ndigits;
            t = abs_ival;
            while (t) {
                *p++ = (digit)(t & PyLong_MASK);
                t >>= PyLong_SHIFT;
            }
        }
        return (PyObject *)v;
    }
```

我们上面讲过size_t是和机器相关的，也就是说long的上限其实是和机器相关的，大部分时候达不到那个值（比如8字节），所以一般实际和内存大小相关。然后随便看一下FromLong函数，这段函数不需要细读的原因是其实就是一段高精度的实现，数字实际都存储在ob_digit开始的一段连续内存中。这里因为PyLongObject是不可变对象，一开始便申请了固定大小内存，所以不需要像list那样去realloc，直接使用连续内存即可。其他操作（其实就是类似高精度的各种运算）和销毁都很简单，就不赘述。
