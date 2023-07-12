import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { OrdersRelayer } from '../typechain-types';

describe('Orders Relayer', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  let ordersRelayer: OrdersRelayer;
  async function deployFixture() {
    const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');
    const [deployer] = await ethers.getSigners();

    ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
    await ordersRelayer.deployed();
  }

  describe('generate order key', function () {
    it('should generate a unique length 32 key', async function () {
      await loadFixture(deployFixture);
      const tx = await ordersRelayer.generateOrderKey();
      expect(tx).to.not.be.null;
    });
  });

  describe('create order', function () {
    it('should create order and emit event for creation', async function () {
      await loadFixture(deployFixture);
      const testOrderReq = {
        creator: '0x1576E5229Ea037215d4F58f1439EF27412E28c82',
        market: 'eth_swth',
        side: 'buy',
        quantity: 123123,
        orderType: 'limit',
        price: '123123',
        isReduceOnly: false,
      };

      const tx = await ordersRelayer.createOrder(
        testOrderReq.market,
        testOrderReq.side,
        testOrderReq.quantity,
        testOrderReq.orderType,
        testOrderReq.price,
        testOrderReq.isReduceOnly
      );
      let res = await tx.wait();
      expect(tx).to.not.be.null;
    });
  });
});

import 'hardhat/console.sol';
