BlueSEA Cairo SmartContract
===

1. Setup Account

```
sncast account add --name <deployer> --address <account_address> --type argent --private-key <private_key> --add-profile sepolia
```

2. Declare Contract

```
sncast -p sepolia declare --contract-name BlueSeaToken
sncast -p sepolia declare --contract-name BlueSeaReward
```

3. Deploy Contract

```
sncast -p sepolia deploy --class-hash <class_hash> -c <list_params>
```

### Current deployment on Sepolia
- BlueSeaToken: [0x0711b26954f9a844b066ef094fc439b211398afc2be39b63e14908e86444b150](https://sepolia.starkscan.co/token/0x0711b26954f9a844b066ef094fc439b211398afc2be39b63e14908e86444b150)
- BlueSeaReward: [0x0686d1544a0926fff8f2773f50d307c8e69c081e8668e13c49318a77b0f91f7f](https://sepolia.starkscan.co/contract/0x0686d1544a0926fff8f2773f50d307c8e69c081e8668e13c49318a77b0f91f7f)
