#  使用 web3modal SDK实现点击【Connect Wallet】按钮，请求 MetaMask 钱包



新建文件夹`web3modal_metamask`和`index.js`文件

输入文件内容如下：

```
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Connect MetaMask Wallet</title>
</head>
<body>
  <button id="connectWallet">Connect Wallet</button>
  <div id="walletInfo">
    <p>Address: <span id="walletAddress">Not connected</span></p>
    <p>Balance: <span id="walletBalance">Not connected</span> ETH</p>
  </div>

  <!-- Load web3modal and ethers.js from CDN -->
  <script src="https://unpkg.com/web3modal@1.9.5/dist/index.js"></script>
  <script src="https://cdn.ethers.io/lib/ethers-5.2.umd.min.js"></script>
  <script>
    let web3Modal;
    let provider;
    let signer;

    async function init() {
      const providerOptions = {
        // Here you can define different wallet providers if needed
      };

      web3Modal = new Web3Modal.default({
        cacheProvider: false, // optional
        providerOptions, // required
      });

      document.getElementById('connectWallet').addEventListener('click', onConnect);
    }

    async function onConnect() {
      try {
        provider = await web3Modal.connect();
        const web3Provider = new ethers.providers.Web3Provider(provider);
        signer = web3Provider.getSigner();
        const address = await signer.getAddress();
        document.getElementById('walletAddress').textContent = address;

        // Get balance
        const balance = await web3Provider.getBalance(address);
        const balanceInEth = ethers.utils.formatEther(balance);
        document.getElementById('walletBalance').textContent = balanceInEth;
      } catch (e) {
        console.error(e);
      }
    }

    window.addEventListener('load', init);
  </script>
</body>
</html>

```



### 关键点：

1. **确保使用正确的CDN URL**：使用了最新版本的web3modal和ethers.js的CDN链接。
2. **初始化和加载顺序**：确保在页面加载后初始化web3Modal，并在点击按钮时触发连接事件。

### 执行步骤：

1. 确保已安装Node.js和npm。
2. 安装所需的依赖：

```
yarn add web3modal ethers
```

1. 创建并打开 `index.html` 文件，复制并粘贴上述代码。
2. 运行一个本地服务器以查看HTML文件，例如使用 `http-server`：

```
npm install -g http-server
http-server
```

1. 打开浏览器并导航到 `http://localhost:8080`，你应该会看到一个【Connect Wallet】按钮。点击该按钮，请求MetaMask钱包授权，并在页面上显示钱包地址和余额。

确保MetaMask已安装且已解锁。如果问题依旧，请提供控制台的详细错误信息，以便进一步排查。

![image-20240715171650809](/Users/yhb/Library/Application Support/typora-user-images/image-20240715171650809.png)

将这个项目部署到Vercel，你需要按照以下步骤进行操作：

并安装`vercel` CLI工具：

```
npm install -g vercel
```

### 创建一个 Vercel 配置文件

在你的项目根目录下创建一个`vercel.json`文件，内容如下：

```
{
  "version": 2,
  "builds": [
    {
      "src": "index.html",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}
```

### 部署到 Vercel

在终端中运行以下命令登录到你的Vercel账户（如果你还没有Vercel账户，可以在命令行中注册）：

```
vercel login
```

输出结果：

```
hb@yhbdeMacBook-Air web3Modal_metamask % vercel login
(node:49097) [DEP0040] DeprecationWarning: The `punycode` module is deprecated. Please use a userland alternative instead.
(Use `node --trace-deprecation ...` to show where the warning was created)
Vercel CLI 34.3.1
? Log in to Vercel Continue with Email
? Enter your email address: 1131764933@qq.com
We sent an email to 1131764933@qq.com. Please follow the steps provided inside it and make sure the security code matches Sunny Dormouse.
> Success! Email authentication complete for 1131764933@qq.com
Congratulations! You are now logged in. In order to deploy something, run `vercel`.
💡  Connect your Git Repositories to deploy every branch push automatically (https://vercel.link/git).


```

然后在项目根目录中运行以下命令来部署项目：

```
vercel
```

Vercel会提示你选择项目的相关设置，一般直接按回车键选择默认设置即可。部署成功后，Vercel会生成一个访问链接，并显示在终端中。

```
hb@yhbdeMacBook-Air web3Modal_metamask % vercel
(node:49403) [DEP0040] DeprecationWarning: The `punycode` module is deprecated. Please use a userland alternative instead.
(Use `node --trace-deprecation ...` to show where the warning was created)
Vercel CLI 34.3.1
? Set up and deploy “~/web3Modal_metamask”? yes
? Which scope do you want to deploy to? egama's projects
? Link to existing project? no
? What’s your project’s name? web3-modal-metamask
? In which directory is your code located? ./
🔗  Linked to egamas-projects/web3-modal-metamask (created .vercel and added it to .gitignore)
🔍  Inspect: https://vercel.com/egamas-projects/web3-modal-metamask/CnhDqTVbUayT7wyKcYVtgJ1CZDiK [3s]
✅  Production: https://web3-modal-metamask-mr5q05f8r-egamas-projects.vercel.app [3s]
📝  Deployed to production. Run `vercel --prod` to overwrite later (https://vercel.link/2F).
💡  To change the domain or build command, go to https://vercel.com/egamas-projects/web3-modal-metamask/settings
```



### 5. 查看部署的项目

访问Vercel提供的链接，你应该会看到你的网页，其中包括【Connect Wallet】按钮，点击该按钮可以请求MetaMask钱包授权，并显示钱包地址和余额。

你的项目结构如下：

```
my-web3-project/
│
├── index.html
├── package.json
└── vercel.json
```

完成这些步骤后，Vercel会提供一个访问链接，访问该链接即可查看部署的项目。