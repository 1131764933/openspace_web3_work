package main

import (
	"crypto"
    "crypto/rand"
    "crypto/rsa"
    "crypto/sha256"
    "crypto/x509"
    "encoding/hex"
    "encoding/pem"
    "fmt"
    "os"
    "strings"
    "time"
)

// 生成RSA密钥对并保存到文件
func generateRSAKeyPair() (*rsa.PrivateKey, *rsa.PublicKey, error) {
    // 生成私钥
    privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return nil, nil, err
    }

    // 导出并保存私钥
    privateKeyFile, err := os.Create("private_key.pem")
    if err != nil {
        return nil, nil, err
    }
    defer privateKeyFile.Close()

    privateKeyPEM := pem.Block{
        Type:  "RSA PRIVATE KEY",
        Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
    }
    if err := pem.Encode(privateKeyFile, &privateKeyPEM); err != nil {
        return nil, nil, err
    }

    // 导出并保存公钥
    publicKey := &privateKey.PublicKey
    publicKeyFile, err := os.Create("public_key.pem")
    if err != nil {
        return nil, nil, err
    }
    defer publicKeyFile.Close()

    publicKeyBytes, err := x509.MarshalPKIXPublicKey(publicKey)
    if err != nil {
        return nil, nil, err
    }

    publicKeyPEM := pem.Block{
        Type:  "RSA PUBLIC KEY",
        Bytes: publicKeyBytes,
    }
    if err := pem.Encode(publicKeyFile, &publicKeyPEM); err != nil {
        return nil, nil, err
    }

    return privateKey, publicKey, nil
}

// 计算SHA256哈希值并返回哈希字符串
func calculateSHA256(input string) string {
    hash := sha256.Sum256([]byte(input))
    return hex.EncodeToString(hash[:])
}

// 查找符合4个零开头的哈希值的“昵称 + nonce”
func findPOW(nickname string) (string, string) {
    nonce := 0
    targetPrefix := "0000"

    for {
        input := fmt.Sprintf("%s%d", nickname, nonce)
        hash := calculateSHA256(input)

        if strings.HasPrefix(hash, targetPrefix) {
            return input, hash
        }
        nonce++
    }
}

// 使用私钥对消息进行签名
func signMessage(privateKey *rsa.PrivateKey, message string) ([]byte, error) {
    hashed := sha256.Sum256([]byte(message))
    signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, hashed[:])
    if err != nil {
        return nil, err
    }
    return signature, nil
}

// 使用公钥验证签名
func verifySignature(publicKey *rsa.PublicKey, message string, signature []byte) error {
    hashed := sha256.Sum256([]byte(message))
    return rsa.VerifyPKCS1v15(publicKey, crypto.SHA256, hashed[:], signature)
}

func main() {
    // 生成RSA密钥对
    privateKey, publicKey, err := generateRSAKeyPair()
    if err != nil {
        fmt.Println("生成密钥对失败:", err)
        return
    }
    fmt.Println("RSA密钥对已生成并保存到文件。")

    // 查找符合POW（4个零开头的哈希值）的“昵称 + nonce”
    nickname := "egama"
    startTime := time.Now()
    message, hash := findPOW(nickname)
    elapsedTime := time.Since(startTime)

    fmt.Printf("找到符合4个零开头的哈希值:\n")
    fmt.Printf("昵称 + nonce: %s\n", message)
    fmt.Printf("哈希值: %s\n", hash)
    fmt.Printf("耗时: %s\n", elapsedTime)

    // 用私钥对消息进行签名
    signature, err := signMessage(privateKey, message)
    if err != nil {
        fmt.Println("签名失败:", err)
        return
    }
    fmt.Printf("签名: %x\n", signature)

    // 用公钥验证签名
    err = verifySignature(publicKey, message, signature)
    if err != nil {
        fmt.Println("验证签名失败:", err)
        return
    }
    fmt.Println("签名验证成功！")
}