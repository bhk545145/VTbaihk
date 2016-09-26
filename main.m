//
//  main.m
//  VTbaihk
//
//  Created by 白洪坤 on 16/9/25.
//  Copyright © 2016年 白洪坤. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#import <arpa/inet.h>

typedef struct vtbridge_header{
    unsigned int   magiccode;	// 0x5aa5a55a
    unsigned short status;		// 0 means success, other means failure.
    unsigned short msgtype;	// message type
    unsigned short data_len;	// valid data length
    unsigned short checksum;	// all data checksum
    unsigned short version;		// always 0.
    unsigned short encrypt;		// always 0.
    unsigned short sequence;	// always 0.
    unsigned short reserved;	// always 0.
    unsigned char cookie[36];	// service响应时，需要将cookie原样返回
}__attribute__((packed))vtbridge_header_t;

typedef NS_ENUM(NSUInteger, Msgtype) {
    AGENT_HEARTBEAT_REQ = 0,		//心跳请求，由厂商SDK发起
    AGENT_HEARTBEAT_RES,		//心跳相应，由bridge回应
    AGENT_DEVICELIST_REQ,		//请求设备列表，由bridge发起
    AGENT_DEVICELIST_RES,		//设备列表响应，由第三方设备回应
    AGENT_DEVCTRL_REQ,			//设备控制请求，由bridge发起
    AGENT_DEVCTRL_RES,			//设备控制响应，由第三方设备回应,
    AGENT_DEVREG_REQ,			//设备注册请求，由bridge发起
    AGENT_DEVREG_RES,			//设备注册响应，由第三方设备回应,
};



unsigned short GetCheckSum(char *data, size_t len){
    
    int i;
    unsigned short sum = 0xbeaf;
    vtbridge_header_t *header = (vtbridge_header_t *)data;
    
    header->checksum = 0;
    for (i=0; i<len; i++) {
        sum += data[i];
    }
    
    return sum;

    
}

char *VTHeader(char *data,Msgtype i,unsigned short status,unsigned char cookie[36]){
    struct vtbridge_header vtbridge = {0x5aa5a55a,0,AGENT_DEVREG_REQ,0,0,0,0,0,0,000000000000000000000000000000000000000000000000000000000000000000000000};
    char *vtbridgedata = (char *)&vtbridge;
    size_t len = sizeof(vtbridgedata);
    short sum = GetCheckSum(vtbridgedata,len);
    vtbridgedata = sum + vtbridgedata;
    return vtbridgedata;
}



//socket 发送
void SendTCP(char buf[1024]){
    int fd=socket(AF_INET, SOCK_STREAM, 0);
    char recvbuf[1024];
    ssize_t count;
    size_t len = sizeof(*buf);
    send(fd, buf, len, 0);
    count = recv(fd, recvbuf, 1024, 0);
}

char DataPack(Msgtype msgtype,char *data){
    unsigned char cookie[36] = {0};
    char vtheaderbytes = *VTHeader(data, msgtype, 0, cookie);
    return vtheaderbytes;
}

void Register(){
    NSDictionary *array = @{
                            @"pid":@"00000000000000000000000028270000",
                            @"uniquesn":@"123456789"
                            };
    NSDictionary *dic = @{
                          @"companyid": @"7d314908312182c8a243d64713c7eefe",
                          @"devlist"  : @[array],
                          };
    int msgtype = AGENT_DEVREG_REQ;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    char *jsondata = (char*)[jsonData bytes];
    unsigned char cookie[36] = {0};
    char *headerdata = VTHeader(jsondata,msgtype,0,cookie);
    strcat(headerdata, jsondata);
    SendTCP(headerdata);
}

//socket 连接
void VTDevice(const char *address,int port) {
    
    //        1
    int err;
    int fd=socket(AF_INET, SOCK_STREAM, 0);
    BOOL success=(fd!=-1);
    struct sockaddr_in addr;
    //        1
    //   2
    if (success) {
        NSLog(@"socket success");
        memset(&addr, 0, sizeof(addr));
        addr.sin_len=sizeof(addr);
        addr.sin_family=AF_INET;
        addr.sin_addr.s_addr=INADDR_ANY;
        err=bind(fd, (const struct sockaddr *)&addr, sizeof(addr));
        success=(err==0);
    }
    //   2
    //3
    if (success) {
        //============================================================================
        struct sockaddr_in peeraddr;
        memset(&peeraddr, 0, sizeof(peeraddr));
        peeraddr.sin_len=sizeof(peeraddr);
        peeraddr.sin_family=AF_INET;
        peeraddr.sin_port=htons(port);
        //            peeraddr.sin_addr.s_addr=INADDR_ANY;
        peeraddr.sin_addr.s_addr=inet_addr(address);
        //            这个地址是服务器的地址，
        socklen_t addrLen;
        addrLen =sizeof(peeraddr);
        NSLog(@"connecting");
        err=connect(fd, (struct sockaddr *)&peeraddr, addrLen);
        success=(err==0);
        if (success) {
            //                struct sockaddr_in addr;
            err =getsockname(fd, (struct sockaddr *)&addr, &addrLen);
            success=(err==0);
            //============================================================================
            //============================================================================
            if (success) {
                NSLog(@"connect success,local address:%s,port:%d",inet_ntoa(addr.sin_addr),ntohs(addr.sin_port));
                Register();
            }
        }
        else{
            NSLog(@"connect failed");
        }
    }
    //    ============================================================================
    //3
}




int main(int argc, const char * argv[]) {
    @autoreleasepool {
        VTDevice("192.168.2.120", 16640);
    }
    return 0;
}



