/* dlink-flash - Flash D-Link DIR505 (and potentially other D-Links) 
 * using recovery web flashing without using Internet Explorer 8
 *
 * SuperGlue project | http://superglue.it
 * Danja Vasiliev <danja@k0a1a.net> | 2014
 * Based on original work by Daniel Dickinson, 2014
 *
 * - Compile this tool:
 *
 *   $ gcc -o dlink-flash dlink-flash.c
 * 
 * - Boot your DIR-505 unit while holding Reset until red LED begins to blink slowly
 * - Configure your host network interface:
 *
 *   # ifconfig eth0 192.168.0.2 netmask 255.255.255.0 up
 *
 * - Upload desired (original) firmware:
 *
 *   $ ./dlink-flash firmware.bin 
 *
 * - Allow a few minutes for flashing (no indication provided)
 * - Power cycle the unit to boot to new firmware
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. 
 */
 
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdlib.h>
#include <regex.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <errno.h>
 
void build_post_bin(uint8_t **post, size_t *post_len, uint8_t *newdata, size_t datalen) {
    uint8_t *newpost = NULL;
 
    newpost = malloc((*post_len + datalen) * sizeof(uint8_t));
    if (*post) {
  memcpy(newpost, *post, *post_len);
    } else {
        *post_len = 0;
    }
    memcpy(newpost + *post_len, newdata, datalen);
    *post_len += datalen;    
    if (*post)
  free(*post);    
    *post = newpost;
}
 
void build_post(uint8_t **post, size_t *post_len, char *newchar, size_t *content_len) {
    uint8_t *newpost = NULL;
    size_t nlen;
    build_post_bin(post, post_len, newchar, strlen(newchar));
    if (content_len) {
        *content_len += strlen(newchar);
    }
}
 
void usage(char *exename) {
    printf("Usage: %s <filename> [-d]\n", exename);
    printf("   Interface attached to D-Link must have IP addres 192.168.0.2");
    exit(1);
}
 
int open_socket(void) {
    /* we need TCP window to be 1024 bytes long */
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    unsigned int tcpflush = 1;
    unsigned int recvbufsz = 1024;
    unsigned int smallwindow = 1024;
    unsigned int mss = 2048;
 
    setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &recvbufsz, sizeof(recvbufsz));
    setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &recvbufsz, sizeof(recvbufsz));
    setsockopt(sock, IPPROTO_IP, TCP_NODELAY, &tcpflush, sizeof(tcpflush));
    setsockopt(sock, IPPROTO_IP, TCP_MAXSEG, &mss, sizeof(mss));
    setsockopt(sock, IPPROTO_IP, TCP_WINDOW_CLAMP, &smallwindow, sizeof(smallwindow));
 
    struct sockaddr_in ipaddr;
    /* D-Link default recovery IP */
    in_addr_t hostip = inet_addr("192.168.0.1");
    ipaddr.sin_family = AF_INET;
    ipaddr.sin_port = htons(80);
    ipaddr.sin_addr.s_addr = hostip;
    if (connect(sock, (struct sockaddr *)&ipaddr, sizeof(struct sockaddr)) < 0) {
        return -1;
    }
    return sock;
}
 
void send_get(int *sock, uint8_t *get, size_t getlen, uint8_t *post, int debug) {
    size_t socksent = 0;
    size_t curpos = 0;
    *sock = open_socket();
    if (*sock < 0) {
        perror("send_get");
        free(get);
        if (post)
            free(post);
        exit(7);
    }
    while (curpos < getlen) {
        if ((getlen - curpos) >= 1024) {
      socksent = send(*sock, get + curpos, 1024, 0);
            if (debug)
                fprintf(stderr, "Sent %d bytes\n", socksent);
      if (socksent < 0) {
          perror("send_get");
    close(*sock);
    free(get);
                if (post)
        free(post);
    exit(7);
            }
  } else {
      socksent = send(*sock, get + curpos, getlen - curpos, 0);
            if (debug)
                fprintf(stderr, "Sent %d bytes\n", socksent);
      if (socksent < 0) {
          perror("send_get");
    close(*sock);
    free(get);
                if (post)
        free(post);
    exit(7);
            }
        }
        curpos += socksent;
        printf("\r%d/%d Bytes written: GET %g%% complete                          ", curpos, getlen, ((float)curpos / (float)getlen) * (float)100);
  fflush(stdout);
    }
    printf("\nFinished sending GET. Waiting for response.\n");
}
 
