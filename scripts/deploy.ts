import { ethers } from 'hardhat';

const OrdersAddress = '0x7B93Da8e76D8B97C1c255E8E61bede2148981097';
async function main() {
  const router = require(`../artifacts/contracts/OrdersRelayer.sol/OrdersRelayer.json`).abi;
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);
  const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');

  const ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
  const contract = await ordersRelayer._deployed();
  console.log(contract.address);
  // const testOrderReq = {
  //   creator: '0x1576E5229Ea037215d4F58f1439EF27412E28c82',
  //   market: 'eth_swth',
  //   side: 'buy',
  //   quantity: 123123,
  //   orderType: 'limit',
  //   price: '123123',
  //   isReduceOnly: false,
  // };

  // console.log('Calling order');
  // const orderTx = await ordersRelayer.createOrder(
  //   testOrderReq.creator,
  //   testOrderReq.market,
  //   testOrderReq.side,
  //   testOrderReq.quantity,
  //   testOrderReq.orderType,
  //   testOrderReq.price,
  //   testOrderReq.isReduceOnly,
  //   { gasLimit: 100000000 }
  // );
  // console.log('Tx encoded', orderTx);
  // const orderReceipt = await orderTx.wait();
  // console.log('============Logging events============ \n');
  // console.log(orderReceipt.events);
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
