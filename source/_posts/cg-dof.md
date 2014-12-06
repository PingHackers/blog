title: CG学习之DOF景深算法
date: 2014-12-05 22:27:39
description: PingHackers | CG学习之DOF景深算法 | 在C++程序运行的过程中免不了要进行资源的分配——尤其是在游戏中！资源可以有很多种，从纹理、声音、着色器代码到句柄、字符串这些东西都可以被称为资源。资源的管理是项目中很重要的一轮，做得不好的话轻则内存泄漏、重则内存崩溃。RAII则是在C++项目中用于资源管理的一种重要的编程思想。
tags:
- CG
- Game
- Shader
---
**作者**：左君博

**转载请注明出处，保留原文链接和作者信息**

* * *

## 目录
- 何为DOF
- 前置技能——Blur的实现
- 粗糙的DOF实现方法
- 较好的DOF实现方法

## 何为DOF
DOF，全称叫做"Depth Of Field"，也就是景深效果，是CG中常用的效果。

举一个最简单的栗子：当你在看电影的时候，应该经常注意到镜头几乎从来都是聚焦到主角的脸上，比方说下面这张图（来源于陆小凤传奇之绣花大盗）：
<!-- more -->

![image](http://noahzuo-noah.stor.sinaapp.com/Image.png)

此时镜头的全部聚焦于张智霖的脸上了，一般人肯定也是聚精会神在这个帅比的脸上，但是细心的童鞋肯定会发现此时他身后的背景和镜头与他之间的景物此时被模糊了，这就是DOF效果。

总之，就是需要在渲染的时候展现深度信息，这就是DOF效果的目的。

## 前置技能——Blur的实现
Blur，又称为平滑、模糊化，也就是说把一张图变得比较模糊。在CG中，这通常是通过滤波器来实现的。滤波器这个名字听起来可能比较让人尿一裤子，实际上，也就是一张纹理，我们在对某个像素点进行采样的时候，不仅仅只取这个点的像素值，而是会考虑取它周围的像素点的一些权重的颜色值，如下图，我们对于这个坐标的像素点取了1/4的比例权重，而对于上下左右比较近的点，去了1/8的权重，对于左上、左下、右上、右下的点，取了1/16的权重，从而实现了平滑滤波。

![image](http://noahzuo-noah.stor.sinaapp.com/dof-BlurFilter-Image.png)

当然，还有很多其他的滤波器可供选择，但是原理都是一样的。BTW，大三树莓班朝红阳教授的DIP课程简直是神课，看到好多师弟师妹的吐槽心里感觉挺不是滋味的……

知道了滤波器的原理那么实现起来就很简单了……以下是实现像素着色器的代码，采用的是HLSL的着色语言：

{% codeblock lang:cpp %}
    float sampleDist0;
    sampler RT;
    // Simple blur filter
    
    const float2 samples[12] = {
       -0.326212, -0.405805,
       -0.840144, -0.073580,
       -0.695914,  0.457137,
       -0.203345,  0.620716,
        0.962340, -0.194983,
        0.473434, -0.480026,
        0.519456,  0.767022,
        0.185461, -0.893124,
        0.507431,  0.064425,
        0.896420,  0.412458,
       -0.321940, -0.932615,
       -0.791559, -0.597705,
    };
    
    float4 main(float2 texCoord: TEXCOORD0) : COLOR {
       float4 sum = tex2D(RT, texCoord);
       for (int i = 0; i < 12; i++){
          sum += tex2D(RT, texCoord + sampleDist0 * samples[i]);
       }
       return sum / 13;
    }

{% endcodeblock %}	

markdown没有HLSL语法支持orz……

## 粗糙的DOF实现方法
如果仅仅从展现效果来看，要实现DOF效果，那么只要在设定两个值，一个近平面一个远平面，在近平面中以内和远平面以外的像素我们采用Blur的像素点渲染，而在远平面和近平面之间的像素我们正常渲染。如果是这样的话那么我们就只需要进行深度的检测就可以了，不得不说是相当简单的方法：

在这里是使用了RenderMonkey进行实现，直接在Vertex Shader中将对应的Vertex的深度设为Far_Dist或者Near_Dist，然后进行深度模板的检测就可以了，Vertex Shader代码如下：
{% codeblock lang:cpp %}
    float4x4 matViewProjection;
    float fInverseViewportHeight;
    float fInverseViewportWidth;
    float Near_Dist;
    
    struct VS_OUTPUT
    {
       float4 Position : POSITION ;
       float2 Tex:TEXCOORD0 ;
    };
    
    VS_OUTPUT vs_main( float4 Position : POSITION )
    {
       VS_OUTPUT Output;
       Output.Position = float4(Position.xy , Near_Dist, 1.0 );
       Output.Tex .x = (Position.x + 1.0 + fInverseViewportWidth) * 0.5 ;
       Output.Tex .y = (1.0 - Position.y + fInverseViewportHeight) * 0.5;
      
      
       return( Output );  
    }
{% endcodeblock %}	

效果如下：

![image](http://noahzuo-noah.stor.sinaapp.com/DOF-BlurFilter-Depth.png)

大致看起来效果还不错，但是这里存在着一个很严重的问题——且先把远处模糊和近处模糊的颜色分别用红绿颜色表示：

![image](http://noahzuo-noah.stor.sinaapp.com/DOF-BlurFilter-Depth-RedGreen.png)

大家估计能猜到问题是啥了吧，没错，这种的DOF实现会导致模糊处与正常渲染处的过渡非常尖锐，所以说这种方法虽然简单，但是局限性还是非常大的。当然改进的办法也不是没有，我们只要再次进行一次或者几次平滑滤波就可以把尖锐的波形给滤掉了。如果上过朝红阳教授的DIP课的童鞋会不会感到非常亲切呢哇哈哈哈哈……

## 较好的DOF实现方法
在上面的DOF实现方法中，不足之处就在于**深度值是跳跃的**，从而导致Blur的效果在两个平面表现的非常尖锐。那么有啥办法能够让深度值表现的不那么跳跃呢？

其实很简单，我们在管线中另外声明一个值来储存这个点的深度不就够了咩？想到这一点后又不难联想到——颜色是使用RGBA四个分量来储存的，A分量还没用呢！那么我们只需要取得当前的视角变换矩阵，并且和这个点的Position分量进行矩阵乘法，就能获得它距离摄像机的距离了！

vs代码：
{% codeblock lang:cpp %}
    float4x4 view_proj_matrix;
    float4x4 view_matrix;
    float distanceScale;
    struct VS_OUTPUT {
       float4 Pos:      POSITION;
       float2 texCoord: TEXCOORD0;
       float3 normal:   TEXCOORD1;
       float3 viewVec:  TEXCOORD2;
    };
    
    VS_OUTPUT main(float4 Pos: POSITION, float3 normal: NORMAL, float2 texCoord: TEXCOORD0){
       VS_OUTPUT Out;
    
       Out.Pos = mul(view_proj_matrix, Pos);
       Out.texCoord = texCoord;
       // Eye-space lighting
       Out.normal = mul(view_matrix, normal);
       // We multiply with distance scale in the vertex shader
       // instead of the fragment shader to improve performance.
       Out.viewVec = -distanceScale * mul(view_matrix, Pos);
    
       return Out;
    }
{% endcodeblock %}	

ps代码：
{% codeblock lang:cpp %}
    float Kd;
    float Ks;
    float4 lightDir;
    sampler Base;
    float4 main(float2 texCoord: TEXCOORD0, float3 normal: TEXCOORD1, float3 viewVec: TEXCOORD2) : COLOR {
       float3 base = tex2D(Base, texCoord);
    
       // Basic lighting
       float diffuse = dot(lightDir, normal);
       float specular = pow(saturate(dot(reflect(-normalize(viewVec), normal), lightDir)), 16);
       float3 light = Kd * diffuse * base + Ks * specular;
    
       // We'll use the distance to decide how much blur we want
       float dist = length(viewVec);
    
       return float4(light, dist);
}
{% endcodeblock %}	
上面代码中的viewVec就是我所定义的这个顶点距离摄像机的向量，乘以一个distanceScale只是做一个范围的转变。

哦对了顺便说一句上面的代码涉及到一些光照模型的知识，本来想拉出来聊聊的但是嘉华说这些专业性太强了师妹估计看不懂所以提一下就可以了……话说看这些博客的师妹真的这么少么orz……

这是处理后的rendertarget图：

![image](http://noahzuo-noah.stor.sinaapp.com/DOF-BlurFilter-Alpha1.png)

这是rendertarget的alpha通道图：

![image](http://noahzuo-noah.stor.sinaapp.com/DOF-BlurFilter-Alpha2.png)

经过这样一番处理可以看到顶点的深度信息已经写到renderTarget的alpha通道里了，并且alpha信息是连续的。

那么我们现在要做的就只是把深度信息转化为blur程度的信息，这还不简单咩？lerp函数伺候！

{% codeblock lang:cpp %}
    float focus;
    float range;
    sampler Blur1;
    sampler RT;
    float4 main(float2 texCoord: TEXCOORD0) : COLOR {
       float4 sharp = tex2D(RT,   texCoord);
       float4 blur  = tex2D(Blur1, texCoord);
    
       return lerp(sharp, blur, saturate(range * abs(focus - sharp.a)));
    }
{% endcodeblock %}	

效果如下：

![image](http://noahzuo-noah.stor.sinaapp.com/DOF-BlurFilter-Alpha-Result.png)

比起前一种方法的效果要好多啦！

（全文完）
