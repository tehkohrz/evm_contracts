import { ethers } from 'hardhat';
import { ClientProxy, OrdersRelayer } from '../typechain-types';

const OrdersAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const valEVMAccAddress = '0x5161e15fee8b918d4621703db75641bbc25301c8';
const carbonAddress = '0x352D3dfBeAF0a23A127d0920eB0C390d4905aa13';

//CONFIGURATIONS
const carbonNetwork = true; // for testing with relayer on carbon network
const orderFailed = false; // for testing order failure via deleteErrorOrder method
const proxyCallback = true; // to toggle sending callback or not by the proxy

async function main() {
  // ----------------- Contract Deploy -----------------
  const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');
  const orderI = OrdersRelayer.interface;
  let ordersRelayer: OrdersRelayer;

  if (carbonNetwork) {
    ordersRelayer = OrdersRelayer.attach(carbonAddress);
  } else {
    ordersRelayer = await OrdersRelayer.deploy('testContract', 0);
    await ordersRelayer._deployed();
    console.log('hardhat network relayer:', ordersRelayer.address);
  }
  const orderAddress = ordersRelayer.address;

  // Deploy clientProxy contract
  const ClientProxy = await ethers.getContractFactory('ClientProxy');
  const proxyI = ClientProxy.interface;
  const clientProxy = await ClientProxy.deploy(orderAddress);
  await clientProxy._deployed();

  // ----------------- Order Queries -----------------
  const orderKey = 'testOrder';
  console.log('============Querying order through proxy============ \n');
  const queryTx = await clientProxy.requestForOrder(orderKey);

  // Parsing the emitted event to obtain the orderKey
  const queryReceipt = await queryTx.wait();
  console.log('============Logging events============ \n');
  console.log('Logs:', queryReceipt);

  // ----------------- Order Updates -----------------
  const orderDetails: OrdersRelayer.OrderStruct = {
    id: 'testOrder',
    market: 'swth_eth',
    side: ethers.BigNumber.from('1'),
    price: 1000000000000000,
    quantity: 1231230000000000,
    status: ethers.BigNumber.from('3'),
    orderType: ethers.BigNumber.from('0'),
    timeInForce: ethers.BigNumber.from('0'),
    avgFilledPrice: 222222222,
    isReduceOnly: false,
    evmCreator: valEVMAccAddress,
  };

  console.log('============Sending Manual Response to relayer============ \n');
  const orderRes: OrdersRelayer.MsgOrderQueryResponseStruct = {
    orderKey: 'testOrder',
    order: orderDetails,
  };
  const orderQueryResTx = await ordersRelayer.respondToOrderQuery(orderRes);
  const orderQueryResReciept = await orderQueryResTx.wait();
  console.log('============Logging events============ \n');
  console.log('Parsed logs:', orderQueryResReciept);

  console.log('============Checking Order in Proxy============ \n');
  const order = await clientProxy.orders('testOrder');
  console.log(order);

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
