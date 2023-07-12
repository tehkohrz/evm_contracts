import { ethers } from 'hardhat';
import { ClientProxy, OrdersRelayer } from '../typechain-types';

const OrdersAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const ClientAddress = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

const valEVMAccAddress = '0x5161e15fee8b918d4621703db75641bbc25301c8';
// const carbonAddress = '0x352D3dfBeAF0a23A127d0920eB0C390d4905aa13';

async function main() {
  // Deploy orderRelayer contract
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);
  const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');

  const ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
  const contract = await ordersRelayer._deployed();
  console.log('relayer', contract.address);

  // Deploy clientProxy contract
  const ClientProxy = await ethers.getContractFactory('ClientProxy');
  const clientProxy = await ClientProxy.deploy();
  const clientProxyContract = await clientProxy._deployed();
  console.log('client', clientProxyContract.address);

  const pingTest = await ordersRelayer.ping();
  console.log('Relayer ping', pingTest);
  console.log('Relayer ping', await ordersRelayer.ping());
  console.log('Client ping', await clientProxy.ping());

  console.log('Client making request');
  await clientProxy.requestForPosition(OrdersAddress, valEVMAccAddress, 'btc_donuts');

  await clientProxy.requestForNumber(OrdersAddress, valEVMAccAddress);

  const checkRequest = await ordersRelayer.positionQueries(valEVMAccAddress);
  console.log('Check request', checkRequest);

  // Trial functions
  console.log('=================== before number');
  const before = await clientProxy.testNumber();
  console.log('Position in clientProxy', before);
  console.log('Trials================ Relayer updating number');
  const numberUpdateTx = await ordersRelayer.updateTestNumber(valEVMAccAddress, 123);
  console.log('Tx encoded', numberUpdateTx);
  const numberUpdateReceipt = await numberUpdateTx.wait();
  console.log('=================== Client checking number');
  const number = await clientProxy.testNumber();
  console.log('Position in clientProxy', number);
  const test = await clientProxy.testNumber2();
  console.log('countercheck', test);

  return;
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
