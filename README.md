<h2 align=center>Boundless Prover Node Guide</h2>

## 💻 System Requirements

| Requirement                         | Details                                                     |
|-------------------------------------|-------------------------------------------------------------|
| **CPU**                             | `16 cores`                                                  |
| **RAM**                             | 32 GB                                                       |
| **GPUs**                            | At least 1 NVIDIA GPU with >= **8GB of VRAM**               |
| **Disk/Storage**                    | 200 GB of solid state storage, NVME / SSD preferred         |
| **Operating System**                | Ubuntu 20.04/22.04                                          |

## 🌐 Rent GPU

- Visit : [Vast AI Website](https://cloud.vast.ai/?ref_id=264064)
- Sign Up / Sign In on their website
- Go to the `billing` section and then click on `Add Credit` to top up
- Click on Coinbase and then choose Metamask if u want to pay with cryptocurrency
- Now complete the payment [**Supported network** : Ethereum Mainnet, Base Mainnet, Polygon Mainnet]
- Then open a terminal (this could be either WSL / Codespace / Command Prompt)
- Use this below command to generate SSH-Key
```
ssh-keygen
```
- It will ask 3 questions like this :
```
Enter file in which to save the key (/home/codespace/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again: 
```
- You need to press `Enter` 3 times
- After that you will get a message like this on your terminal
```
Your public key has been saved in /home/codespace/.ssh/id_rsa.pub
```
- `/home/codespace/.ssh/id_rsa.pub` is the path of this public key in my case, in your case it might be different

![Screenshot 2025-04-08 081948](https://github.com/user-attachments/assets/035803da-c5bb-454e-9db4-4459e2123128)

- You should use this command to see those ssh key :
    - If you are using Linux/macOS (WSL) : `cat path/of/that/publickey` , in my case, it would be : `cat /home/codespace/.ssh/id_rsa.pub`
    - If you are using Command Prompt : `type path\of\that\publickey`, in my case, it would be : `type \home\codespace\.ssh\id_rsa.pub`
    - If you are using PowerShell : `Get-Content path\of\that\publickey`, in my case, it would be : `Get-Content \home\codespace\.ssh\id_rsa.pub`
- Now copy this public key and visit vast ai website again
- Then navigate to the `key` section, click on `ssh-key` and then paste and save your copied SSH key here
- Then go to the template section and then choose `Ubuntu 22.04 VM` template and then click on the play icon to select this template
- Here choose a GPU and Rent it
- After that visit `Instances` section, if your ordered GPU is ready then u will see `Connect` button there
- Click on it to copy the command and then paste this command on your terminal to access your GPU

## 🍓Prerequisites
**1. Claim Faucet**
- First claim USDC faucet from this [website](https://faucet.circle.com/) to your wallet
- If you want to run this prover on Mainnet as well, then u need to have real USDC on Base Mainnet in your wallet

**2. Get RPC**
- Get RPC for the network from [Alchemy website](https://dashboard.alchemy.com/chains)
- If you want to run this prover on eth-sepolia then u need to get eth sepolia rpc, if base-sepolia then base-sepoia rpc or if base mainnet then u need to get base mainnet rpc

## 📥 Installation
- Install `curl` command
```
apt update && apt install -y curl
```
- Execute this command to run boundless prover
```
[ -f boundless.sh ] && rm boundless.sh; curl -o boundless.sh https://raw.githubusercontent.com/zunxbt/boundless-prover/refs/heads/main/boundless.sh && chmod +x boundless.sh && . ./boundless.sh
```
## ⚙️ Check Logs
- Use the below command to check logs
```
docker compose logs -f broker
```
- You will some similar types of logs after few mins of running

![image](https://github.com/user-attachments/assets/4fe76d31-9d3e-4220-a107-d6146c61aafc)

## 💻 Some commands
- To Stop Broker

   - For `eth-sepolia`

     ```
     just broker down ./.env.broker.eth-sepolia
     ```
  - For `base-sepolia`

    ```
    just broker down ./.env.broker.base-sepolia
    ```
  - For `base` (mainnet)

    ```
    just broker down ./.env.broker.base
    ```
- To Start Broker

   - For `eth-sepolia`

     ```
     just broker up ./.env.broker.eth-sepolia
     ```
  - For `base-sepolia`

    ```
    just broker up ./.env.broker.base-sepolia
    ```
  - For `base` (mainnet)

    ```
    just broker up ./.env.broker.base
    ```

**Note : This is the basic stuff, your node will run fine now but I still need to add more things here, so u should check this guide back later**