int main(int argc, char *argv[]) {
    uint8_t *firmware = NULL;   
    uint8_t *post = NULL;
    size_t postlen = 0;
    uint8_t *get = NULL;
    size_t getlen = 0;
    uint8_t *content = NULL;
    size_t contentlen = 0;
    size_t nonnllen = 0;
    size_t firmwarelen = 0;
    char contentlenstr[2048];
    size_t curpos = 0;
    contentlenstr[0] = 0;
    int debug = 0;
 
    if (argc < 2) {
  usage(argv[0]);
    }
 
   if (argc == 3) {
        if (!strncmp(argv[2], "-d", 2)) {
      debug = 1;
        } else {
      usage(argv[0]);
        }
    } else if (argc > 2) {
  usage(argv[0]);
    }
 
    printf("Load firmware file %s\n", argv[1]);
 
    int firmwarefd = open(argv[1], 0);
    if (firmwarefd < 0) {
  perror(argv[1]);
  exit(1);
    }
 
    size_t len = 0;
    uint8_t buf[2048];
    uint8_t *newfw = NULL;
    int sock;
 
    do {
        len = read(firmwarefd, &buf[0], 2048);
        if (len < 0) {
  perror(argv[1]);
  close(firmwarefd);
        if (firmware)
      free(firmware);
            exit(2);
  }
        if (len > 0) {
      newfw = malloc((firmwarelen + len) * sizeof(uint8_t));
      if (firmware)
    memcpy(newfw, firmware, firmwarelen);
      memcpy(newfw + firmwarelen, &buf[0], len);
      firmwarelen += len;
      if (firmware)
    free(firmware);
      firmware = newfw;
        }
    } while (len > 0);
    close(firmwarefd);
    printf("Firmware %u bytes long\n", firmwarelen);
 
    build_post(&content, &contentlen, "---------------------------7de1fe13304\r\n", NULL);    
    nonnllen += 2;
    /* just going to keep this */
    build_post(&content, &contentlen, "Content-Disposition: form-data; name=\"files\"; filename=\"C:\\My Documents\\firmware.bin\"\r\n", &nonnllen);
    build_post(&content, &contentlen, "Content-Type: application/octet-stream\r\n", &nonnllen);
    build_post(&content, &contentlen, "\r\n", &nonnllen);
    build_post_bin(&content, &contentlen, firmware, firmwarelen);
    build_post(&content, &contentlen, "\r\n---------------------------7de1fe13304--\r\n", NULL);
    nonnllen += 4;
 
    sprintf(contentlenstr, "%d\r\n", nonnllen + firmwarelen);
 
    build_post(&post, &postlen, "POST /cgi/index HTTP/1.1\r\n", NULL);
    build_post(&post, &postlen, "Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, */*\r\n", NULL);
    build_post(&post, &postlen, "Referer: http://192.168.0.1\r\n", NULL);
    build_post(&post, &postlen, "Accept-Language: en-US\r\n", NULL);
    build_post(&post, &postlen, "User-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)\r\n", NULL);
    build_post(&post, &postlen, "Content-Type: multipart/form-data; boundary=---------------------------7de1fe13304\r\n", NULL);
    build_post(&post, &postlen, "Accept-Encoding: gzip, deflate\r\n", NULL);
    build_post(&post, &postlen, "Host: 192.168.0.1\r\n", NULL);
    build_post(&post, &postlen, "Content-Length: ", NULL);
    build_post(&post, &postlen, contentlenstr, NULL);
    build_post(&post, &postlen, "Connection: Keep-Alive\r\n", NULL);
    build_post(&post, &postlen, "Cache-Control: no-cache\r\n", NULL);
    build_post(&post, &postlen, "\r\n", NULL);
    build_post_bin(&post, &postlen, content, contentlen);
    free(content);
    free(firmware);
 
    int gotlen = 0;
    char recvbuf[2048];
    int recvlen = recv(sock, &recvbuf[0], 1024, MSG_WAITALL);
    int newrecvlen;
    printf("Initiating transfer....");
    fflush(stdout);
    sock = open_socket();
    if (sock < 0) {
        perror(argv[1]);
        free(post);
    }
    size_t socksent = 0;
    curpos = 0;
    while (curpos < postlen) {
        if ((postlen - curpos) >= 1024) {
      socksent = send(sock, post + curpos, 1024, 0);
            if (debug)
                fprintf(stderr, "Sent %d bytes\n", socksent);
      if (socksent < 0) {
          perror(argv[1]);
    close(sock);
    free(post);
    exit(5);
            }
  } else {
      socksent = send(sock, post + curpos, postlen - curpos, 0);
            if (debug)
                fprintf(stderr, "Sent %d bytes\n", socksent);
      if (socksent < 0) {
          perror(argv[1]);
    close(sock);
    free(post);
    exit(5);
            }
        }
        curpos += socksent;
        printf("\r%d/%d Bytes written: Upload %g%% complete        ", curpos, postlen, ((float)curpos / (float)postlen) * (float)100);
  fflush(stdout);
    }
    printf("\nFinished sending post. Waiting for response.\n");
    free(post);
    regex_t pattern;
    if (regcomp(&pattern, "count_down", REG_NOSUB)) {
  printf("Error compiling expression to detect success or failure\n");
  close(sock);
  exit(7);
    }
    recvbuf[0] = 0;
    recvlen = recv(sock, &recvbuf[0], 1024, MSG_WAITALL);
    if (debug) {
        fprintf(stderr, "Got %d bytes\n", recvlen);
        fprintf(stderr, "%s", &recvbuf[0]);
    }
    int firstpacket = 1;
    do {
       if (recvlen < 0) {
           perror(argv[1]);
     close(sock);
     exit(6);
       } else if (recvlen > 0) {
           if (!regexec(&pattern, &recvbuf[0], 0, NULL, 0)) {
              printf("Firmware successfully sent.  Please wait for device to reboot.\n");
              break;
              if (firstpacket) {
            printf("Error sending firmware to device.  Response is:\n");
              }
        printf("%s", &recvbuf[0]);
          }
          recvlen = recv(sock, &recvbuf[0], 1024, MSG_WAITALL);
          if (debug) {
        fprintf(stderr, "Got %d data\n", newrecvlen);
              if (recvlen > 0)
                 fprintf(stderr, "%s", &recvbuf[0]);
          }
       }
       firstpacket = 0;
    } while (recvlen > 0);
    regfree(&pattern);
    shutdown(sock, SHUT_RDWR);
    close(sock);
    return 0;    
}
