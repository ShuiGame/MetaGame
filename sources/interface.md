# 接口文档
## Rust后端接口
### 1、发送验证码
用途：用于注册metaId时后端短信对用户手机进行绑定验证时发送随机4位验证码 

**GET https:/shui.one:8080/send_verify_code**  
示例：https:/shui.one:8080/send_verify_code?phone=13262272235  

#### 请求参数  
| 参数名 | 类型 | 是否必填 | 描述 |
| :--- | ---: | :---: | :---: |
| phone | string | 是 | 用户手机 |

#### 响应参数    
| 参数名 | 类型 | 描述 |
| :--- | ---: | :---: |
| success | boolean | 是否成功 |
| msg | string | 响应数据描述，当success不等于true时再读取打印 |
| data | string | 数据 |

#### 响应示例  
{
  "success": true,
  "msg": "send code success",
  "data": "{}"
}

### 2、注册MetaId
用途：调用智能合约给用户钱包发放MetaId

**GET https:/shui.one:8080/register_meta**  
示例：https:/shui.one:8080/register_meta?phone=13262272235&name=sean&email=4486@qq.com&code=1234

#### 请求参数  
| 参数名 | 类型 | 是否必填 | 描述 |
| :--- | ---: | :---: | :---: |
| phone | string | 是 | 电话 |
| name | string | 是 | 用户名称 |
| email | string | 否 | 邮箱 |
| code | string | 是 | 手机验证码,4位数字 |

#### 响应参数    
| 参数名 | 类型 | 描述 |
| :--- | ---: | :---: |
| success | boolean | 是否成功 |
| msg | string | 响应数据描述，当success不等于true时再读取打印 |
| data | string | 数据 |

#### 响应示例  
{
  "success": true,
  "msg": "register success",
  "data": "{}"
}

### 3、查询MetaId信息
用途：根据绑定手机号或钱包地址查询用户MetaId信息，目前主要用于判断用户是否已注册，是否已绑定手机账号等。

**GET https:/shui.one:8080/query_meta_status**  
示例1 根据手机查询信息：https:/shui.one:8080/query_meta_status?phone=13262272231  
示例2 根据钱包地址查询信息：https:/shui.one:8080/query_meta_status?wallet_addr=0xbe379359ac6e9d0fc0b867f147f248f1c2d9fc019a9a708adfcbe15fc3130c18  
示例3 判断钱包地址是否和手机绑定：https:/shui.one:8080/query_meta_status?phone=13262272231&wallet_addr=0xbe379359ac6e9d0fc0b867f147f248f1c2d9fc019a9a708adfcbe15fc3130c18  

#### 请求参数  
| 参数名 | 类型 | 是否必填 | 描述 |
| :--- | ---: | :---: | :---: |
| phone | string | 可单独填写 | 电话 |
| wallet_addr | string | 可单独填写 | 钱包地址 |

#### 响应参数    
| 参数名 | 类型 | 描述 |
| :--- | ---: | :---: |
| success | boolean | 是否成功 |
| msg | string | 响应数据描述，当success不等于true时再读取打印 |
| data | string | metaId的详细json数据 |

#### 响应示例  
case1&2:{  
            "success": true,  
            "message": "",  
            "data":{"bind_status": true,  
            	"email": "448651346@qq.com",  
            	"id": {  
            		"id": "0x6e6c6c39abdcf51d4c906c9135ccd4a42488892a9177353d449a145430f2fa67"  
            	},  
            	"items": {...}  }


case3:{
    "success": true,
    "message": "the phone is binded with the wallet",
    "data":{status:'binded'}}  
    // 若不匹配则显示"data":{status:'unbinded'}}

### 4、查询物品栏信息
用途：根据合约发放的MetaId身份查询用户持有的物品信息

**GET https:/shui.one:8080/query_items_info**  
示例：https:/shui.one:8080/query_items_info?metaId=0x6e6c6c39abdcf51d4c906c9135ccd4a42488892a9177353d449a145430f2fa67  

#### 请求参数  
| 参数名 | 类型 | 是否必填 | 描述 |
| :--- | ---: | :---: | :---: |
| metaId | string | 是 | MetaId 由合约分配 |

#### 响应参数    
| 参数名 | 类型 | 描述 |
| :--- | ---: | :---: |
| success | boolean | 是否成功 |
| msg | string | 响应数据描述，当success不等于true时再读取打印 |
| data | string | 用户持有items的详细json数据 |

#### 响应示例  
case1&2:{  
            "success": true,  
            "message": "",  
            "data":{"bind_status": true,  
            	"email": "448651346@qq.com",  
            	"id": {  
            		"id": "0x6e6c6c39abdcf51d4c906c9135ccd4a42488892a9177353d449a145430f2fa67"  
            	},  
            	"items": {...}  }


case3:{
    "success": true,
    "message": "the phone is binded with the wallet",
    "data":{status:'binded'}}  
    // 若不匹配则显示"data":{status:'unbinded'}}
