# Compile

I have used `dart sdk 2.14.2`

Clone the repository and `cd` into it

```
cd packages
git clone https://github.com/zenon-network/znn_sdk_dart
cd znn_sdk_dart
dart pub get
cd ../..
dart pub get
dart compile exe sentrify.dart -o sentrify
```

Transfer it to your pillar

`scp sentrify root@ip:/path/`

# Usage

### This is a tutorial on how to sentrify your node, meaning that it will only communicate with the sentries
### At least 2 sentries are recommended per node
### Only works for ipv4 for now
### Firewall rules are persistent to reboot

#### Get unzip, znn bundle and sentrify
```
apt-get update
apt-get install unzip
mkdir alphanet && cd alphanet
wget https://github.com/zenon-network/znn-bundle/releases/download/v0.0.1-alphanet/znn-alphanet-bundle-linux-amd64.zip
unzip znn-alphanet-bundle-linux-amd64.zip
wget https://github.com/MoonBaZe/sentrify/releases/download/release/sentrify
chmod +x sentrify
```

#### Add swap memory
Add 16 GB of swap so the node can process any block and won't get stuck for too long

`fallocate -l 16G /swapMem && chmod 600 /swapMem && mkswap /swapMem && swapon /swapMem && echo '/swapMem none swap sw 0 0' | tee -a /etc/fstab`

#### Transfer producer keystore and config.json to the pillar (only if using a new vps)

`mkdir -p /root/.znn/wallet` - on the new pillar vps


`scp /root/.znn/config.json root@ip:/root/.znn` - on the old pillar vps, change ip with the new pillar vps ip
`scp /root/.znn/wallet/producer root@ip:/root/.znn/wallet/` on the old pillar vps, change ip with the new pillar vps ip


#### Use controller to download znnd and create service
`./znn-controller` and choose option `2 (deploy)` - to download znnd and create the service

choose `y` as you want to continue with the configuration

`./znn-controller` and choose option `5 (stopService)` - stop it for now


#### Bootstrap (optional)
`./sentrify` and choose option `1` - will ask for bootstrap url, will download the blocks and genesis and put them in the default directory

bootstrap url: `https://github.com/MoonBaZe/sentrify/releases/download/release/bootstrap.zip`

Otherwise, you can download the genesis and wait for the node to sync when we start the service
```
cd /root/.znn
wget -O genesis.json https://ipfs.io/ipfs/QmVFyGWNt3Ph2mn9MoxZyTgjuMGSs2cDdqXP3B8Ri5AYY5?filename=genesis.json
```
#### Remove peers
`./sentrify` and choose option `3` - this will remove all peers from `config.json` if you have any

#### Add sentries
`./sentrify` and choose option `2` - will ask for sentry ip and then ws port, so it can take it's public key and add it 
repeat for all your sentries

#### Sentrify
`./sentrify` and choose option `4` - will add firewall rules so that your node only accepts
ssh, dns (so controller works) and your sentries

#### Enable firewall
`ufw enable` - then `y` - don't worry, will not interrupt your `ssh`

#### Start node
`./znn-controller` and choose option `4 (startService)`

### Tips

Every time you add a new sentry, you should run `sentrify` (option 4) and then `enable ufw`

Peers url ONLY for sentries:
`https://ipfs.io/ipfs/QmeAUQkpoEMNRQ9SFcBV2kmRTXT3WLKAoMxvAtX2ErZubJ?filename=peers.json`
