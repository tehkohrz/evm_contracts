import { ethers } from 'hardhat';
import { ClientProxy, OrdersRelayer } from '../typechain-types';

let OrdersAddress = '0x352D3dfBeAF0a23A127d0920eB0C390d4905aa13';
const ClientAddress = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

const valEVMAccAddress = '0x5161e15fee8b918d4621703db75641bbc25301c8';
// const carbonAddress = '0x352D3dfBeAF0a23A127d0920eB0C390d4905aa13';

const proxyCallback = false; // to toggle sending callback or not by the proxy
const orderFailed = true; // for testing order failure via deleteErrorOrder method
const carbonNetwork = true; // for testing with relayer on carbon network

async function main() {
  const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');
  let ordersRelayer: OrdersRelayer;
  if (carbonNetwork) {
    ordersRelayer = OrdersRelayer.attach(OrdersAddress);
    console.log('Order relayer attaced');
  } else {
    // Deploy orderRelayer contract
    ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
    await ordersRelayer._deployed();
    OrdersAddress = ordersRelayer.address;
    console.log('relayer\n', ordersRelayer.address);
  }

  if (proxyCallback) {
    // Deploy clientProxy contract
    const ClientProxy = await ethers.getContractFactory('ClientProxy');
    const clientProxy = await ClientProxy.deploy(ordersRelayer.address);
    await clientProxy._deployed();
    console.log('client\n', clientProxy.address);

    console.log('Client making request');
    await clientProxy.requestForPosition(valEVMAccAddress, 'btc_donuts');
    const checkRequest = await ordersRelayer.positionQueries(valEVMAccAddress);
    console.log('Check request exist in queue', checkRequest);
  } else {
    // Make direct call to order relayer contract
    console.log('Query for position:');
    const querytx = await ordersRelayer.queryAddressPosition(valEVMAccAddress, 'btc_donuts', '');
    // Check that the respond method was called on order relayer
    const checkRequest = await ordersRelayer.positionQueries(valEVMAccAddress);
    console.log('Check response updated the request', checkRequest);
  }

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
