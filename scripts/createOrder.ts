import hre from 'hardhat';

const OrdersAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const carbonAddress = '0x7B93Da8e76D8B97C1c255E8E61bede2148981097';

async function main() {
  const OrdersRelayer = await hre.ethers.getContractFactory('OrdersRelayer');

  const ordersRelayer = OrdersRelayer.attach(carbonAddress);
  const testOrderReq = {
    creator: '0x5161e15fee8b918d4621703db75641bbc25301c8',
    market: 'eth_swth',
    side: 'buy',
    quantity: 123123,
    orderType: 'limit',
    price: '123123',
    isReduceOnly: false,
  };

  console.log('Calling order');
  const orderTx = await ordersRelayer.createOrder(
    testOrderReq.creator,
    testOrderReq.market,
    testOrderReq.side,
    testOrderReq.quantity,
    testOrderReq.orderType,
    testOrderReq.price,
    testOrderReq.isReduceOnly
  );
  console.log('Tx encoded', orderTx);
  const orderReceipt = await orderTx.wait();
  console.log('============Logging events============ \n');
  console.log(orderReceipt.logs);
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
