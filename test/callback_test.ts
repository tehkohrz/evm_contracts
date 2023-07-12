import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { ClientProxy, OrdersRelayer } from '../typechain-types';

describe.only('Test two contract callback', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  let ordersRelayer: OrdersRelayer;
  let clientProxy: ClientProxy;

  let OrdersAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
  let ClientAddress = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
  const valEVMAccAddress = '0x5161e15fee8b918d4621703db75641bbc25301c8';

  async function deployFixture() {
    const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');
    const [deployer] = await ethers.getSigners();
    ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
    await ordersRelayer.deployed();

    const ClientProxy = await ethers.getContractFactory('ClientProxy');
    clientProxy = await ClientProxy.deploy();
    await clientProxy.deployed();

    OrdersAddress = await ordersRelayer.address;
    ClientAddress = await clientProxy.address;
  }

  describe('Mock order making through clientProxy -> orderRelayer -> clienProxy', function () {
    it('should update the clientProxy via the callback with the response', async function () {
      await loadFixture(deployFixture);

      await clientProxy.requestForPosition(OrdersAddress, valEVMAccAddress, 'btc_donuts');
      let log = await ordersRelayer.positionQueries(valEVMAccAddress);
      expect(log).to.be.equal({ market: 'btc_donuts', address: ClientAddress });

      const positionUpdate: OrdersRelayer.MsgPositionUpdateStruct = {
        evmAddress: valEVMAccAddress,
        market: 'btc_donuts',
        accountAddress: 'testtest',
        lots: '123123123',
        entryPrice: '1111111111',
        realisedPnl: '22222222',
        marginDenom: 'swth',
        marginAmount: '3333333333',
        openBlockHeight: '1000',
      };

      const tx = await ordersRelayer.respondToPositionQuery(positionUpdate);
    });
  });
});

import 'hardhat/console.sol';
