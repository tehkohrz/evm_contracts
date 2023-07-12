import { ethers } from 'hardhat';

const OrdersAddress = '0x7B93Da8e76D8B97C1c255E8E61bede2148981097';

async function main() {
  // Deploy orderRelayer contract
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);
  const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');

  const ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
  const contract = await ordersRelayer._deployed();
  console.log(contract.address);

  // Deploy clientProxy contract
  const ClientProxy = await ethers.getContractFactory('ClientProxy');
  const clientProxy = await ClientProxy.deploy();
  const clientProxyContract = await clientProxy._deployed();
  console.log(clientProxyContract.address);
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// steps to test the deployed contract
// carbond tx xevmmerge merge-account 034a1e1f95ebb49bc59b3c2d60afbb4c2fb2b77cd1f1e2322123fdacaa3d12f7a9 --from val --keyring-backend file --fees 100000000swth
// yarn hardhat --network carbon_local run scripts/deploy.ts
