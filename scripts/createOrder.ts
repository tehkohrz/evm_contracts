import { ethers } from 'hardhat';
import { ClientProxy, OrdersRelayer } from '../typechain-types';

const OrdersAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const valEVMAccAddress = '0x5161e15fee8b918d4621703db75641bbc25301c8';
const carbonAddress = '0x352D3dfBeAF0a23A127d0920eB0C390d4905aa13';

const carbonNetwork = false;

async function main() {
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
  const clientProxy = await ClientProxy.deploy(orderAddress);
  await clientProxy._deployed();

  const testOrderReq = {
    creator: valEVMAccAddress,
    market: 'swth_eth',
    side: ethers.BigNumber.from('0'),
    quantity: 1231230000000000,
    orderType: ethers.BigNumber.from('0'),
    price: 1000000000000000,
    isReduceOnly: false,
    fnSig:
      'saveOrder((string,string,uint8,uint256,uint256,uint8,uint8,uint8,uint256,bool,address),string)',
  };

  console.log('============Creating order through proxy============ \n');
  const orderTx = await clientProxy.createProxyOrder(
    testOrderReq.market,
    testOrderReq.side,
    testOrderReq.quantity,
    testOrderReq.orderType,
    testOrderReq.price,
    testOrderReq.isReduceOnly,
    testOrderReq.fnSig
  );
  // const orderTx = await ordersRelayer.createOrder(
  //   testOrderReq.market,
  //   testOrderReq.side,
  //   testOrderReq.quantity,
  //   testOrderReq.orderType,
  //   testOrderReq.price,
  //   testOrderReq.isReduceOnly,
  //   testOrderReq.fnSig
  // );

  // Parsing the emitted event to obtain the orderKey
  const orderReceipt = await orderTx.wait();
  let parsedLog = orderI.parseLog(orderReceipt.logs[0]);
  const orderKey = parsedLog.args.orderKey;
  console.log('============Logging events============ \n');
  console.log('OrderKey:', orderKey);

  console.log('============Sending Manual Update to relayer============ \n');
  const orderUpdate: OrdersRelayer.MsgOrderUpdateStruct = {
    orderKey: orderKey,
    orderId: 'testOrder',
    avgFilledPrice: '123123123',
    status: ethers.BigNumber.from('0'),
  };
  const allUpdates: OrdersRelayer.MsgOrderUpdateStruct[] = [orderUpdate];

  const updateOrder = await ordersRelayer.updateAllOrdersStatus(allUpdates);
  const updateTx = await updateOrder.wait();
  console.log('============Logging events============ \n');
  parsedLog = orderI.parseLog(orderReceipt.logs[0]);
  console.log('Parsed logs:', parsedLog.args);

  const order = await clientProxy.orders('testOrder');
  console.log('============Checking Order in Proxy============ \n');
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
