import hre from 'hardhat';

const OrdersAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const valEVMAccAddress = '0x5161e15fee8b918d4621703db75641bbc25301c8';
const carbonAddress = '0x352D3dfBeAF0a23A127d0920eB0C390d4905aa13';

const orderKey = '0xb5c0e0c51cc581688cf8c391a394df4befbc897dfc5cd2bf5b044773c965b09f';

async function main() {
  const OrdersRelayer = await hre.ethers.getContractFactory('OrdersRelayer');

  const ordersRelayer = OrdersRelayer.attach(carbonAddress);
  const test = await ordersRelayer.ping();

  const checkTx = await ordersRelayer.pendingOrders(orderKey);
  console.log('Pending orders', checkTx);

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
