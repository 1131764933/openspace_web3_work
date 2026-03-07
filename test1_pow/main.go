package main

import(
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)


func main() {

	fmt.Println("寻找满足4个0开头的哈希值")
	startTime:=time.Now()
	findhash("egama",4)
	fmt.Printf("耗时: %v\n\n",time.Since(startTime))


	fmt.Println("寻找满足5个0开头的哈希值")
	startTime=time.Now()
	findhash("egama",5)
	fmt.Printf("耗时: %v\n\n",time.Since(startTime))

}


func findhash(nickname string ,zeros int){
	targetPrefix :=strings.Repeat("0",zeros)
	nonce:=0

	for {
		input :=fmt.Sprintf("%s%d",nickname,nonce)
		hash:=sha256.Sum256([]byte(input))
		hashString:=hex.EncodeToString(hash[:])
		if strings.HasPrefix(hashString,targetPrefix)  {
			fmt.Printf("找到目标哈希值: %s\n",hashString)
			fmt.Printf("内容: %s\n",input)
			fmt.Printf("哈希值: %x\n",hash)
			break
		}
		nonce++
	}
}